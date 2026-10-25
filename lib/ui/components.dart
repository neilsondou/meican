import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: ColoredBox(color: AppColors.background),
    );
  }
}

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.opacity = 0.9,
    this.haptic = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final double opacity;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    if (widget.haptic) HapticFeedback.lightImpact();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 170);
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap == null ? null : _handleTap,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _setPressed(false);
                widget.onLongPress!();
              },
        child: AnimatedScale(
          scale: _pressed ? widget.scale : 1,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _pressed ? widget.opacity : 1,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: RepaintBoundary(child: widget.child),
          ),
        ),
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.onTap,
    this.color,
    this.radius = AppRadius.card,
    this.elevated = false,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final bool elevated;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.glassBlack,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AppColors.glassBorder,
          width: 1,
        ),
        boxShadow: elevated && !kIsWeb ? AppShadows.card : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: Padding(padding: padding, child: child),
      ),
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, scale: 0.985, child: card);
  }
}

class GroupedCard extends StatelessWidget {
  const GroupedCard({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });

  final List<Widget> children;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              const Padding(
                padding: EdgeInsets.only(left: 72),
                child: Divider(height: 0.7, thickness: 0.7),
              ),
            children[index],
          ],
          ?footer,
        ],
      ),
    );
  }
}

class HairLine extends StatelessWidget {
  const HairLine({super.key, this.indent = 0, this.endIndent = 0});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.7,
      thickness: 0.7,
      indent: indent,
      endIndent: endIndent,
      color: AppColors.line,
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.size = 40,
    this.iconSize = 19,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

class GroupedRow extends StatelessWidget {
  const GroupedRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.detail,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    this.titleStyle,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? detail;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final EdgeInsetsGeometry padding;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      titleStyle ??
                      const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: AppColors.ink,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (detail != null) ...[
            const SizedBox(width: 12),
            Text(
              detail!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          if (showChevron && onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.tertiary,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Pressable(onTap: onTap, child: content);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(title, style: AppTextStyles.sectionTitle)),
          if (actionLabel != null)
            Pressable(
              onTap: onAction,
              haptic: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentDeep,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      CupertinoIcons.chevron_right,
                      size: 11,
                      color: AppColors.accentDeep,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: AppColors.accentDeep,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(title, style: AppTextStyles.largeTitle),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 16),
          Padding(padding: const EdgeInsets.only(bottom: 3), child: trailing!),
        ],
      ],
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 40,
    this.iconSize = 19,
    this.background,
    this.foreground = AppColors.ink,
    this.borderColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? background;
  final Color foreground;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background ?? AppColors.glassStrong,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor ?? AppColors.glassBorder,
              width: 1,
            ),
            boxShadow: kIsWeb
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Icon(icon, size: iconSize, color: foreground),
        ),
      ),
    );
    final interactive = onTap == null
        ? button
        : Pressable(onTap: onTap, haptic: true, scale: 0.9, child: button);
    if (tooltip == null) return interactive;
    return Tooltip(message: tooltip!, child: interactive);
  }
}

class ActionPill extends StatelessWidget {
  const ActionPill({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.filled = true,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final foreground = filled ? AppColors.background : AppColors.ink;
    final pill = Opacity(
      opacity: enabled || busy ? 1 : 0.4,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: filled ? AppColors.surface : AppColors.glassStrong,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: filled ? const Color(0x66FFFFFF) : AppColors.glassBorder,
            width: 1,
          ),
          boxShadow: kIsWeb
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 26,
                    offset: Offset(0, 12),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox.square(
                dimension: 17,
                child: CupertinoActivityIndicator(radius: 8, color: foreground),
              )
            else
              Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
    if (!enabled) return pill;
    return Pressable(onTap: onPressed, haptic: true, scale: 0.97, child: pill);
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Pressable(
      onTap: enabled ? onPressed : null,
      haptic: true,
      scale: 0.975,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Opacity(
          opacity: enabled || busy ? 1 : 0.4,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: const Color(0x66FFFFFF), width: 1),
              boxShadow: kIsWeb
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x59000000),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox.square(
                    dimension: 17,
                    child: CupertinoActivityIndicator(
                      radius: 8,
                      color: AppColors.background,
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 18, color: AppColors.background),
                if (busy || icon != null) const SizedBox(width: 9),
                Text(
                  busy ? '请稍候' : label,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: AppColors.background,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SegmentedOption<T> {
  const SegmentedOption({required this.value, required this.label});

  final T value;
  final String label;
}

class PillSegmented<T> extends StatelessWidget {
  const PillSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SegmentedOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = options.indexWhere((option) => option.value == value);
    final index = selectedIndex < 0 ? 0 : selectedIndex;
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: width * index,
                top: 0,
                bottom: 0,
                width: width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF232326),
                    borderRadius: BorderRadius.circular(19),
                    boxShadow: kIsWeb ? null : AppShadows.thumb,
                  ),
                ),
              ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: Pressable(
                        onTap: () {
                          if (option.value != value) {
                            HapticFeedback.selectionClick();
                            onChanged(option.value);
                          }
                        },
                        scale: 0.96,
                        opacity: 1,
                        semanticLabel: option.label,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              fontFamily: 'MeicanSans',
                              fontSize: 14,
                              fontWeight: option.value == value
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: option.value == value
                                  ? AppColors.ink
                                  : AppColors.secondary,
                              decoration: TextDecoration.none,
                            ),
                            child: Text(option.label),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : AppColors.glass,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: selected ? const Color(0x66FFFFFF) : AppColors.glassBorder,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.background : AppColors.secondary,
          ),
        ),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag({
    super.key,
    required this.label,
    this.color = AppColors.accentDeep,
    this.background = AppColors.accentSoft,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class MetricValue extends StatelessWidget {
  const MetricValue({
    super.key,
    required this.label,
    required this.value,
    this.unit = '大卡',
    this.accent,
    this.align = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final String unit;
  final Color? accent;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 21,
                height: 1.05,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.6,
                color: accent ?? AppColors.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.glassStrong,
              border: Border.all(color: AppColors.glassBorder),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 21, color: AppColors.accent),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.secondary,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            Pressable(
              onTap: onAction,
              haptic: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentDeep,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      CupertinoIcons.chevron_right,
                      size: 11,
                      color: AppColors.accentDeep,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.style,
    this.suffix,
    this.suffixStyle,
    this.duration = const Duration(milliseconds: 650),
  });

  final double value;
  final TextStyle style;
  final String? suffix;
  final TextStyle? suffixStyle;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 999999)),
      duration: reduceMotion ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return RepaintBoundary(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(formatCalories(animated), style: style),
              if (suffix != null) ...[
                const SizedBox(width: 6),
                Text(suffix!, style: suffixStyle),
              ],
            ],
          ),
        );
      },
    );
  }
}

class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  Timer? _timer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    if (_started) return;
    if (widget.delay == Duration.zero) {
      _started = true;
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) {
          _started = true;
          _controller.forward();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _timer?.cancel();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - animation.value)),
          child: child,
        ),
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

class SheetHeading extends StatelessWidget {
  const SheetHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.pageTitle),
                if (subtitle != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 12),
            CircleIconButton(
              icon: CupertinoIcons.xmark,
              size: 34,
              iconSize: 14,
              background: AppColors.glassStrong,
              borderColor: AppColors.glassBorder,
              onTap: onClose,
              tooltip: '关闭',
            ),
          ],
        ],
      ),
    );
  }
}

class PageTopBar extends StatelessWidget {
  const PageTopBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: AppColors.ink,
            ),
          ),
          if (leading != null) Positioned(left: 0, child: leading!),
          if (trailing != null) Positioned(right: 0, child: trailing!),
        ],
      ),
    );
  }
}

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: CupertinoIcons.chevron_left,
      onTap: onTap ?? () => Navigator.maybePop(context),
      tooltip: '返回',
      size: 38,
      iconSize: 19,
    );
  }
}

/// A modal page that rises over the scene, with a short fade so the
/// motion reads even on the web renderer.
Route<T> appSlideUpRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 440),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.fastEaseInToSlowEaseOut,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.16),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.72, end: 1).animate(curved),
          child: RepaintBoundary(child: child),
        ),
      );
    },
  );
}

Future<T?> showAppSheet<T>(
  BuildContext context,
  Widget child, {
  bool fillHeight = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x99000000),
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final bottomInset = media.viewInsets.bottom;
      final maxHeight =
          (media.size.height - bottomInset - media.padding.top - 28).clamp(
            320.0,
            media.size.height,
          );
      final sheet = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: _GlassSheet(child: child),
      );
      return Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + bottomInset),
        child: fillHeight ? SizedBox(height: maxHeight, child: sheet) : sheet,
      );
    },
  );
}

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF20C0C0D),
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        border: Border.all(color: const Color(0x1FFFFFFF), width: 1),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x3DFFFFFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        child: kIsWeb
            ? content
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: content,
              ),
      ),
    );
  }
}

Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? maximumDate,
}) {
  final initial = DateTime(
    initialDate.year,
    initialDate.month,
    initialDate.day,
  );
  final max = maximumDate ?? DateTime.now();

  if (kIsWeb) {
    return showDatePicker(
      context: context,
      initialDate: initial.isAfter(max) ? max : initial,
      firstDate: DateTime(2020),
      lastDate: max,
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              backgroundColor: const Color(0xFF161618),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  var selected = initial;
  return showCupertinoModalPopup<DateTime>(
    context: context,
    barrierColor: const Color(0x99000000),
    builder: (context) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161618),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 336,
            child: Column(
              children: [
                SizedBox(
                  height: 58,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '取消',
                          style: TextStyle(color: AppColors.secondary),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        '选择日期',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: () => Navigator.pop(context, selected),
                        child: const Text(
                          '完成',
                          style: TextStyle(
                            color: AppColors.accentDeep,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                const HairLine(),
                Expanded(
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      brightness: Brightness.dark,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          fontFamily: 'MeicanSans',
                          fontSize: 20,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: initial,
                      maximumDate: max,
                      minimumDate: DateTime(2020),
                      dateOrder: DatePickerDateOrder.ymd,
                      backgroundColor: Colors.transparent,
                      onDateTimeChanged: (value) => selected = value,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  bool showCancel = true,
  Widget? extra,
}) async {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: const Color(0x66000000),
    transitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) => Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 360,
            maxHeight: MediaQuery.sizeOf(dialogContext).height - 48,
          ),
          child: SingleChildScrollView(
            child: _GlassAlert(
              title: title,
              message: message,
              confirmLabel: confirmLabel,
              destructive: destructive,
              showCancel: showCancel,
              extra: extra,
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: RepaintBoundary(child: child),
        ),
      );
    },
  );
  return result ?? false;
}

Future<void> showAppAlert(
  BuildContext context, {
  required String title,
  required String message,
  String buttonLabel = '知道了',
  Widget? extra,
}) async {
  await showConfirmDialog(
    context,
    title: title,
    message: message,
    confirmLabel: buttonLabel,
    showCancel: false,
    extra: extra,
  );
}

class _GlassAlert extends StatelessWidget {
  const _GlassAlert({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
    this.showCancel = true,
    this.extra,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
  final bool showCancel;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
      decoration: BoxDecoration(
        color: const Color(0xE61A1A1C),
        borderRadius: BorderRadius.circular(40),
        boxShadow: kIsWeb
            ? null
            : const [
                BoxShadow(
                  color: Color(0x8C000000),
                  blurRadius: 50,
                  offset: Offset(0, 24),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: AppColors.ink,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: AppColors.secondary,
              decoration: TextDecoration.none,
            ),
          ),
          if (extra != null) ...[const SizedBox(height: 18), extra!],
          const SizedBox(height: 24),
          Row(
            children: [
              if (showCancel) ...[
                Expanded(
                  child: _AlertAction(
                    label: '取消',
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: _AlertAction(
                  label: confirmLabel,
                  destructive: destructive,
                  onTap: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: kIsWeb
          ? content
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: content,
            ),
    );
  }
}

class _AlertAction extends StatelessWidget {
  const _AlertAction({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: 0.97,
      opacity: 0.92,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x26FFFFFF),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
            color: destructive ? AppColors.danger : AppColors.ink,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

OverlayEntry? _activeToast;

void showAppMessage(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _activeToast?.remove();
  _activeToast = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (toastContext) => Positioned(
      top: MediaQuery.paddingOf(toastContext).top + 10,
      left: 20,
      right: 20,
      child: IgnorePointer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: _ToastBubble(
              message: message,
              onDismissed: () {
                if (entry.mounted) entry.remove();
                if (identical(_activeToast, entry)) _activeToast = null;
              },
            ),
          ),
        ),
      ),
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
}

class _ToastBubble extends StatelessWidget {
  const _ToastBubble({required this.message, required this.onDismissed});

  final String message;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xF0141416),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.info_circle_fill,
            size: 17,
            color: AppColors.accentDeep,
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      onEnd: () {
        Future<void>.delayed(const Duration(milliseconds: 2200), onDismissed);
      },
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, -10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: kIsWeb
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x73000000),
                      blurRadius: 30,
                      offset: Offset(0, 14),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: kIsWeb
                ? bubble
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                    child: bubble,
                  ),
          ),
        ),
      ),
    );
  }
}
