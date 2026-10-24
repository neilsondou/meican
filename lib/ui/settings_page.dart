import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../export_service.dart';
import '../models.dart';
import 'ai_page.dart';
import 'components.dart';
import 'theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? exporting;

  Future<void> export(String type) async {
    if (exporting != null) return;
    setState(() => exporting = type);
    try {
      if (type == 'CSV') {
        await ExportService.exportCsv(widget.state);
      } else {
        await ExportService.exportPdf(widget.state);
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      children: [
        const PageHeader(eyebrow: '自己与设备', title: '我的'),
        const SizedBox(height: 28),
        _ProfileCard(
          state: state,
          onTap: () => showProfileSheet(context, state),
        ),
        const SizedBox(height: 44),
        const SectionHeader(title: '智能记录'),
        GroupedCard(
          children: [
            GroupedRow(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
              leading: const IconBadge(
                icon: CupertinoIcons.lock_shield,
                color: AppColors.accentDeep,
                background: AppColors.accentSoft,
                size: 40,
                iconSize: 18,
              ),
              title: 'API Key',
              subtitle: state.apiKey.isEmpty
                  ? '还没有设置，拍照识别暂时不可用'
                  : '已保存在这台设备，只用于图片识别',
              detail: state.apiKey.isEmpty ? '未设置' : '已设置',
              onTap: () => showApiKeySheet(context, state),
            ),
            GroupedRow(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
              leading: const IconBadge(
                icon: CupertinoIcons.camera_viewfinder,
                color: AppColors.accentDeep,
                background: AppColors.accentSoft,
                size: 40,
                iconSize: 18,
              ),
              title: '拍照识别',
              subtitle: '拍一张照片，生成可编辑的食物清单',
              onTap: () => _openCapture(context, state),
            ),
          ],
        ),
        const SizedBox(height: 44),
        const SectionHeader(title: '导出'),
        GroupedCard(
          children: [
            GroupedRow(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
              leading: const IconBadge(
                icon: CupertinoIcons.square_arrow_up,
                color: AppColors.warm,
                background: Color(0x1FD9A77A),
                size: 40,
                iconSize: 18,
              ),
              title: '导出 CSV',
              subtitle: '全部饮食与体重记录',
              detail: exporting == 'CSV' ? '导出中…' : 'CSV',
              onTap: exporting == null ? () => export('CSV') : null,
            ),
            GroupedRow(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
              leading: const IconBadge(
                icon: CupertinoIcons.doc_text,
                color: AppColors.warm,
                background: Color(0x1FD9A77A),
                size: 40,
                iconSize: 18,
              ),
              title: '导出 PDF',
              subtitle: '可打印的汇总报告',
              detail: exporting == 'PDF' ? '导出中…' : 'PDF',
              onTap: exporting == null ? () => export('PDF') : null,
            ),
          ],
        ),
        const SizedBox(height: 52),
        const Center(
          child: Column(
            children: [
              Text(
                '每餐',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 5,
                  color: AppColors.secondary,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'by 老窦',
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.5,
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 144),
      ],
    );
  }

  void _openCapture(BuildContext context, AppState state) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => AiCapturePage(state: state)),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.state, required this.onTap});

  final AppState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    final bmr = NutritionMath.bmr(profile);
    final tdee = NutritionMath.tdee(profile);

    return SurfaceCard(
      elevated: true,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: CupertinoIcons.person_fill,
                color: AppColors.accentDeep,
                background: AppColors.accentSoft,
                size: 46,
                iconSize: 21,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '身体与目标',
                      style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '轻点修改身高、体重与活动量',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: AppColors.tertiary,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatNumber(profile.weightKg),
                style: AppTextStyles.numericLarge,
              ),
              const Padding(
                padding: EdgeInsets.only(left: 6, bottom: 4),
                child: Text(
                  'kg',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Tag(
                  label: '目标 ${formatNumber(profile.targetWeightKg)} kg',
                  color: AppColors.accentDeep,
                  background: AppColors.accentSoft,
                  icon: CupertinoIcons.flag,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '基础代谢约 ${formatCalories(bmr)} 大卡。按「${activityLabel(profile.activity)}」的活动量，每天大约消耗 ${formatCalories(tdee)} 大卡。',
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.7,
              color: AppColors.secondary,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: HairLine(),
          ),
          Row(
            children: [
              Expanded(
                child: _ProfileFact(
                  label: '身高',
                  value: '${formatNumber(profile.heightCm)} cm',
                ),
              ),
              Expanded(
                child: _ProfileFact(label: '年龄', value: '${profile.age} 岁'),
              ),
              Expanded(
                child: _ProfileFact(
                  label: '性别',
                  value: profile.sex == 'male' ? '男性' : '女性',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileFact extends StatelessWidget {
  const _ProfileFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: AppColors.tertiary),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

const activityOptions = <({double value, String label})>[
  (value: 1.2, label: '久坐为主'),
  (value: 1.375, label: '每周 1–3 次'),
  (value: 1.55, label: '每周 3–5 次'),
  (value: 1.725, label: '每周 6–7 次'),
  (value: 1.9, label: '高强度'),
];

String activityLabel(double activity) {
  for (final option in activityOptions) {
    if ((option.value - activity).abs() < 0.001) return option.label;
  }
  return '活动量较高';
}

Future<void> showProfileSheet(BuildContext context, AppState state) {
  return showAppSheet<void>(context, ProfileSheet(state: state));
}

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key, required this.state});

  final AppState state;

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  late final height = TextEditingController(
    text: formatNumber(widget.state.profile.heightCm),
  );
  late final weight = TextEditingController(
    text: formatNumber(widget.state.profile.weightKg),
  );
  late final age = TextEditingController(
    text: widget.state.profile.age.toString(),
  );
  late final target = TextEditingController(
    text: formatNumber(widget.state.profile.targetWeightKg),
  );
  late String sex = widget.state.profile.sex;
  late double activity = widget.state.profile.activity;

  @override
  void initState() {
    super.initState();
    for (final controller in [height, weight, age, target]) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    height.dispose();
    weight.dispose();
    age.dispose();
    target.dispose();
    super.dispose();
  }

  UserProfile? get _draft {
    final heightValue = double.tryParse(height.text.trim());
    final weightValue = double.tryParse(weight.text.trim());
    final ageValue = int.tryParse(age.text.trim());
    final targetValue = double.tryParse(target.text.trim());
    if (heightValue == null ||
        heightValue < 100 ||
        heightValue > 250 ||
        weightValue == null ||
        weightValue < 25 ||
        weightValue > 400 ||
        ageValue == null ||
        ageValue < 10 ||
        ageValue > 100 ||
        targetValue == null ||
        targetValue < 25 ||
        targetValue > 400) {
      return null;
    }
    return widget.state.profile.copyWith(
      heightCm: heightValue,
      weightKg: weightValue,
      age: ageValue,
      targetWeightKg: targetValue,
      sex: sex,
      activity: activity,
    );
  }

  Future<void> save() async {
    final draft = _draft;
    if (draft == null) {
      showAppMessage(context, '请检查身高、体重、年龄和目标是否有效');
      return;
    }
    await widget.state.updateProfile(draft);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeading(
            title: '身体与目标',
            subtitle: '用于基础代谢、每日消耗与减重预测。',
            onClose: () => Navigator.pop(context),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: height,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '身高',
                    suffixText: 'cm',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '体重',
                    suffixText: 'kg',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: age,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '年龄',
                    suffixText: '岁',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: target,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '目标体重',
                    suffixText: 'kg',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text('生理性别', style: AppTextStyles.eyebrow),
          const SizedBox(height: 10),
          PillSegmented<String>(
            options: const [
              SegmentedOption(value: 'male', label: '男性'),
              SegmentedOption(value: 'female', label: '女性'),
            ],
            value: sex,
            onChanged: (value) => setState(() => sex = value),
          ),
          const SizedBox(height: 22),
          const Text('日常活动', style: AppTextStyles.eyebrow),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in activityOptions)
                ChoicePill(
                  label: option.label,
                  selected: (activity - option.value).abs() < 0.001,
                  onTap: () => setState(() => activity = option.value),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _PreviewStat(
                    label: '基础代谢',
                    value: draft == null
                        ? '—'
                        : '${formatCalories(NutritionMath.bmr(draft))} 大卡',
                  ),
                ),
                Container(width: 0.7, height: 30, color: AppColors.line),
                Expanded(
                  child: _PreviewStat(
                    label: '每日总消耗',
                    value: draft == null
                        ? '—'
                        : '${formatCalories(NutritionMath.tdee(draft))} 大卡',
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: '保存', onPressed: save),
        ],
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.secondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
