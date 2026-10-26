import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../glm_service.dart';
import '../models.dart';
import 'components.dart';
import 'theme.dart';

Future<void> showWeightImport(BuildContext context, AppState state) {
  return showAppSheet<void>(context, WeightImportSheet(state: state));
}

class WeightImportSheet extends StatefulWidget {
  const WeightImportSheet({super.key, required this.state});

  final AppState state;

  @override
  State<WeightImportSheet> createState() => _WeightImportSheetState();
}

class _WeightImportSheetState extends State<WeightImportSheet> {
  final picker = ImagePicker();
  Uint8List? imageBytes;
  String mimeType = 'image/jpeg';
  WeightScanResult? scan;
  WeightUnit? selectedUnit;
  Set<int> selected = {};
  bool busy = false;
  String? error;

  List<WeightScanRecord> get records => scan?.records ?? const [];

  List<WeightScanRecord> get selectedRecords => [
    for (var index = 0; index < records.length; index++)
      if (selected.contains(index)) records[index],
  ];

  bool get allSelected =>
      records.isNotEmpty && selected.length == records.length;

  int get conflictCount => selectedRecords.where((record) {
    return widget.state.weightOnDay(record.date) != null;
  }).length;

  List<WeightScanRecord> get invalidRecords {
    final unit = selectedUnit;
    if (unit == null) return const [];
    return selectedRecords.where((record) {
      final kg = unit.toKilograms(record.value);
      return kg < 25 || kg > 400;
    }).toList();
  }

  bool get canImport =>
      !busy &&
      selectedUnit != null &&
      selected.isNotEmpty &&
      invalidRecords.isEmpty;

  Future<void> pick(ImageSource source) async {
    if (busy) return;
    try {
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 90,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      final lowerPath = image.path.toLowerCase();
      setState(() {
        imageBytes = bytes;
        mimeType =
            image.mimeType?.toLowerCase().contains('png') == true ||
                lowerPath.endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
        scan = null;
        selectedUnit = null;
        selected = {};
        error = null;
        busy = true;
      });
      await analyze(bytes);
    } catch (error) {
      if (mounted) {
        setState(() => busy = false);
        showAppMessage(context, '无法读取照片：$error');
      }
    }
  }

  Future<void> analyze(Uint8List bytes) async {
    try {
      final result = await GlmService().recognizeWeights(
        bytes: bytes,
        mimeType: mimeType,
      );
      if (!mounted) return;
      setState(() {
        scan = result;
        selectedUnit = result.unit;
        selected = {
          for (var index = 0; index < result.records.length; index++) index,
        };
        error = result.records.isEmpty
            ? '这张截图里没有找到可用的体重记录。换一张日期和数值更清楚的截图试试。'
            : null;
        busy = false;
      });
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = failure.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void toggle(int index) {
    setState(() {
      if (!selected.add(index)) selected.remove(index);
    });
  }

  void toggleAll() {
    setState(() {
      if (allSelected) {
        selected.clear();
      } else {
        selected = {for (var index = 0; index < records.length; index++) index};
      }
    });
  }

  Future<void> import() async {
    if (!canImport) return;
    final unit = selectedUnit!;
    final chosen = selectedRecords;
    final conflicts = chosen.where(
      (record) => widget.state.weightOnDay(record.date) != null,
    );
    if (conflicts.isNotEmpty) {
      final dates = conflicts
          .take(4)
          .map((record) => DateFormat('M月d日').format(record.date))
          .join('、');
      final more = conflicts.length > 4 ? ' 等 ${conflicts.length} 天' : '';
      final confirmed = await showConfirmDialog(
        context,
        title: '覆盖 ${conflicts.length} 条同日记录？',
        message: '$dates$more 已经有体重记录。继续会用手动确认的导入值覆盖原记录，其他日期的记录不受影响。',
        confirmLabel: '覆盖并导入',
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => busy = true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final entries = <WeightEntry>[
      for (var index = 0; index < chosen.length; index++)
        WeightEntry(
          id: 'scan_${stamp}_$index',
          date: chosen[index].date,
          kg: unit.toKilograms(chosen[index].value),
        ),
    ];
    await widget.state.importWeights(entries);
    if (!mounted) return;
    showAppMessage(context, '已导入 ${entries.length} 条体重记录');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = scan == null ? '从截图导入体重' : '核对体重记录';
    final subtitle = scan == null
        ? '支持备忘录、健康 App、聊天记录等截图。只识别体重条目，不会改动饮食记录。'
        : '逐条核对日期和单位。勾选的记录才会导入，遇到同一天会先向你确认。';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeading(
            title: title,
            subtitle: subtitle,
            onClose: () => Navigator.pop(context),
          ),
          if (imageBytes != null) ...[
            _ImageStrip(bytes: imageBytes!),
            const SizedBox(height: 18),
          ],
          if (!busy && error == null && imageBytes == null) ...[
            _PickActions(onPick: pick),
            const SizedBox(height: 8),
          ],
          if (busy) _AnalyzingState(hasImage: imageBytes != null),
          if (!busy && error != null) ...[
            _MessageBox(message: error!, warning: true),
            const SizedBox(height: 18),
            _PickActions(onPick: pick),
            if (scan != null && records.isNotEmpty) ...[
              const SizedBox(height: 10),
              _RetakeHint(onRetake: () => pick(ImageSource.gallery)),
            ],
          ],
          if (!busy && scan != null && records.isNotEmpty) ...[
            _UnitSelector(
              inferredUnit: scan!.unit,
              selectedUnit: selectedUnit,
              onChanged: (unit) => setState(() => selectedUnit = unit),
            ),
            if (scan!.reply.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                scan!.reply,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.tertiary,
                ),
              ),
            ],
            if (scan!.skipped > 0) ...[
              const SizedBox(height: 10),
              _MessageBox(
                message: '有 ${scan!.skipped} 条内容缺少年份、日期或有效数值，已跳过。',
                warning: false,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '识别到 ${records.length} 条',
                    style: AppTextStyles.sectionTitle,
                  ),
                ),
                Pressable(
                  onTap: toggleAll,
                  haptic: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 8,
                    ),
                    child: Text(
                      allSelected ? '取消全选' : '全选',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentDeep,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GroupedCard(
              children: [
                for (var index = 0; index < records.length; index++)
                  _RecordRow(
                    record: records[index],
                    selected: selected.contains(index),
                    unit: selectedUnit,
                    displayUnit: widget.state.profile.weightUnit,
                    existing: widget.state.weightOnDay(records[index].date),
                    onTap: () => toggle(index),
                  ),
              ],
            ),
            if (selectedUnit == null) ...[
              const SizedBox(height: 12),
              const _MessageBox(
                message: '截图里没有写明单位。请先选择这些数字是公斤还是市斤，两者刚好相差一倍。',
                warning: true,
              ),
            ] else if (invalidRecords.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MessageBox(
                message:
                    '按${selectedUnit!.label}换算后，有 ${invalidRecords.length} 条不在 25–400 公斤的合理范围内。请核对单位或取消勾选这些记录。',
                warning: true,
              ),
            ],
            if (conflictCount > 0) ...[
              const SizedBox(height: 12),
              _MessageBox(
                message: '有 $conflictCount 条和已有记录日期相同，导入前会再次确认是否覆盖。',
                warning: true,
              ),
            ],
            const SizedBox(height: 22),
            PrimaryButton(
              label: selectedUnit == null
                  ? '请先选择单位'
                  : '导入 ${selected.length} 条记录',
              busy: busy,
              onPressed: canImport ? import : null,
            ),
            const SizedBox(height: 8),
            Center(
              child: Pressable(
                onTap: busy ? null : () => pick(ImageSource.gallery),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Text(
                    '换一张截图',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickActions extends StatelessWidget {
  const _PickActions({required this.onPick});

  final ValueChanged<ImageSource> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ActionPill(
                label: '拍照',
                icon: CupertinoIcons.camera,
                onPressed: () => onPick(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ActionPill(
                label: '从相册选择',
                icon: CupertinoIcons.photo,
                filled: false,
                onPressed: () => onPick(ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '照片只用于识别体重记录，不会保存到云端。导入的日期、数值和单位仍可继续手动修改。',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.65,
            color: AppColors.tertiary,
          ),
        ),
      ],
    );
  }
}

class _ImageStrip extends StatelessWidget {
  const _ImageStrip({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: double.infinity,
        height: 132,
        child: Image.memory(bytes, fit: BoxFit.cover),
      ),
    );
  }
}

class _AnalyzingState extends StatelessWidget {
  const _AnalyzingState({required this.hasImage});

  final bool hasImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 20,
            child: CupertinoActivityIndicator(
              radius: 9,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              hasImage ? '正在读取截图里的体重记录，通常需要 10–20 秒。' : '正在读取照片。',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitSelector extends StatelessWidget {
  const _UnitSelector({
    required this.inferredUnit,
    required this.selectedUnit,
    required this.onChanged,
  });

  final WeightUnit? inferredUnit;
  final WeightUnit? selectedUnit;
  final ValueChanged<WeightUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    final ambiguous = inferredUnit == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ambiguous ? '这些数值的单位是？' : '记录单位', style: AppTextStyles.eyebrow),
        const SizedBox(height: 9),
        Row(
          children: [
            for (final unit in WeightUnit.values) ...[
              if (unit != WeightUnit.values.first) const SizedBox(width: 8),
              ChoicePill(
                label: unit.label,
                selected: selectedUnit == unit,
                onTap: () => onChanged(unit),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        Text(
          ambiguous
              ? '截图没有给出单位，需要你确认后才能导入。'
              : '识别为${inferredUnit!.label}，如果截图实际不是这个单位，可以直接切换。',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.55,
            color: ambiguous ? AppColors.warm : AppColors.tertiary,
          ),
        ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.record,
    required this.selected,
    required this.unit,
    required this.displayUnit,
    required this.existing,
    required this.onTap,
  });

  final WeightScanRecord record;
  final bool selected;
  final WeightUnit? unit;
  final WeightUnit displayUnit;
  final WeightEntry? existing;
  final VoidCallback onTap;

  String _rawValue(WeightUnit? unit) {
    final rounded = (record.value * 10).roundToDouble() / 10;
    final text = rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(1);
    return unit == null ? text : '$text ${unit.label}';
  }

  @override
  Widget build(BuildContext context) {
    final conflict = existing;
    final subtitle = conflict == null
        ? '将导入为新的体重记录'
        : '同日已有 ${displayUnit.format(conflict.kg)}，导入会覆盖';
    return Opacity(
      opacity: selected ? 1 : 0.46,
      child: GroupedRow(
        onTap: onTap,
        showChevron: false,
        leading: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: selected ? AppColors.accentDeep : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.accentDeep : AppColors.lineStrong,
              width: 1.2,
            ),
          ),
          child: selected
              ? Icon(
                  CupertinoIcons.checkmark_alt,
                  size: 16,
                  color: AppColors.background,
                )
              : null,
        ),
        title: DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(record.date),
        subtitle: subtitle,
        detail: unit == null ? '${_rawValue(null)} ?' : _rawValue(unit),
        titleStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: conflict == null ? AppColors.ink : AppColors.warm,
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, required this.warning});

  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: warning
            ? AppColors.warning.withValues(alpha: 0.10)
            : AppColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: warning
              ? AppColors.warning.withValues(alpha: 0.24)
              : AppColors.glassBorder,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.6,
          color: warning ? AppColors.warning : AppColors.secondary,
        ),
      ),
    );
  }
}

class _RetakeHint extends StatelessWidget {
  const _RetakeHint({required this.onRetake});

  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Pressable(
        onTap: onRetake,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            '换一张截图',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.accentDeep,
            ),
          ),
        ),
      ),
    );
  }
}
