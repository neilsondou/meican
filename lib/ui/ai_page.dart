import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../ai_keys.dart';
import '../app_state.dart';
import '../glm_service.dart';
import '../models.dart';
import 'components.dart';
import 'meal_widgets.dart';
import 'record_page.dart';
import 'theme.dart';

class AiCapturePage extends StatefulWidget {
  const AiCapturePage({super.key, required this.state});

  final AppState state;

  @override
  State<AiCapturePage> createState() => _AiCapturePageState();
}

class _AiCapturePageState extends State<AiCapturePage> {
  final picker = ImagePicker();
  final refinement = TextEditingController();
  Uint8List? imageBytes;
  String mimeType = 'image/jpeg';
  List<MealItem> items = [];
  String reply = '';
  String mealType = _currentMealType();
  bool busy = false;
  bool saving = false;

  double get total => items.fold(0, (sum, item) => sum + item.kcal);

  bool get canRecognize => kIsWeb || AiKeyPool.isConfigured;

  static String _currentMealType() {
    final hour = DateTime.now().hour;
    if (hour < 10) return '早餐';
    if (hour < 15) return '午餐';
    if (hour < 21) return '晚餐';
    return '加餐';
  }

  @override
  void dispose() {
    refinement.dispose();
    super.dispose();
  }

  Future<void> chooseImage(ImageSource source) async {
    if (!canRecognize) {
      showAppMessage(context, '当前版本未启用图片识别服务，请安装配置后的版本。');
      return;
    }
    try {
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 88,
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
        items = [];
        reply = '';
      });
      await analyze();
    } catch (error) {
      if (mounted) showAppMessage(context, '无法读取照片：$error');
    }
  }

  Future<void> replaceImage() async {
    final source = await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('更换照片'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, ImageSource.camera),
            child: const Text('拍照'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, ImageSource.gallery),
            child: const Text('从相册选择'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (source != null && mounted) await chooseImage(source);
  }

  Future<void> analyze({String instruction = ''}) async {
    final bytes = imageBytes;
    if (bytes == null || busy) return;
    setState(() => busy = true);
    try {
      final result = await GlmService().analyze(
        bytes: bytes,
        mimeType: mimeType,
        instruction: instruction,
        currentItems: instruction.isEmpty ? const [] : items,
      );
      if (!mounted) return;
      setState(() {
        items = result.items;
        reply = result.reply;
        refinement.clear();
      });
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submitRefinement() async {
    final instruction = refinement.text.trim();
    if (instruction.isEmpty || busy) return;
    FocusScope.of(context).unfocus();
    await analyze(instruction: instruction);
  }

  Future<void> openArgueSheet() async {
    if (busy || items.isEmpty) return;
    FocusScope.of(context).unfocus();
    final instruction = await showAppSheet<String>(
      context,
      _ArgueSheet(items: items, initialText: refinement.text),
    );
    final trimmed = instruction?.trim() ?? '';
    if (!mounted || trimmed.isEmpty) return;
    refinement.text = trimmed;
    await analyze(instruction: trimmed);
  }

  Future<void> editItem(int index) async {
    final result = await showAppSheet<MealItem>(
      context,
      ItemAmountSheet(item: items[index]),
    );
    if (result != null && mounted) {
      setState(() => items[index] = result);
    }
  }

  void removeItem(int index) {
    HapticFeedback.selectionClick();
    setState(() => items.removeAt(index));
  }

  Future<void> saveMeal() async {
    if (items.isEmpty || saving || busy) return;
    setState(() => saving = true);
    await widget.state.addMeal(
      MealEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: DateTime.now(),
        mealType: mealType,
        items: List.of(items),
        note: reply,
        source: 'ai',
      ),
    );
    if (!mounted) return;
    showAppMessage(context, '已保存到今天的记录');
    Navigator.of(context).pop();
  }

  String _subtitle(bool hasImage) {
    if (!hasImage) {
      return '把整餐拍进画面，先得到一份可编辑的食物清单，再由你决定保存什么。';
    }
    if (busy) {
      return items.isEmpty
          ? '正在辨认食物与分量，通常需要 10–20 秒。'
          : '正在按你的要求重新估算，完成后会覆盖当前清单。';
    }
    if (items.isEmpty) {
      return '这张照片没有找到食物。换一张光线更均匀、食物完整入镜的照片试试。';
    }
    return '轻点任意一项调整克数与热量；不同意估算，就和 AI 犟嘴，让它按你的说法重算。';
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBytes != null;
    final showDock = hasImage && items.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackground(),
          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(24, 68, 24, showDock ? 190 : 32),
                  children: [
                    PageHeader(
                      eyebrow: hasImage ? '先核对，再保存' : null,
                      title: hasImage ? '这一餐' : '拍照识别',
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _subtitle(hasImage),
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.7,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (!hasImage) ...[
                      _CaptureCard(
                        onCamera: () => chooseImage(ImageSource.camera),
                        onGallery: () => chooseImage(ImageSource.gallery),
                      ),
                      if (!kIsWeb && !AiKeyPool.isConfigured) ...[
                        const SizedBox(height: 16),
                        const _ServiceNotice(),
                      ],
                      const SizedBox(height: 32),
                      const _UsageNote(),
                    ] else ...[
                      _ImagePreview(
                        bytes: imageBytes!,
                        onReplace: busy ? null : replaceImage,
                      ),
                      const SizedBox(height: 22),
                      if (busy) ...[
                        _AnalyzingCard(hasItems: items.isNotEmpty),
                        const SizedBox(height: 20),
                      ],
                      if (!busy && reply.isNotEmpty) ...[
                        _ReplyNote(reply: reply),
                        const SizedBox(height: 28),
                      ],
                      if (!busy && items.isEmpty) ...[
                        SurfaceCard(
                          padding: EdgeInsets.zero,
                          child: EmptyState(
                            icon: CupertinoIcons.tray,
                            title: '这一张没有结果',
                            message: '光线更亮、食物完整入镜时，估算会更稳定。也可以在下方换一张照片。',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ActionPill(
                                label: '重新拍照',
                                icon: CupertinoIcons.camera,
                                onPressed: busy
                                    ? null
                                    : () => chooseImage(ImageSource.camera),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ActionPill(
                                label: '从相册选择',
                                icon: CupertinoIcons.photo,
                                filled: false,
                                onPressed: busy
                                    ? null
                                    : () => chooseImage(ImageSource.gallery),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!busy && items.isNotEmpty) ...[
                        _ArgueAction(onTap: openArgueSheet),
                        const SizedBox(height: 24),
                        _ItemsHeader(count: items.length, total: total),
                        const SizedBox(height: 12),
                        GroupedCard(
                          children: [
                            for (var index = 0; index < items.length; index++)
                              _AiItemRow(
                                item: items[index],
                                mealType: mealType,
                                onTap: () => editItem(index),
                                onRemove: () => removeItem(index),
                              ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Text('保存为', style: AppTextStyles.eyebrow),
                        const SizedBox(height: 12),
                        PillSegmented<String>(
                          options: const [
                            SegmentedOption(value: '早餐', label: '早餐'),
                            SegmentedOption(value: '午餐', label: '午餐'),
                            SegmentedOption(value: '晚餐', label: '晚餐'),
                            SegmentedOption(value: '加餐', label: '加餐'),
                          ],
                          value: mealType,
                          onChanged: (value) =>
                              setState(() => mealType = value),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '轻点食物可以调整克数与热量。不同意估算，就点上面的「和ai犟嘴（我没吃这么多）」，'
                          'AI 会按你的说法重新估算并覆盖当前清单。',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.65,
                            color: AppColors.tertiary,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
                Positioned(top: 8, left: 14, child: AppBackButton()),
              ],
            ),
          ),
          if (showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _ResultDock(
                    controller: refinement,
                    busy: busy,
                    saving: saving,
                    canSave: !busy && !saving,
                    onChanged: () => setState(() {}),
                    onSend: submitRefinement,
                    onSave: saveMeal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CaptureCard extends StatelessWidget {
  const _CaptureCard({required this.onCamera, required this.onGallery});

  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      elevated: true,
      borderColor: AppColors.borderStrong,
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.glassStrong,
                  border: Border.all(color: AppColors.glassBorder),
                ),
                alignment: Alignment.center,
                child: Icon(
                  CupertinoIcons.camera_viewfinder,
                  size: 24,
                  color: AppColors.accentDeep,
                ),
              ),
              const Spacer(),
              Tag(
                label: '约 10–20 秒',
                color: AppColors.accentDeep,
                background: AppColors.accentSoft,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '拍下这一餐',
            style: TextStyle(
              fontSize: 24,
              height: 1.18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '把整餐放进画面，光线尽量均匀。识别后逐项核对克数，再保存到今天的记录。',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.7,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: ActionPill(
                  label: '拍照',
                  icon: CupertinoIcons.camera,
                  onPressed: onCamera,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ActionPill(
                  label: '从相册选择',
                  icon: CupertinoIcons.photo,
                  filled: false,
                  onPressed: onGallery,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceNotice extends StatelessWidget {
  const _ServiceNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              CupertinoIcons.exclamationmark_circle,
              size: 15,
              color: AppColors.tertiary,
            ),
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              '当前安装包未启用图片识别服务，请安装配置后的版本。',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageNote extends StatelessWidget {
  const _UsageNote();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '识别之后',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '先看到的是一份可编辑的清单：食物、克数、热量都能改。觉得估多了，点「和ai犟嘴（我没吃这么多）」，'
            '说清实际分量，AI 会按你的说法重算整张清单。',
            style: TextStyle(
              fontSize: 13,
              height: 1.7,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.bytes, required this.onReplace});

  final Uint8List bytes;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderStrong),
        boxShadow: kIsWeb ? null : AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card - 1),
        child: SizedBox(
          height: 230,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
              Positioned(
                left: 14,
                top: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x1FFFFFFF)),
                  ),
                  child: const Text(
                    '已选照片',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onImage,
                    ),
                  ),
                ),
              ),
              if (onReplace != null)
                Positioned(
                  right: 14,
                  top: 14,
                  child: Pressable(
                    onTap: onReplace,
                    haptic: true,
                    scale: 0.94,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0x29FFFFFF)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.camera_rotate,
                            size: 13,
                            color: AppColors.onImage,
                          ),
                          SizedBox(width: 5),
                          Text(
                            '更换',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onImage,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyzingCard extends StatelessWidget {
  const _AnalyzingCard({required this.hasItems});

  final bool hasItems;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      borderColor: AppColors.borderStrong,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 22,
            child: CupertinoActivityIndicator(
              radius: 10,
              color: AppColors.accentDeep,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasItems ? '正在按你的要求重新估算…' : '正在辨认食物与分量…',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasItems ? '完成后会覆盖当前清单，请稍候。' : '通常需要 10–20 秒，请稍候。',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyNote extends StatelessWidget {
  const _ReplyNote({required this.reply});

  final String reply;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      borderColor: AppColors.borderStrong,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              CupertinoIcons.sparkles,
              size: 16,
              color: AppColors.accentDeep,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '识别说明',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.tertiary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  reply,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.65,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArgueAction extends StatelessWidget {
  const _ArgueAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: 0.985,
      semanticLabel: '和ai犟嘴（我没吃这么多）',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.accentSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.chat_bubble_2,
              size: 18,
              color: AppColors.accentDeep,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '和ai犟嘴（我没吃这么多）',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentDeep,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '告诉 AI 实际吃了多少，它会按你的说法重算整张清单。',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_right,
              size: 13,
              color: AppColors.accentDeep,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemsHeader extends StatelessWidget {
  const _ItemsHeader({required this.count, required this.total});

  final int count;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: Text('食物列表', style: AppTextStyles.sectionTitle)),
        Tag(label: '$count 项'),
        const SizedBox(width: 10),
        Text('${formatCalories(total)} 大卡', style: AppTextStyles.numericInline),
      ],
    );
  }
}

class _AiItemRow extends StatelessWidget {
  const _AiItemRow({
    required this.item,
    required this.mealType,
    required this.onTap,
    required this.onRemove,
  });

  final MealItem item;
  final String mealType;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final visual = mealVisual(mealType);
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 15, 8, 15),
        child: Row(
          children: [
            IconBadge(
              icon: visual.icon,
              color: visual.color,
              background: visual.background,
              size: 38,
              iconSize: 16,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatNumber(item.grams)} 克',
                    style: TextStyle(fontSize: 12, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCalories(item.kcal),
                  style: AppTextStyles.numericInline,
                ),
                Text(
                  '大卡',
                  style: TextStyle(fontSize: 9.5, color: AppColors.tertiary),
                ),
              ],
            ),
            const SizedBox(width: 2),
            Pressable(
              onTap: onRemove,
              haptic: true,
              scale: 0.85,
              semanticLabel: '移除${item.name}',
              child: SizedBox(
                width: 38,
                height: 40,
                child: Icon(
                  CupertinoIcons.minus_circle,
                  size: 20,
                  color: AppColors.tertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultDock extends StatelessWidget {
  const _ResultDock({
    required this.controller,
    required this.busy,
    required this.saving,
    required this.canSave,
    required this.onChanged,
    required this.onSend,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool busy;
  final bool saving;
  final bool canSave;
  final VoidCallback onChanged;
  final VoidCallback onSend;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final canSend = controller.text.trim().isNotEmpty && !busy;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: kIsWeb ? null : AppShadows.raised,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.sheet,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !busy,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) => canSend ? onSend() : null,
                  style: const TextStyle(fontSize: 14.5, height: 1.4),
                  decoration: InputDecoration(
                    hintText: '微调，例如：米饭只有半碗',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.fieldFill,
                    contentPadding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: AppColors.accent,
                        width: 1.2,
                      ),
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Pressable(
                        onTap: canSend ? onSend : null,
                        scale: 0.88,
                        semanticLabel: '重新识别',
                        child: SizedBox.square(
                          dimension: 40,
                          child: Center(
                            child: busy
                                ? SizedBox.square(
                                    dimension: 17,
                                    child: CupertinoActivityIndicator(
                                      radius: 8,
                                      color: AppColors.accentDeep,
                                    ),
                                  )
                                : Icon(
                                    CupertinoIcons.arrow_up_circle_fill,
                                    size: 24,
                                    color: canSend
                                        ? AppColors.accentDeep
                                        : AppColors.tertiary.withValues(
                                            alpha: 0.45,
                                          ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _SaveAction(enabled: canSave, saving: saving, onTap: onSave),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveAction extends StatelessWidget {
  const _SaveAction({
    required this.enabled,
    required this.saving,
    required this.onTap,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = enabled || saving;
    return Pressable(
      onTap: active ? onTap : null,
      haptic: true,
      scale: 0.96,
      child: Opacity(
        opacity: active ? 1 : 0.45,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.onSurfaceBorder),
            boxShadow: kIsWeb ? null : AppShadows.card,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (saving)
                SizedBox.square(
                  dimension: 16,
                  child: CupertinoActivityIndicator(
                    radius: 8,
                    color: AppColors.background,
                  ),
                )
              else
                Icon(
                  CupertinoIcons.checkmark_alt,
                  size: 16,
                  color: AppColors.background,
                ),
              const SizedBox(width: 7),
              Text(
                '保存',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.background,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArgueSheet extends StatefulWidget {
  const _ArgueSheet({required this.items, required this.initialText});

  final List<MealItem> items;
  final String initialText;

  @override
  State<_ArgueSheet> createState() => _ArgueSheetState();
}

class _ArgueSheetState extends State<_ArgueSheet> {
  static const _suggestions = ['米饭只吃了一半', '肉只吃了一半', '没喝汤', '少油少糖'];

  late final controller = TextEditingController(text: widget.initialText);

  double get total => widget.items.fold(0, (sum, item) => sum + item.kcal);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void useSuggestion(String suggestion) {
    final current = controller.text.trim();
    final next = current.isEmpty ? suggestion : '$current，$suggestion';
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() {});
  }

  void submit() {
    final instruction = controller.text.trim();
    if (instruction.isEmpty) {
      showAppMessage(context, '先说说实际吃了多少');
      return;
    }
    Navigator.pop(context, instruction);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeading(
            title: '和 AI 犟嘴',
            subtitle: '把实际吃法说清楚，AI 会按你的说法重算整张清单。',
            onClose: () => Navigator.pop(context),
          ),
          Row(
            children: [
              Icon(
                CupertinoIcons.square_list,
                size: 14,
                color: AppColors.tertiary,
              ),
              const SizedBox(width: 7),
              Text(
                '当前 ${widget.items.length} 项 · ${formatCalories(total)} 大卡',
                style: TextStyle(fontSize: 12, color: AppColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            maxLength: 140,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '例如：米饭只吃了半碗，鸡腿去皮，汤没喝完。',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in _suggestions)
                ChoicePill(
                  label: suggestion,
                  selected: controller.text.contains(suggestion),
                  onTap: () => useSuggestion(suggestion),
                ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: '让 AI 重新算',
            onPressed: controller.text.trim().isEmpty ? null : submit,
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              '会覆盖当前清单，之后仍可逐项修改。',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
