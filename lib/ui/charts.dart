import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import 'theme.dart';

class WeightTrendChart extends StatelessWidget {
  const WeightTrendChart({
    super.key,
    required this.entries,
    required this.target,
    this.height = 136,
  });

  final List<WeightEntry> entries;
  final double target;
  final double height;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) {
          return RepaintBoundary(
            child: CustomPaint(
              painter: _WeightPainter(
                entries: entries,
                target: target,
                progress: progress,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WeightPainter extends CustomPainter {
  const _WeightPainter({
    required this.entries,
    required this.target,
    required this.progress,
  });

  final List<WeightEntry> entries;
  final double target;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty || size.width <= 0) return;
    final values = entries.map((entry) => entry.kg).toList();
    final includeTarget =
        target >= values.reduce(math.min) - 2 &&
        target <= values.reduce(math.max) + 2;
    var low = values.reduce(math.min);
    var high = values.reduce(math.max);
    if (includeTarget) {
      low = math.min(low, target);
      high = math.max(high, target);
    }
    final span = math.max(1.0, high - low);
    final minValue = low - span * 0.22;
    final maxValue = high + span * 0.22;
    const inset = 9.0;
    final chartHeight = size.height - inset * 2;

    Offset point(int index) {
      final x = entries.length == 1
          ? size.width / 2
          : size.width * index / (entries.length - 1);
      final y =
          inset +
          chartHeight -
          chartHeight * (values[index] - minValue) / (maxValue - minValue);
      return Offset(x, y);
    }

    if (includeTarget) {
      final targetY =
          inset +
          chartHeight -
          chartHeight * (target - minValue) / (maxValue - minValue);
      _dashedLine(
        canvas,
        Offset(0, targetY),
        Offset(size.width, targetY),
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.32)
          ..strokeWidth = 1,
      );
    }

    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var index = 1; index < entries.length; index++) {
      final previous = point(index - 1);
      final current = point(index);
      final middle = (previous.dx + current.dx) / 2;
      line.cubicTo(
        middle,
        previous.dy,
        middle,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.accent.withValues(alpha: 0.20),
            AppColors.accent.withValues(alpha: 0.01),
          ],
        ).createShader(Offset.zero & size),
    );

    if (progress < 1) {
      final metric = line.computeMetrics().first;
      final partial = metric.extractPath(0, metric.length * progress);
      canvas.drawPath(
        partial,
        Paint()
          ..color = AppColors.accentDeep
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawPath(
        line,
        Paint()
          ..color = AppColors.accentDeep
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }

    if (progress > 0.5) {
      final dotOpacity = ((progress - 0.5) * 2).clamp(0.0, 1.0);
      for (var index = 0; index < entries.length; index++) {
        final center = point(index);
        final last = index == entries.length - 1;
        if (last) {
          canvas.drawCircle(
            center,
            6,
            Paint()..color = AppColors.ink.withValues(alpha: dotOpacity),
          );
          canvas.drawCircle(
            center,
            3.2,
            Paint()..color = AppColors.accentDeep.withValues(alpha: dotOpacity),
          );
        } else {
          canvas.drawCircle(
            center,
            2.4,
            Paint()..color = AppColors.accentDeep.withValues(alpha: dotOpacity),
          );
        }
      }
    }
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 4.0;
    const gap = 5.0;
    var x = from.dx;
    while (x < to.dx) {
      canvas.drawLine(
        Offset(x, from.dy),
        Offset(math.min(x + dash, to.dx), to.dy),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _WeightPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.target != target ||
      oldDelegate.entries != entries;
}

class BodyFatTrendChart extends StatelessWidget {
  const BodyFatTrendChart({super.key, required this.values, this.height = 94});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) {
          return RepaintBoundary(
            child: CustomPaint(
              painter: _BodyFatPainter(values: values, progress: progress),
            ),
          );
        },
      ),
    );
  }
}

class _BodyFatPainter extends CustomPainter {
  const _BodyFatPainter({required this.values, required this.progress});

  final List<double> values;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0) return;
    const inset = 8.0;
    final chartHeight = size.height - inset * 2;
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final span = math.max(1.5, high - low);
    final minValue = low - span * 0.28;
    final maxValue = high + span * 0.28;

    Offset point(int index) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final y =
          inset +
          chartHeight -
          chartHeight * (values[index] - minValue) / (maxValue - minValue);
      return Offset(x, y);
    }

    if (values.length == 1) {
      final center = point(0);
      canvas.drawCircle(
        center,
        4,
        Paint()..color = AppColors.warm.withValues(alpha: progress),
      );
      return;
    }

    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var index = 1; index < values.length; index++) {
      final previous = point(index - 1);
      final current = point(index);
      final middle = (previous.dx + current.dx) / 2;
      line.cubicTo(
        middle,
        previous.dy,
        middle,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.warm.withValues(alpha: 0.16),
            AppColors.warm.withValues(alpha: 0.01),
          ],
        ).createShader(Offset.zero & size),
    );

    final metric = line.computeMetrics().first;
    final partial = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      partial,
      Paint()
        ..color = AppColors.warm
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    if (progress > 0.65) {
      final opacity = ((progress - 0.65) / 0.35).clamp(0.0, 1.0);
      final last = point(values.length - 1);
      canvas.drawCircle(
        last,
        5,
        Paint()..color = AppColors.ink.withValues(alpha: opacity),
      );
      canvas.drawCircle(
        last,
        2.6,
        Paint()..color = AppColors.warm.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BodyFatPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.values != values;
}

class DailyIntake {
  const DailyIntake({
    required this.day,
    required this.kcal,
    required this.recorded,
  });

  final DateTime day;
  final double kcal;
  final bool recorded;
}

class IntakeWeekChart extends StatelessWidget {
  const IntakeWeekChart({
    super.key,
    required this.days,
    required this.tdee,
    this.height = 118,
  });

  final List<DailyIntake> days;
  final double tdee;
  final double height;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 760),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) => RepaintBoundary(
              child: CustomPaint(
                painter: _IntakePainter(
                  days: days,
                  tdee: tdee,
                  progress: progress,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final day in days)
              Expanded(
                child: Text(
                  _weekdays[day.day.weekday - 1],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: _isToday(day.day)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _isToday(day.day)
                        ? AppColors.accentDeep
                        : AppColors.tertiary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }
}

class _IntakePainter extends CustomPainter {
  const _IntakePainter({
    required this.days,
    required this.tdee,
    required this.progress,
  });

  final List<DailyIntake> days;
  final double tdee;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty || size.width <= 0) return;
    final maxKcal = days.fold<double>(
      tdee,
      (max, day) => math.max(max, day.kcal),
    );
    final maxValue = math.max(1.0, maxKcal * 1.16);
    final slot = size.width / days.length;
    final barWidth = math.min(18.0, slot * 0.42);

    final tdeeY = size.height - size.height * (tdee / maxValue);
    _dashedLine(
      canvas,
      Offset(0, tdeeY),
      Offset(size.width, tdeeY),
      Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.30)
        ..strokeWidth = 1,
    );

    for (var index = 0; index < days.length; index++) {
      final day = days[index];
      final left = slot * index + (slot - barWidth) / 2;
      final radius = Radius.circular(barWidth / 2);
      final baseRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, barWidth, size.height),
        radius,
      );
      canvas.drawRRect(
        baseRect,
        Paint()..color = AppColors.ink.withValues(alpha: 0.06),
      );
      if (!day.recorded) continue;
      final barHeight =
          (size.height * (day.kcal / maxValue)).clamp(4.0, size.height) *
          progress;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - barHeight, barWidth, barHeight),
        radius,
      );
      final today = IntakeWeekChart._isToday(day.day);
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: today
                ? const [Color(0xFFD5E2D2), AppColors.accent]
                : const [Color(0xFF93A593), Color(0xFF6E826F)],
          ).createShader(rect.outerRect),
      );
    }
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 4.0;
    const gap = 5.0;
    var x = from.dx;
    while (x < to.dx) {
      canvas.drawLine(
        Offset(x, from.dy),
        Offset(math.min(x + dash, to.dx), to.dy),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _IntakePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.tdee != tdee ||
      oldDelegate.days != days;
}
