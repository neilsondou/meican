import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import 'components.dart';
import 'theme.dart';

class MealVisual {
  const MealVisual({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;
}

MealVisual mealVisual(String mealType) => switch (mealType) {
  '早餐' => const MealVisual(
    icon: CupertinoIcons.sunrise,
    color: Color(0xFFD9A77A),
    background: Color(0x1FD9A77A),
  ),
  '午餐' => const MealVisual(
    icon: CupertinoIcons.sun_max,
    color: AppColors.accentDeep,
    background: AppColors.accentSoft,
  ),
  '晚餐' => const MealVisual(
    icon: CupertinoIcons.moon_stars,
    color: Color(0xFFA9B7C9),
    background: Color(0x1FA9B7C9),
  ),
  _ => const MealVisual(
    icon: CupertinoIcons.sparkles,
    color: AppColors.warning,
    background: Color(0x1FE29379),
  ),
};

String mealPreview(MealEntry meal) {
  if (meal.items.isEmpty) return '没有食物明细';
  final names = meal.items.map((item) => item.name).toList();
  if (names.length <= 3) return names.join(' · ');
  return '${names.take(3).join(' · ')} 等 ${names.length} 种';
}

class MealSummaryTile extends StatelessWidget {
  const MealSummaryTile({
    super.key,
    required this.meal,
    this.onTap,
    this.showChevron = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  });

  final MealEntry meal;
  final VoidCallback? onTap;
  final bool showChevron;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final visual = mealVisual(meal.mealType);
    final time = DateFormat('HH:mm').format(meal.date);
    final source = meal.source == 'ai' ? ' · AI 识别' : '';

    final content = Padding(
      padding: padding,
      child: Row(
        children: [
          IconBadge(
            icon: visual.icon,
            color: visual.color,
            background: visual.background,
            size: 44,
            iconSize: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      meal.mealType,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        '$time$source',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  mealPreview(meal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCalories(meal.totalKcal),
                style: AppTextStyles.numericInline,
              ),
              const Text(
                '大卡',
                style: TextStyle(
                  fontSize: 9.5,
                  color: AppColors.tertiary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          if (showChevron) ...[
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 13,
              color: AppColors.tertiary,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return Pressable(onTap: onTap, scale: 0.99, child: content);
  }
}

void showMealDetail(BuildContext context, MealEntry meal, {AppState? state}) {
  showAppSheet<void>(context, _MealDetailSheet(meal: meal, state: state));
}

class _MealDetailSheet extends StatelessWidget {
  const _MealDetailSheet({required this.meal, this.state});

  final MealEntry meal;
  final AppState? state;

  Future<void> _delete(BuildContext context) async {
    final appState = state;
    if (appState == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '删除这条记录？',
      message:
          '${meal.mealType} · ${formatCalories(meal.totalKcal)} 大卡，删除后无法恢复。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await appState.deleteMeal(meal.id);
    if (context.mounted) {
      Navigator.pop(context);
      showAppMessage(context, '已删除这条记录');
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = mealVisual(meal.mealType);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeading(
            title: meal.mealType,
            subtitle:
                '${DateFormat('M月d日 HH:mm').format(meal.date)} · 共 ${formatCalories(meal.totalKcal)} 大卡',
            onClose: () => Navigator.pop(context),
          ),
          if (meal.items.isEmpty)
            const Text(
              '这一餐没有留下食物明细。',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppColors.secondary,
              ),
            )
          else
            GroupedCard(
              children: [
                for (var index = 0; index < meal.items.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        Icon(visual.icon, size: 15, color: AppColors.tertiary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meal.items[index].name,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${formatNumber(meal.items[index].grams)} 克',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${formatCalories(meal.items[index].kcal)} 大卡',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          if (meal.note.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              '备注',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: AppColors.tertiary,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              meal.note,
              style: const TextStyle(
                fontSize: 14,
                height: 1.65,
                color: AppColors.secondary,
              ),
            ),
          ],
          if (state != null) ...[
            const SizedBox(height: 18),
            Pressable(
              onTap: () => _delete(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.trash,
                      size: 16,
                      color: AppColors.danger,
                    ),
                    SizedBox(width: 7),
                    Text(
                      '删除这条记录',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
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
