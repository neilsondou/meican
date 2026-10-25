import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import 'components.dart';
import 'converter_page.dart';
import 'meal_widgets.dart';
import 'record_page.dart';
import 'theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.state,
    required this.onCamera,
    required this.onOpenRecord,
    required this.onOpenProgress,
  });

  final AppState state;
  final VoidCallback onCamera;
  final VoidCallback onOpenRecord;
  final VoidCallback onOpenProgress;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final meals = state.mealsForDay(today)
      ..sort((first, second) => first.date.compareTo(second.date));
    final intake = state.caloriesForDay(today);
    final tdee = NutritionMath.tdee(state.profile);
    final remaining = tdee - intake;
    final over = remaining < 0;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverList.list(
            children: [
              PageHeader(
                eyebrow: DateFormat('M月d日 EEEE', 'zh_CN').format(today),
                title: '今天',
                trailing: CircleIconButton(
                  icon: CupertinoIcons.camera,
                  size: 44,
                  iconSize: 20,
                  onTap: onCamera,
                  tooltip: '拍照识别',
                ),
              ),
              const SizedBox(height: 30),
              _IntakeCard(
                intake: intake,
                tdee: tdee,
                remaining: remaining,
                over: over,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ActionPill(
                      label: '记一餐',
                      icon: CupertinoIcons.plus,
                      onPressed: () => showRecordSheet(context, state),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ActionPill(
                      label: '拍照识别',
                      icon: CupertinoIcons.camera,
                      filled: false,
                      onPressed: onCamera,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 42),
              SectionHeader(
                title: '今天吃了什么',
                actionLabel: meals.isEmpty ? null : '全部记录',
                onAction: meals.isEmpty ? null : onOpenRecord,
              ),
              if (meals.isEmpty)
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: EmptyState(
                    icon: CupertinoIcons.tray,
                    title: '还没有开动',
                    message: '记下第一餐，热量和缺口才有依据。不用追求完美，先记下来。',
                    actionLabel: '记一餐',
                    onAction: () => showRecordSheet(context, state),
                  ),
                )
              else
                GroupedCard(
                  children: [
                    for (final meal in meals)
                      MealSummaryTile(
                        meal: meal,
                        showChevron: true,
                        onTap: () => showMealDetail(
                          context,
                          meal,
                          state: state,
                          onEdit: () =>
                              showRecordSheet(context, state, meal: meal),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 42),
              _GoalPaceCard(state: state, onTap: onOpenProgress),
              const SizedBox(height: 42),
              SurfaceCard(
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const ConverterPage()),
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
                child: Row(
                  children: [
                    const IconBadge(
                      icon: CupertinoIcons.arrow_left_right,
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
                            '热量换算',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '对着包装，把千焦换成大卡，也能算清整包',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
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
              ),
              const SizedBox(height: 144),
            ],
          ),
        ),
      ],
    );
  }
}

class _IntakeCard extends StatelessWidget {
  const _IntakeCard({
    required this.intake,
    required this.tdee,
    required this.remaining,
    required this.over,
  });

  final double intake;
  final double tdee;
  final double remaining;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final ratio = tdee <= 0 ? 0.0 : (intake / tdee).clamp(0.0, 1.0);
    final percent = tdee <= 0 ? 0 : (intake / tdee * 100).round();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return SurfaceCard(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '今天已经吃了',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
              const Spacer(),
              Tag(
                label: intake <= 0 ? '还没有记录' : '$percent%',
                color: over ? AppColors.warning : AppColors.accentDeep,
                background: over
                    ? AppColors.warning.withValues(alpha: 0.14)
                    : AppColors.accentSoft,
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedNumber(
            value: intake,
            style: AppTextStyles.numericHero,
            suffix: '大卡',
            suffixStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _headline(intake, tdee, remaining, over),
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.65,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 22),
          _IntakeBar(ratio: ratio, over: over, animate: !reduceMotion),
          const SizedBox(height: 11),
          Row(
            children: [
              Text(
                '目标 ${formatCalories(tdee)} 大卡',
                style: const TextStyle(fontSize: 12, color: AppColors.tertiary),
              ),
              const Spacer(),
              Text(
                over
                    ? '超出 ${formatCalories(-remaining)} 大卡'
                    : '还可摄入 ${formatCalories(remaining)} 大卡',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: over ? AppColors.warning : AppColors.accentDeep,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _headline(double intake, double tdee, double remaining, bool over) {
    if (intake <= 0) {
      return '按下「记一餐」，今天的热量和缺口就有了依据。';
    }
    if (over) {
      return '比每天大约消耗的 ${formatCalories(tdee)} 大卡多出 ${formatCalories(-remaining)} 大卡。下一餐清淡一点，再走一走，明天继续。';
    }
    return '每天大约消耗 ${formatCalories(tdee)} 大卡，今天还可以吃 ${formatCalories(remaining)} 大卡。按现在的节奏来就好。';
  }
}

class _IntakeBar extends StatelessWidget {
  const _IntakeBar({
    required this.ratio,
    required this.over,
    required this.animate,
  });

  final double ratio;
  final bool over;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.surfaceMuted),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: animate
                  ? const Duration(milliseconds: 620)
                  : Duration.zero,
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: over
                            ? const [Color(0xFFD9A77A), AppColors.warning]
                            : const [Color(0xFF8FA98F), AppColors.accentDeep],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalPaceCard extends StatelessWidget {
  const _GoalPaceCard({required this.state, required this.onTap});

  final AppState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final weights = [...state.weights]
      ..sort((first, second) => first.date.compareTo(second.date));
    final current = weights.isEmpty ? state.profile.weightKg : weights.last.kg;
    final target = state.profile.targetWeightKg;
    final remainingKg = current - target;
    final days = state.predictDaysToTarget();
    final deficit = state.recentAverageDeficit();
    final targetDate = days == null
        ? null
        : DateTime.now().add(Duration(days: days));

    final reached = remainingKg <= 0;
    final hasPrediction = days != null && targetDate != null;

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
      elevated: true,
      borderColor: const Color(0x38FFFFFF),
      child: Stack(
        children: [
          const Positioned(right: -72, top: -92, child: _GoalRings()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '目标进程',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: AppColors.secondary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    CupertinoIcons.arrow_up_right,
                    size: 16,
                    color: AppColors.tertiary,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (reached)
                const Text('已经到达目标', style: _goalTitle)
              else if (hasPrediction)
                Text('约 $days 天后\n到达目标', style: _goalTitle)
              else
                const Text('再记录几天，\n就能看到预测', style: _goalTitle),
              const SizedBox(height: 14),
              Text(
                _caption(
                  reached: reached,
                  hasPrediction: hasPrediction,
                  targetDate: targetDate,
                  deficit: deficit,
                  target: target,
                ),
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.7,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Text(
                    '当前 ${formatNumber(current)} kg · 目标 ${formatNumber(target)} kg',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.tertiary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '看趋势',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 11,
                    color: AppColors.tertiary,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _caption({
    required bool reached,
    required bool hasPrediction,
    required DateTime? targetDate,
    required double deficit,
    required double target,
  }) {
    if (reached) {
      return '当前 ${formatNumber(state.profile.weightKg)} kg，已经比目标 ${formatNumber(target)} kg 更轻。保持现在的节奏就好。';
    }
    if (hasPrediction) {
      return '预计 ${DateFormat('M月d日').format(targetDate!)} 前后到达。还需减掉约 ${formatNumber((state.profile.weightKg - target) * 2)} 斤，按近期日均缺口 ${formatCalories(deficit)} 大卡推算。';
    }
    return '连续记录几天饮食后，会按近期的热量缺口，推算到达目标的日子。';
  }
}

const _goalTitle = TextStyle(
  fontSize: 28,
  height: 1.22,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.7,
  color: AppColors.ink,
);

class _GoalRings extends StatelessWidget {
  const _GoalRings();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x14FFFFFF), width: 26),
      ),
    );
  }
}
