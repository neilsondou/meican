import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../glm_service.dart';
import '../models.dart';
import 'charts.dart';
import 'components.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'weight_import.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final weights = state.sortedWeights;
    final current = state.currentWeightKg;
    final target = state.profile.targetWeightKg;
    final unit = state.profile.weightUnit;
    final recent = weights.length > 12
        ? weights.sublist(weights.length - 12)
        : weights;
    final days = state.predictDaysToTarget();
    final deficit = state.recentAverageDeficit();
    final targetDate = days == null
        ? null
        : DateTime.now().add(Duration(days: days));

    final now = DateTime.now();
    final intakeDays = List<DailyIntake>.generate(7, (index) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - index));
      final meals = state.mealsForDay(day);
      return DailyIntake(
        day: day,
        kcal: meals.fold(0, (sum, meal) => sum + meal.totalKcal),
        recorded: meals.isNotEmpty,
      );
    });
    final recordedDays = intakeDays.where((day) => day.recorded).length;
    final averageIntake = recordedDays == 0
        ? 0.0
        : intakeDays.fold(0.0, (sum, day) => sum + day.kcal) / recordedDays;
    final tdee = NutritionMath.tdee(state.profile);

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
                eyebrow: '身体与目标',
                title: '趋势',
                trailing: CircleIconButton(
                  icon: CupertinoIcons.add,
                  size: 44,
                  iconSize: 21,
                  onTap: () => showWeightSheet(context, state),
                  tooltip: '记录体重',
                ),
              ),
              const SizedBox(height: 28),
              _WeightCard(
                entries: weights,
                recent: recent,
                current: current,
                target: target,
                unit: unit,
                onAdd: () => showWeightSheet(context, state),
                onImport: () => showWeightImport(context, state),
              ),
              const SizedBox(height: 16),
              _PredictionCard(
                current: current,
                target: target,
                days: days,
                targetDate: targetDate,
                deficit: deficit,
                unit: unit,
              ),
              const SizedBox(height: 16),
              _BodyFatCard(state: state, entries: weights, current: current),
              const SizedBox(height: 16),
              _AiAdviceCard(state: state),
              const SizedBox(height: 42),
              const SectionHeader(title: '最近七天'),
              _IntakeCard(
                days: intakeDays,
                tdee: tdee,
                averageIntake: averageIntake,
                recordedDays: recordedDays,
                averageDeficit: deficit,
              ),
              const SizedBox(height: 42),
              SectionHeader(
                title: '身体数据',
                actionLabel: '编辑',
                onAction: () => showProfileSheet(context, state),
              ),
              _BodyMetrics(state: state),
              const SizedBox(height: 42),
              SectionHeader(
                title: '体重记录',
                actionLabel: weights.isEmpty ? null : '记录',
                onAction: weights.isEmpty
                    ? null
                    : () => showWeightSheet(context, state),
              ),
              if (weights.isEmpty)
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: EmptyState(
                    icon: CupertinoIcons.gauge,
                    title: '记录今天的体重',
                    message: '固定时间、相近状态测量，趋势才有意义。一天一次就够了。',
                    actionLabel: '记录体重',
                    onAction: () => showWeightSheet(context, state),
                  ),
                )
              else
                _WeightLog(state: state, entries: weights),
              if (weights.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
                  child: Text(
                    '轻点一条记录可以修改日期和数值，左滑删除。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.tertiary,
                    ),
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

class _WeightCard extends StatelessWidget {
  const _WeightCard({
    required this.entries,
    required this.recent,
    required this.current,
    required this.target,
    required this.unit,
    required this.onAdd,
    required this.onImport,
  });

  final List<WeightEntry> entries;
  final List<WeightEntry> recent;
  final double current;
  final double target;
  final WeightUnit unit;
  final VoidCallback onAdd;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final previous = entries.length >= 2
        ? entries[entries.length - 2].kg
        : null;
    final delta = previous == null ? null : current - previous;
    final targetGap = current - target;

    return SurfaceCard(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '当前体重',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
              const Spacer(),
              Tag(
                label: '目标 ${unit.format(target)}',
                color: AppColors.accentDeep,
                background: AppColors.accentSoft,
                icon: CupertinoIcons.flag,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                unit.formatValue(current),
                style: AppTextStyles.numericLarge,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 7, bottom: 4),
                child: Text(
                  unit.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const Spacer(),
              if (delta != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _DeltaLabel(delta: delta, unit: unit),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    targetGap > 0 ? '距目标 ${unit.format(targetGap)}' : '已在目标之内',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          if (recent.length < 2)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '再记录一次体重，就能看到变化曲线。',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.7,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 10),
                _WeightTextAction(label: '记录今天的体重', onTap: onAdd),
                const SizedBox(height: 2),
                _WeightTextAction(
                  label: '从截图导入体重',
                  icon: CupertinoIcons.photo,
                  onTap: onImport,
                ),
              ],
            )
          else ...[
            WeightTrendChart(entries: recent, target: target, height: 144),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  DateFormat('M月d日').format(recent.first.date),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.tertiary,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '目标线',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Text(
                  DateFormat('M月d日').format(recent.last.date),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _WeightTextAction(
              label: '从截图导入体重',
              icon: CupertinoIcons.photo,
              onTap: onImport,
            ),
          ],
        ],
      ),
    );
  }
}

class _WeightTextAction extends StatelessWidget {
  const _WeightTextAction({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: AppColors.accentDeep),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
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
    );
  }
}

class _DeltaLabel extends StatelessWidget {
  const _DeltaLabel({required this.delta, required this.unit});

  final double delta;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final down = delta < 0;
    final flat = delta.abs() < 0.05;
    final color = flat
        ? AppColors.tertiary
        : down
        ? AppColors.accentDeep
        : AppColors.warm;
    final text = flat
        ? '与上次持平'
        : '${down ? '↓' : '↑'} ${unit.format(delta.abs())}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({
    required this.current,
    required this.target,
    required this.days,
    required this.targetDate,
    required this.deficit,
    required this.unit,
  });

  final double current;
  final double target;
  final int? days;
  final DateTime? targetDate;
  final double deficit;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final remaining = current - target;
    final reached = remaining <= 0;
    final hasPrediction = days != null && targetDate != null;

    return SurfaceCard(
      elevated: true,
      borderColor: const Color(0x38FFFFFF),
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      child: Stack(
        children: [
          const Positioned(right: -76, top: -96, child: _PredictionGlow()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '减重预测',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 18),
              if (reached)
                const Text('已经到达目标', style: _predictionTitle)
              else if (hasPrediction)
                Text('约 $days 天后\n到达目标', style: _predictionTitle)
              else
                const Text('再记录几天，\n就能看到预测', style: _predictionTitle),
              const SizedBox(height: 14),
              Text(
                reached
                    ? '当前 ${unit.format(current)}，已经在目标 ${unit.format(target)} 之内。保持现在的节奏就好。'
                    : hasPrediction
                    ? '预计 ${DateFormat('yyyy年M月d日').format(targetDate!)} 前后达成。按过去 7 天有记录日子的日均缺口 ${formatCalories(deficit)} 大卡推算。'
                    : '连续记录几天饮食后，会按近期有记录日子的热量缺口，推算到达目标的日子。',
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.7,
                  color: AppColors.secondary,
                ),
              ),
              if (!reached) ...[
                const SizedBox(height: 18),
                Text(
                  unit == WeightUnit.kilograms
                      ? '还需减掉约 ${unit.format(remaining)} · ${WeightUnit.jin.format(remaining)}'
                      : '还需减掉约 ${unit.format(remaining)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Text(
                '按每公斤脂肪约 7700 大卡估算，只用来观察长期趋势。',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.55,
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _predictionTitle = TextStyle(
  fontSize: 28,
  height: 1.22,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.7,
  color: AppColors.ink,
);

class _PredictionGlow extends StatelessWidget {
  const _PredictionGlow();

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

class _BodyFatCard extends StatelessWidget {
  const _BodyFatCard({
    required this.state,
    required this.entries,
    required this.current,
  });

  final AppState state;
  final List<WeightEntry> entries;
  final double current;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    final unit = profile.weightUnit;
    final percent = NutritionMath.bodyFatPercent(profile, weightKg: current);
    final category = NutritionMath.bodyFatLabel(percent, profile.sex);
    final fatMass = current * percent / 100;
    final leanMass = current - fatMass;
    final history = [
      for (final entry in entries)
        NutritionMath.bodyFatPercent(profile, weightKg: entry.kg),
    ];
    final recent = history.length > 12
        ? history.sublist(history.length - 12)
        : history;
    final previous = entries.length >= 2
        ? NutritionMath.bodyFatPercent(
            profile,
            weightKg: entries[entries.length - 2].kg,
          )
        : null;
    final delta = previous == null ? null : percent - previous;
    final categoryColor = category == '标准'
        ? AppColors.accentDeep
        : category == '偏高'
        ? AppColors.warm
        : category == '较高'
        ? AppColors.warning
        : AppColors.secondary;

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '体脂估算',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
              const Spacer(),
              Tag(
                label: category,
                color: categoryColor,
                background: categoryColor.withValues(alpha: 0.12),
                icon: CupertinoIcons.drop,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                percent.toStringAsFixed(1),
                style: AppTextStyles.numericLarge,
              ),
              const Padding(
                padding: EdgeInsets.only(left: 2, bottom: 4),
                child: Text(
                  '%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const Spacer(),
              if (delta != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    delta.abs() < 0.05
                        ? '与上次持平'
                        : '较上次 ${delta < 0 ? '↓' : '↑'} ${delta.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: delta.abs() < 0.05
                          ? AppColors.tertiary
                          : delta < 0
                          ? AppColors.accentDeep
                          : AppColors.warm,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '脂肪量约 ${unit.format(fatMass)} · 瘦体重约 ${unit.format(leanMass)}',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.secondary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (recent.length >= 2) ...[
            const SizedBox(height: 18),
            BodyFatTrendChart(values: recent),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  DateFormat(
                    'M月d日',
                  ).format(entries[entries.length - recent.length].date),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.tertiary,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('M月d日').format(entries.last.date),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.tertiary,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 16),
            const Text(
              '记录两次以上体重后，这里会显示体脂率的变化趋势。',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: AppColors.tertiary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            '按身高、年龄、性别和当前体重自动估算，只适合观察长期方向，不能替代体脂秤或医学检测。',
            style: TextStyle(
              fontSize: 11,
              height: 1.6,
              color: AppColors.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiAdviceCard extends StatefulWidget {
  const _AiAdviceCard({required this.state});

  final AppState state;

  @override
  State<_AiAdviceCard> createState() => _AiAdviceCardState();
}

class _AiAdviceCardState extends State<_AiAdviceCard> {
  static const int _cooldownSeconds = 10;

  final GlmService _service = GlmService();
  bool _loading = false;
  String? _advice;
  String? _error;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  bool get _canGenerate => !_loading && _cooldown == 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_canGenerate) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final advice = await _service.advise(data: _buildPayload());
      if (!mounted) return;
      setState(() {
        _advice = advice.isEmpty ? '这次没有生成有效建议，请稍后再试。' : advice;
      });
    } on GlmException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'AI 建议暂时不可用，请稍后重试。');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _startCooldown();
      }
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = _cooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldown -= 1;
        if (_cooldown <= 0) {
          _cooldown = 0;
          timer.cancel();
        }
      });
    });
  }

  Map<String, Object?> _buildPayload() {
    final state = widget.state;
    final profile = state.profile;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.subtract(const Duration(days: 29));
    final recentWeights = state.sortedWeights
        .where((entry) => !entry.date.isBefore(cutoff))
        .toList();
    final recentMeals =
        state.meals.where((meal) => !meal.date.isBefore(cutoff)).toList()
          ..sort((first, second) => first.date.compareTo(second.date));

    final mealsByDay = <String, Map<String, Object?>>{};
    for (final meal in recentMeals) {
      final date = DateFormat('yyyy-MM-dd').format(meal.date);
      final day = mealsByDay.putIfAbsent(
        date,
        () => {'日期': date, '总热量kcal': 0, '餐次': <Map<String, Object?>>[]},
      );
      final mealData = <String, Object?>{
        '餐次': meal.mealType,
        '热量kcal': meal.totalKcal.round(),
        if (meal.items.isNotEmpty)
          '食物': [
            for (final item in meal.items)
              {'名称': item.name, '克数': item.grams, '热量kcal': item.kcal.round()},
          ],
        if (meal.note.trim().isNotEmpty) '备注': meal.note.trim(),
      };
      (day['餐次'] as List<Map<String, Object?>>).add(mealData);
      day['总热量kcal'] = (day['总热量kcal'] as int) + meal.totalKcal.round();
    }

    var recordedDays = 0;
    var intakeTotal = 0.0;
    for (var offset = 0; offset < 7; offset++) {
      final day = today.subtract(Duration(days: offset));
      final meals = state.mealsForDay(day);
      if (meals.isEmpty) continue;
      recordedDays++;
      intakeTotal += meals.fold<double>(0, (sum, meal) => sum + meal.totalKcal);
    }
    final averageIntake = recordedDays == 0 ? 0.0 : intakeTotal / recordedDays;
    final currentWeight = state.currentWeightKg;
    final bodyFat = NutritionMath.bodyFatPercent(
      profile,
      weightKg: currentWeight,
    );

    return {
      '今天': DateFormat('yyyy-MM-dd').format(now),
      '资料': {
        '性别': profile.sex == 'male' ? '男' : '女',
        '年龄': profile.age,
        '身高cm': profile.heightCm,
        '当前体重kg': currentWeight,
        '目标体重kg': profile.targetWeightKg,
        '活动水平': activityLabel(profile.activity),
      },
      '代谢与体脂估算': {
        '基础代谢kcal': NutritionMath.bmr(profile).round(),
        '每日总消耗kcal': NutritionMath.tdee(profile).round(),
        '体脂率百分比': double.parse(bodyFat.toStringAsFixed(1)),
        '体脂分类': NutritionMath.bodyFatLabel(bodyFat, profile.sex),
      },
      '最近7天': {
        '有饮食记录天数': recordedDays,
        '有记录日子的日均摄入kcal': averageIntake.round(),
        '近期平均每日热量缺口kcal': state.recentAverageDeficit().round(),
        '预计还需天数': state.predictDaysToTarget(),
      },
      '最近30天体重记录': [
        for (final entry in recentWeights)
          {'日期': DateFormat('yyyy-MM-dd').format(entry.date), '体重kg': entry.kg},
      ],
      '最近30天饮食记录': mealsByDay.values.toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasAdvice = _advice != null;
    final buttonLabel = _loading
        ? '正在生成建议'
        : _cooldown > 0
        ? '$_cooldown 秒后可再次生成'
        : hasAdvice
        ? '重新生成建议'
        : '生成 AI 建议';

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.sparkles,
                size: 15,
                color: AppColors.accentDeep,
              ),
              const SizedBox(width: 7),
              const Text(
                'AI 建议',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
              const Spacer(),
              if (hasAdvice && !_loading)
                const Tag(
                  label: '已生成',
                  color: AppColors.accentDeep,
                  background: AppColors.accentSoft,
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '结合最近 30 天的体重和饮食记录，让 AI 给出一段简短的调整建议。',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.7,
              color: AppColors.secondary,
            ),
          ),
          if (_advice != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x2EFFFFFF)),
              ),
              child: Text(
                _advice!,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.8,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: AppColors.warning,
              ),
            ),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            label: buttonLabel,
            icon: hasAdvice
                ? CupertinoIcons.arrow_clockwise
                : CupertinoIcons.sparkles,
            busy: _loading,
            onPressed: _canGenerate ? _generate : null,
          ),
          const SizedBox(height: 10),
          const Text(
            '点击后会把资料、体重和饮食记录发送给 AI 服务，不会上传照片。建议仅供参考，不能替代医生或营养师。',
            style: TextStyle(
              fontSize: 11,
              height: 1.6,
              color: AppColors.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntakeCard extends StatelessWidget {
  const _IntakeCard({
    required this.days,
    required this.tdee,
    required this.averageIntake,
    required this.recordedDays,
    required this.averageDeficit,
  });

  final List<DailyIntake> days;
  final double tdee;
  final double averageIntake;
  final int recordedDays;
  final double averageDeficit;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '日均摄入',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (recordedDays == 0)
                      const Text('—', style: AppTextStyles.numericCard)
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formatCalories(averageIntake),
                            style: AppTextStyles.numericCard,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            '大卡',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Tag(
                label: recordedDays == 0 ? '暂无记录' : '记录了 $recordedDays 天',
                color: recordedDays == 0
                    ? AppColors.secondary
                    : AppColors.accentDeep,
                background: recordedDays == 0
                    ? AppColors.surfaceMuted
                    : AppColors.accentSoft,
              ),
            ],
          ),
          const SizedBox(height: 24),
          IntakeWeekChart(days: days, tdee: tdee, height: 128),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: HairLine(),
          ),
          Text(
            _sentence(),
            style: const TextStyle(
              fontSize: 13,
              height: 1.7,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '只统计有饮食记录的日子，虚线是每天大约消耗的 ${formatCalories(tdee)} 大卡。',
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: AppColors.tertiary,
            ),
          ),
        ],
      ),
    );
  }

  String _sentence() {
    if (recordedDays == 0) {
      return '这七天还没有饮食记录。记下几餐后，这里会出现你的节奏。';
    }
    if (averageDeficit > 0) {
      return '记录了 $recordedDays 天，日均 ${formatCalories(averageIntake)} 大卡。按每天大约消耗 ${formatCalories(tdee)} 大卡算，平均每天留下 ${formatCalories(averageDeficit)} 大卡的缺口。';
    }
    if (averageDeficit < 0) {
      return '记录了 $recordedDays 天，日均 ${formatCalories(averageIntake)} 大卡。按每天大约消耗 ${formatCalories(tdee)} 大卡算，平均每天多出 ${formatCalories(-averageDeficit)} 大卡。';
    }
    return '记录了 $recordedDays 天，日均 ${formatCalories(averageIntake)} 大卡，和每天大约消耗的 ${formatCalories(tdee)} 大卡基本持平。';
  }
}

class _BodyMetrics extends StatelessWidget {
  const _BodyMetrics({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    final bmr = NutritionMath.bmr(profile);
    final tdee = NutritionMath.tdee(profile);

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '基础代谢约 ${formatCalories(bmr)} 大卡。按「${activityLabel(profile.activity)}」的活动量，每天大约消耗 ${formatCalories(tdee)} 大卡。',
            style: const TextStyle(
              fontSize: 14,
              height: 1.75,
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

class _WeightLog extends StatelessWidget {
  const _WeightLog({required this.state, required this.entries});

  final AppState state;
  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    final descending = entries.reversed.toList();
    final unit = state.profile.weightUnit;
    return GroupedCard(
      children: [
        for (var index = 0; index < descending.length; index++)
          Dismissible(
            key: ValueKey(descending[index].id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => showConfirmDialog(
              context,
              title: '删除这条体重记录？',
              message:
                  '${DateFormat('M月d日').format(descending[index].date)} · ${unit.format(descending[index].kg)}',
              confirmLabel: '删除',
              destructive: true,
            ),
            onDismissed: (_) async {
              await state.deleteWeight(descending[index].id);
              if (context.mounted) showAppMessage(context, '已删除体重记录');
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 22),
              decoration: const BoxDecoration(color: AppColors.warning),
              child: const Icon(
                CupertinoIcons.delete,
                color: AppColors.background,
                size: 19,
              ),
            ),
            child: GroupedRow(
              onTap: () =>
                  showWeightSheet(context, state, entry: descending[index]),
              leading: IconBadge(
                icon: index == 0
                    ? CupertinoIcons.sparkles
                    : CupertinoIcons.gauge,
                color: AppColors.accentDeep,
                background: AppColors.accentSoft,
                size: 38,
                iconSize: 17,
              ),
              title: DateFormat(
                'M月d日 EEEE',
                'zh_CN',
              ).format(descending[index].date),
              subtitle: index == 0 ? '最近一次 · 轻点修改' : '轻点修改',
              detail: unit.format(descending[index].kg),
            ),
          ),
      ],
    );
  }
}

Future<void> showWeightSheet(
  BuildContext context,
  AppState state, {
  WeightEntry? entry,
}) {
  return showAppSheet<void>(context, _WeightSheet(state: state, entry: entry));
}

class _WeightSheet extends StatefulWidget {
  const _WeightSheet({required this.state, this.entry});

  final AppState state;
  final WeightEntry? entry;

  @override
  State<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<_WeightSheet> {
  late final WeightUnit unit = widget.state.profile.weightUnit;
  late final DateTime initialDay = widget.entry?.date ?? DateTime.now();
  late DateTime selectedDate = DateTime(
    initialDay.year,
    initialDay.month,
    initialDay.day,
  );
  late final TextEditingController controller = TextEditingController(
    text: unit.formatValue(
      widget.entry?.kg ??
          widget.state.weightOnDay(initialDay)?.kg ??
          widget.state.profile.weightKg,
    ),
  );
  bool saving = false;

  bool get editing => widget.entry != null;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final picked = await showAppDatePicker(
      context,
      initialDate: selectedDate,
      maximumDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> save() async {
    if (saving) return;
    final raw = double.tryParse(controller.text.trim().replaceAll(',', ''));
    final kg = raw == null ? null : unit.toKilograms(raw);
    if (kg == null || !kg.isFinite || kg < 25 || kg > 400) {
      showAppMessage(
        context,
        unit == WeightUnit.jin
            ? '请输入 50–800 市斤之间的有效体重'
            : '请输入 25–400 公斤之间的有效体重',
      );
      return;
    }

    final conflict = widget.state.weightOnDay(selectedDate);
    if (conflict != null && conflict.id != widget.entry?.id) {
      final confirmed = await showConfirmDialog(
        context,
        title: '覆盖同日体重？',
        message:
            '${DateFormat('M月d日').format(selectedDate)} 已有 ${unit.format(conflict.kg)}，保存后只保留这次填写的数值。',
        confirmLabel: '覆盖',
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => saving = true);
    await widget.state.upsertWeight(
      WeightEntry(
        id:
            widget.entry?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        date: selectedDate,
        kg: kg,
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
    final today = DateTime.now();
    final isToday =
        selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
    showAppMessage(
      context,
      editing
          ? '已更新 ${DateFormat('M月d日').format(selectedDate)} 体重'
          : isToday
          ? '已记录今日体重'
          : '已补录 ${DateFormat('M月d日').format(selectedDate)} 体重',
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeading(
            title: editing ? '修改体重' : '记录体重',
            subtitle: '同一个自然日只保留最后一次；补录旧日期不会改变更新的当前体重。',
            onClose: () => Navigator.pop(context),
          ),
          GroupedCard(
            children: [
              GroupedRow(
                title: '日期',
                subtitle: DateFormat(
                  'yyyy年M月d日 EEEE',
                  'zh_CN',
                ).format(selectedDate),
                leading: const IconBadge(
                  icon: CupertinoIcons.calendar,
                  color: AppColors.accentDeep,
                  background: AppColors.accentSoft,
                  size: 38,
                  iconSize: 17,
                ),
                onTap: pickDate,
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: !editing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.numericLarge,
            decoration: InputDecoration(
              labelText: isToday ? '今天的体重' : '这一天的体重',
              suffixText: unit.label,
            ),
            onSubmitted: (_) => save(),
          ),
          const SizedBox(height: 12),
          Text(
            unit == WeightUnit.kilograms
                ? '固定时间、相近状态测量，趋势会更有意义。'
                : '当前按市斤显示，直接填写市斤数，例如 130.4 市斤等于 65.2 公斤。',
            style: const TextStyle(
              fontSize: 12,
              height: 1.6,
              color: AppColors.tertiary,
            ),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: editing ? '保存修改' : '保存',
            busy: saving,
            onPressed: save,
          ),
        ],
      ),
    );
  }
}
