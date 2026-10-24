import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

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
    if (widget.state.apiKey.trim().isEmpty) {
      await showApiKeySheet(context, widget.state);
      if (widget.state.apiKey.trim().isEmpty || !mounted) return;
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
    if (widget.state.apiKey.trim().isEmpty) {
      await showApiKeySheet(context, widget.state);
      if (widget.state.apiKey.trim().isEmpty || !mounted) return;
    }
    setState(() => busy = true);
    try {
      final result = await GlmService().analyze(
        apiKey: widget.state.apiKey.trim(),
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
    return '轻点任意一项，可以调整克数与热量；确认之后，保存到今天的记录。';
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
                      eyebrow: hasImage ? '先核对，再保存' : 'AI 图片识别',
                      title: hasImage ? '这一餐' : '拍照识别',
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _subtitle(hasImage),
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.7,
                        color: AppColors.secondary,
                      ),
                    ),
                    if (kIsWeb && !hasImage) ...[
                      const SizedBox(height: 16),
                      const _WebPreviewNotice(),
                    ],
                    const SizedBox(height: 28),
                    if (!hasImage) ...[
                      _CaptureCard(
                        onCamera: () => chooseImage(ImageSource.camera),
                        onGallery: () => chooseImage(ImageSource.gallery),
                      ),
                      if (widget.state.apiKey.trim().isEmpty) ...[
                        const SizedBox(height: 16),
                        _KeyNotice(
                          onTap: () => showApiKeySheet(context, widget.state),
                        ),
                      ],
                      const SizedBox(height: 32),
                      const _UsageNote(),
                      const SizedBox(height: 20),
                      const Text(
                        '照片只会发送到你配置的 AI 接口 · AI 估算仅供参考',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.6,
                          color: AppColors.tertiary,
                        ),
                      ),
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
                        const Text('保存为', style: AppTextStyles.eyebrow),
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
                        const Text(
                          '轻点食物可以调整克数与热量。觉得整张清单不对，就在下方说「米饭只有半碗」，会重新估算并覆盖当前清单。',
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
                Positioned(
                  top: 8,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      const AppBackButton(),
                      const Spacer(),
                      _ApiKeyButton(
                        configured: widget.state.apiKey.trim().isNotEmpty,
                        onTap: () => showApiKeySheet(context, widget.state),
                      ),
                    ],
                  ),
                ),
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
      borderColor: const Color(0x33FFFFFF),
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
                child: const Icon(
                  CupertinoIcons.camera_viewfinder,
                  size: 24,
                  color: AppColors.accentDeep,
                ),
              ),
              const Spacer(),
              const Tag(
                label: '约 10–20 秒',
                color: AppColors.accentDeep,
                background: AppColors.accentSoft,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
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
          const Text(
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

class _KeyNotice extends StatelessWidget {
  const _KeyNotice({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      borderColor: const Color(0x33FFFFFF),
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      child: Row(
        children: [
          const IconBadge(
            icon: CupertinoIcons.lock_shield,
            color: AppColors.accentDeep,
            background: AppColors.accentSoft,
            size: 42,
            iconSize: 18,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '还差一个 API Key',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '用你自己的 API Key，只保存在这台设备。',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: AppColors.tertiary,
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
    return const SurfaceCard(
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
            '先看到的是一份可编辑的清单：食物、克数、热量都能改。觉得哪里不对，直接在下方告诉每餐，整张清单会按你的话重新估算。',
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

class _WebPreviewNotice extends StatelessWidget {
  const _WebPreviewNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              CupertinoIcons.globe,
              size: 15,
              color: AppColors.tertiary,
            ),
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              '网页预览受浏览器跨域限制，无法直接连接 AI 服务。拍照识别请使用手机或桌面 App。',
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

class _ApiKeyButton extends StatelessWidget {
  const _ApiKeyButton({required this.configured, required this.onTap});

  final bool configured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleIconButton(
          icon: CupertinoIcons.lock_shield,
          onTap: onTap,
          tooltip: 'API Key',
          size: 40,
          iconSize: 18,
        ),
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: configured ? AppColors.accent : AppColors.warm,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 1.6),
            ),
          ),
        ),
      ],
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
        border: Border.all(color: const Color(0x29FFFFFF)),
        boxShadow: AppShadows.card,
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
                      color: AppColors.surface,
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
                            color: AppColors.surface,
                          ),
                          SizedBox(width: 5),
                          Text(
                            '更换',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.surface,
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
      borderColor: const Color(0x29FFFFFF),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          const SizedBox.square(
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasItems ? '完成后会覆盖当前清单，请稍候。' : '通常需要 10–20 秒，请稍候。',
                  style: const TextStyle(
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
      borderColor: const Color(0x29FFFFFF),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
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
                const Text(
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
                  style: const TextStyle(
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

class _ItemsHeader extends StatelessWidget {
  const _ItemsHeader({required this.count, required this.total});

  final int count;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(child: Text('食物列表', style: AppTextStyles.sectionTitle)),
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
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatNumber(item.grams)} 克',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary,
                    ),
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
                const Text(
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
              child: const SizedBox(
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 34,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xF20C0C0D),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0x29FFFFFF)),
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
                      fillColor: const Color(0x14FFFFFF),
                      contentPadding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(
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
                                  ? const SizedBox.square(
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
            border: Border.all(color: const Color(0x66FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (saving)
                const SizedBox.square(
                  dimension: 16,
                  child: CupertinoActivityIndicator(
                    radius: 8,
                    color: AppColors.background,
                  ),
                )
              else
                const Icon(
                  CupertinoIcons.checkmark_alt,
                  size: 16,
                  color: AppColors.background,
                ),
              const SizedBox(width: 7),
              const Text(
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

Future<void> showApiKeySheet(BuildContext context, AppState state) {
  return showAppSheet<void>(context, _ApiKeySheet(state: state));
}

class _ApiKeySheet extends StatefulWidget {
  const _ApiKeySheet({required this.state});

  final AppState state;

  @override
  State<_ApiKeySheet> createState() => _ApiKeySheetState();
}

class _ApiKeySheetState extends State<_ApiKeySheet> {
  late final controller = TextEditingController(text: widget.state.apiKey);
  bool reveal = false;
  bool saving = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    final value = controller.text.trim();
    if (value.isEmpty) {
      showAppMessage(context, '请输入 API Key');
      return;
    }
    setState(() => saving = true);
    await widget.state.setApiKey(value);
    if (!mounted) return;
    showAppMessage(context, 'API Key 已保存在本机');
    Navigator.pop(context);
  }

  Future<void> remove() async {
    if (saving) return;
    setState(() => saving = true);
    await widget.state.setApiKey('');
    if (!mounted) return;
    showAppMessage(context, '已移除 API Key');
    Navigator.pop(context);
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
            title: 'API Key',
            subtitle: '用于 AI 图片识别，密钥只保存在这台设备。',
            onClose: () => Navigator.pop(context),
          ),
          TextField(
            controller: controller,
            obscureText: !reveal,
            autocorrect: false,
            enableSuggestions: false,
            autofocus: widget.state.apiKey.isEmpty,
            decoration: InputDecoration(
              hintText: '粘贴 API Key',
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Pressable(
                  onTap: () => setState(() => reveal = !reveal),
                  scale: 0.88,
                  semanticLabel: reveal ? '隐藏密钥' : '显示密钥',
                  child: SizedBox.square(
                    dimension: 40,
                    child: Center(
                      child: Icon(
                        reveal ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                        size: 19,
                        color: AppColors.tertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  CupertinoIcons.lock,
                  size: 12,
                  color: AppColors.tertiary,
                ),
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '不会写入日志，也不会上传到其他服务。图片只在识别时发送到你填写的 AI 接口。',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.6,
                    color: AppColors.tertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: '保存', busy: saving, onPressed: save),
          if (widget.state.apiKey.isNotEmpty) ...[
            const SizedBox(height: 6),
            Center(
              child: Pressable(
                onTap: saving ? null : remove,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    '移除密钥',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
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
