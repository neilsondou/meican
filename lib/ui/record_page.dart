import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../food_data.dart';
import '../models.dart';
import 'components.dart';
import 'meal_widgets.dart';
import 'theme.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key, required this.state, required this.onCamera});

  final AppState state;
  final VoidCallback onCamera;

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  DateTime selectedDate = _dateOnly(DateTime.now());

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _startOfWeek(DateTime value) =>
      _dateOnly(value).subtract(Duration(days: value.weekday - 1));

  DateTime get _today => _dateOnly(DateTime.now());
  DateTime get _weekStart => _startOfWeek(selectedDate);
  DateTime get _currentWeekStart => _startOfWeek(_today);
  bool get _isCurrentWeek => _weekStart == _currentWeekStart;
  bool get _isToday => selectedDate == _today;

  Future<void> _pickDate() async {
    final date = await showAppDatePicker(
      context,
      initialDate: selectedDate,
      maximumDate: _today,
    );
    if (date != null) {
      setState(() => selectedDate = _dateOnly(date));
    }
  }

  void _shiftWeek(int weeks) {
    final next = _weekStart.add(Duration(days: 7 * weeks));
    if (next.isAfter(_currentWeekStart)) {
      setState(() => selectedDate = _today);
      return;
    }
    final candidate = next.add(Duration(days: selectedDate.weekday - 1));
    setState(() {
      selectedDate = candidate.isAfter(_today) ? _today : candidate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final meals = widget.state.mealsForDay(selectedDate)
      ..sort((first, second) => first.date.compareTo(second.date));
    final calories = widget.state.caloriesForDay(selectedDate);
    final tdee = NutritionMath.tdee(widget.state.profile);
    final deficit = meals.isEmpty
        ? 0.0
        : NutritionMath.deficit(calories, widget.state.profile);

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
                eyebrow: '回看每一天',
                title: '记录',
                trailing: CircleIconButton(
                  icon: CupertinoIcons.calendar_today,
                  size: 44,
                  iconSize: 19,
                  onTap: _pickDate,
                  tooltip: '选择日期',
                ),
              ),
              const SizedBox(height: 28),
              _WeekCard(
                monthLabel: DateFormat('yyyy年M月').format(selectedDate),
                weekStart: _weekStart,
                selectedDate: selectedDate,
                today: _today,
                isToday: _isToday,
                onPrevious: () => _shiftWeek(-1),
                onNext: _isCurrentWeek ? null : () => _shiftWeek(1),
                onPickMonth: _pickDate,
                onSelect: (date) => setState(() => selectedDate = date),
                onToday: () => setState(() => selectedDate = _today),
              ),
              const SizedBox(height: 16),
              _DaySummaryCard(
                calories: calories,
                tdee: tdee,
                deficit: deficit,
                mealCount: meals.length,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ActionPill(
                      label: '记一餐',
                      icon: CupertinoIcons.plus,
                      onPressed: () => showRecordSheet(
                        context,
                        widget.state,
                        date: selectedDate,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ActionPill(
                      label: '拍照识别',
                      icon: CupertinoIcons.camera,
                      filled: false,
                      onPressed: widget.onCamera,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 42),
              SectionHeader(title: _isToday ? '今天吃了什么' : '这一天吃了什么'),
              if (meals.isEmpty)
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: EmptyState(
                    icon: CupertinoIcons.tray,
                    title: _isToday ? '今天还没有记录' : '这一天是空白的',
                    message: _isToday
                        ? '先记下第一餐，热量会自动汇总。不用一次记全，想起来再补也可以。'
                        : '可以补记这一天的每一餐，热量会自动汇总。',
                    actionLabel: '记一餐',
                    onAction: () => showRecordSheet(
                      context,
                      widget.state,
                      date: selectedDate,
                    ),
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
                          state: widget.state,
                          onEdit: () => showRecordSheet(
                            context,
                            widget.state,
                            meal: meal,
                          ),
                        ),
                      ),
                  ],
                ),
              if (meals.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
                  child: Text(
                    '轻点某一餐，可以查看、编辑或删除。',
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

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.monthLabel,
    required this.weekStart,
    required this.selectedDate,
    required this.today,
    required this.isToday,
    required this.onPrevious,
    required this.onNext,
    required this.onPickMonth,
    required this.onSelect,
    required this.onToday,
  });

  final String monthLabel;
  final DateTime weekStart;
  final DateTime selectedDate;
  final DateTime today;
  final bool isToday;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onPickMonth;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onToday;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        children: [
          Row(
            children: [
              Pressable(
                onTap: onPickMonth,
                haptic: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        monthLabel,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        CupertinoIcons.chevron_down,
                        size: 11,
                        color: AppColors.tertiary,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (!isToday) ...[
                Pressable(
                  onTap: onToday,
                  haptic: true,
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Text(
                      '今天',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentDeep,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              _ArrowButton(
                icon: CupertinoIcons.chevron_left,
                onTap: onPrevious,
              ),
              _ArrowButton(icon: CupertinoIcons.chevron_right, onTap: onNext),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var index = 0; index < days.length; index++)
                Expanded(
                  child: _DayCell(
                    label: _weekdays[index],
                    day: days[index].day,
                    selected: days[index] == selectedDate,
                    isToday: days[index] == today,
                    enabled: !days[index].isAfter(today),
                    onTap: () => onSelect(days[index]),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Pressable(
        onTap: onTap,
        scale: 0.88,
        child: Icon(
          icon,
          size: 15,
          color: onTap == null
              ? AppColors.tertiary.withValues(alpha: 0.35)
              : AppColors.secondary,
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.day,
    required this.selected,
    required this.isToday,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final int day;
  final bool selected;
  final bool isToday;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: Pressable(
        onTap: enabled ? onTap : null,
        scale: 0.92,
        haptic: true,
        semanticLabel: '$day 日',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.ink.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.ink.withValues(alpha: 0.3)
                  : AppColors.glassBorder,
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.secondary : AppColors.tertiary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? AppColors.ink : AppColors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? AppColors.accent : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({
    required this.calories,
    required this.tdee,
    required this.deficit,
    required this.mealCount,
  });

  final double calories;
  final double tdee;
  final double deficit;
  final int mealCount;

  @override
  Widget build(BuildContext context) {
    final over = deficit < 0;
    final ratio = tdee <= 0 ? 0.0 : (calories / tdee).clamp(0.0, 1.0);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '这一天吃了',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
              const Spacer(),
              Tag(
                label: mealCount == 0 ? '还没有记录' : '$mealCount 餐',
                color: mealCount == 0
                    ? AppColors.secondary
                    : AppColors.accentDeep,
                background: mealCount == 0
                    ? AppColors.surfaceMuted
                    : AppColors.accentSoft,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(formatCalories(calories), style: AppTextStyles.numericLarge),
              const SizedBox(width: 6),
              Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text(
                  '大卡',
                  style: TextStyle(fontSize: 13, color: AppColors.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _sentence(),
            style: TextStyle(
              fontSize: 13,
              height: 1.65,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: AppColors.surfaceMuted),
                  RepaintBoundary(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: ratio),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 560),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: over
                                  ? [AppColors.warm, AppColors.warning]
                                  : [AppColors.barTop, AppColors.accentDeep],
                            ),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Text(
                '目标 ${formatCalories(tdee)} 大卡',
                style: TextStyle(fontSize: 11.5, color: AppColors.tertiary),
              ),
              const Spacer(),
              Text(
                mealCount == 0
                    ? '缺口暂按 0 计算'
                    : over
                    ? '比目标多 ${formatCalories(-deficit)} 大卡'
                    : '缺口 ${formatCalories(deficit)} 大卡',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: mealCount == 0
                      ? AppColors.tertiary
                      : over
                      ? AppColors.warning
                      : AppColors.accentDeep,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _sentence() {
    if (mealCount == 0) {
      return '这一天还没有记录。想补记哪一餐，随时可以开始。';
    }
    if (deficit < 0) {
      return '比每天大约消耗的 ${formatCalories(tdee)} 大卡多 ${formatCalories(-deficit)} 大卡。偶尔一天不影响长期趋势。';
    }
    return '比每天大约消耗的 ${formatCalories(tdee)} 大卡少 ${formatCalories(deficit)} 大卡，这一天的缺口会算进趋势里。';
  }
}

Future<MealEntry?> showRecordSheet(
  BuildContext context,
  AppState state, {
  DateTime? date,
  MealEntry? meal,
}) {
  return Navigator.of(context).push<MealEntry>(
    appSlideUpRoute(
      builder: (_) => _RecordMealPage(
        state: state,
        date: meal?.date ?? date ?? DateTime.now(),
        existing: meal,
      ),
    ),
  );
}

class _RecordMealPage extends StatefulWidget {
  const _RecordMealPage({
    required this.state,
    required this.date,
    this.existing,
  });

  final AppState state;
  final DateTime date;
  final MealEntry? existing;

  @override
  State<_RecordMealPage> createState() => _RecordMealPageState();
}

class _RecordMealPageState extends State<_RecordMealPage> {
  late String mealType = widget.existing?.mealType ?? _currentMealType();
  late final List<MealItem> items = List.of(
    widget.existing?.items ?? const <MealItem>[],
  );
  late final noteController = TextEditingController(
    text: widget.existing?.note ?? '',
  );
  bool saving = false;

  static String _currentMealType() {
    final hour = DateTime.now().hour;
    if (hour < 10) return '早餐';
    if (hour < 15) return '午餐';
    if (hour < 21) return '晚餐';
    return '加餐';
  }

  double get total => items.fold(0, (sum, item) => sum + item.kcal);

  Future<void> addFromDatabase() async {
    final food = await Navigator.of(
      context,
    ).push<Food>(CupertinoPageRoute(builder: (_) => const _FoodPickerPage()));
    if (food == null || !mounted) return;
    setState(() {
      items.add(
        MealItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: food.name,
          grams: food.defaultGrams,
          kcal: food.kcalPer100 * food.defaultGrams / 100,
        ),
      );
    });
  }

  Future<void> addManually() async {
    final item = await Navigator.of(context).push<MealItem>(
      CupertinoPageRoute(builder: (_) => const _ManualItemPage()),
    );
    if (item != null && mounted) setState(() => items.add(item));
  }

  Future<void> editItem(int index) async {
    final result = await showAppSheet<MealItem>(
      context,
      ItemAmountSheet(item: items[index]),
    );
    if (result != null && mounted) setState(() => items[index] = result);
  }

  Future<void> save() async {
    if (items.isEmpty || saving) return;
    setState(() => saving = true);
    final existing = widget.existing;
    final entry = MealEntry(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      date: existing?.date ?? widget.date,
      mealType: mealType,
      items: List.unmodifiable(items),
      note: noteController.text.trim(),
      source: existing?.source ?? 'manual',
    );
    if (existing == null) {
      await widget.state.addMeal(entry);
    } else {
      await widget.state.updateMeal(entry);
    }
    if (mounted) Navigator.of(context).pop(entry);
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 180),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AppBackButton(
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(height: 18),
                      PageHeader(
                        eyebrow: DateFormat(
                          'M月d日 EEEE',
                          'zh_CN',
                        ).format(widget.date),
                        title: widget.existing == null ? '记一餐' : '编辑这一餐',
                      ),
                      const SizedBox(height: 30),
                      Text('哪一餐', style: AppTextStyles.eyebrow),
                      const SizedBox(height: 12),
                      PillSegmented<String>(
                        value: mealType,
                        onChanged: (value) => setState(() => mealType = value),
                        options: const [
                          SegmentedOption(value: '早餐', label: '早餐'),
                          SegmentedOption(value: '午餐', label: '午餐'),
                          SegmentedOption(value: '晚餐', label: '晚餐'),
                          SegmentedOption(value: '加餐', label: '加餐'),
                        ],
                      ),
                      const SizedBox(height: 34),
                      SectionHeader(title: '这一餐的食物'),
                      if (items.isEmpty)
                        SurfaceCard(
                          padding: EdgeInsets.zero,
                          child: EmptyState(
                            icon: CupertinoIcons.square_list,
                            title: '还没放食物',
                            message: '从食物库挑几样，或者手动输入名称、克数和热量。',
                          ),
                        )
                      else
                        GroupedCard(
                          children: [
                            for (var index = 0; index < items.length; index++)
                              _MealItemRow(
                                item: items[index],
                                onTap: () => editItem(index),
                                onRemove: () =>
                                    setState(() => items.removeAt(index)),
                              ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _PickerAction(
                              icon: CupertinoIcons.search,
                              label: '食物库',
                              onTap: addFromDatabase,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PickerAction(
                              icon: CupertinoIcons.plus,
                              label: '手动添加',
                              onTap: addManually,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      TextField(
                        controller: noteController,
                        maxLength: 80,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: '想记点什么？例如：米饭半碗、少油。',
                          counterText: '',
                        ),
                      ),
                    ],
                  ),
                ),
                _SaveDock(
                  count: items.length,
                  total: total,
                  saving: saving,
                  canSave: items.isNotEmpty && !saving,
                  label: widget.existing == null ? '保存这一餐' : '保存修改',
                  onSave: save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealItemRow extends StatelessWidget {
  const _MealItemRow({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final MealItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatNumber(item.grams)} 克 · 轻点修改',
                    style: TextStyle(fontSize: 12, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
            Text(
              '${formatCalories(item.kcal)} 大卡',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 4),
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
                  color: AppColors.tertiary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerAction extends StatelessWidget {
  const _PickerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: 0.97,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.glassStrong,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.accentDeep),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveDock extends StatelessWidget {
  const _SaveDock({
    required this.count,
    required this.total,
    required this.saving,
    required this.canSave,
    required this.label,
    required this.onSave,
  });

  final int count;
  final double total;
  final bool saving;
  final bool canSave;
  final String label;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      decoration: BoxDecoration(
        color: AppColors.dock,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    count == 0 ? '还没有添加食物' : '$count 项食物',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.secondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '共 ${formatCalories(total)} 大卡',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            PrimaryButton(
              label: label,
              busy: saving,
              onPressed: canSave ? onSave : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodPickerPage extends StatefulWidget {
  const _FoodPickerPage();

  @override
  State<_FoodPickerPage> createState() => _FoodPickerPageState();
}

class _FoodPickerPageState extends State<_FoodPickerPage> {
  String query = '';
  String category = '全部';

  @override
  Widget build(BuildContext context) {
    final foods = searchFoods(query, category);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppBackButton(onTap: () => Navigator.pop(context)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: PageHeader(
                    eyebrow: '共 ${foods.length} 种常见食物',
                    title: '食物库',
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      hintText: '搜索食物，例如：米饭',
                      prefixIcon: Icon(CupertinoIcons.search, size: 19),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: foodCategories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final value = foodCategories[index];
                      return ChoicePill(
                        label: value,
                        selected: category == value,
                        onTap: () => setState(() => category = value),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: SurfaceCard(
                      padding: EdgeInsets.zero,
                      child: foods.isEmpty
                          ? const EmptyState(
                              icon: CupertinoIcons.search,
                              title: '没有找到',
                              message: '换个关键词试试，或返回手动添加。',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 10),
                              physics: const BouncingScrollPhysics(),
                              itemCount: foods.length,
                              separatorBuilder: (_, _) =>
                                  const HairLine(indent: 18, endIndent: 18),
                              itemBuilder: (context, index) {
                                final food = foods[index];
                                return Pressable(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.pop(context, food);
                                  },
                                  scale: 0.99,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                food.name,
                                                style: TextStyle(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.ink,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${food.category} · 默认 ${formatNumber(food.defaultGrams)} 克',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: AppColors.secondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${formatCalories(food.kcalPer100)} 大卡',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.secondary,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Icon(
                                          CupertinoIcons.plus_circle_fill,
                                          size: 21,
                                          color: AppColors.accent,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
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

class _ManualItemPage extends StatefulWidget {
  const _ManualItemPage();

  @override
  State<_ManualItemPage> createState() => _ManualItemPageState();
}

class _ManualItemPageState extends State<_ManualItemPage> {
  final name = TextEditingController();
  final grams = TextEditingController(text: '100');
  final kcal = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    grams.dispose();
    kcal.dispose();
    super.dispose();
  }

  void save() {
    final weight = double.tryParse(grams.text.trim());
    final calories = double.tryParse(kcal.text.trim());
    if (name.text.trim().isEmpty ||
        weight == null ||
        weight <= 0 ||
        calories == null ||
        calories < 0) {
      showAppMessage(context, '请填写食物名称、有效克数和热量');
      return;
    }
    Navigator.pop(
      context,
      MealItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.text.trim(),
        grams: weight,
        kcal: calories,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppBackButton(onTap: () => Navigator.pop(context)),
                ),
                const SizedBox(height: 18),
                const PageHeader(eyebrow: '不在食物库里也没关系', title: '手动添加'),
                const SizedBox(height: 30),
                const _FieldLabel('食物名称'),
                const SizedBox(height: 9),
                TextField(
                  controller: name,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: '例如：楼下的小碗牛肉面'),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('这一份的克数'),
                          const SizedBox(height: 9),
                          TextField(
                            controller: grams,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              hintText: '100',
                              suffixText: '克',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('这一份的热量'),
                          const SizedBox(height: 9),
                          TextField(
                            controller: kcal,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              hintText: '总热量',
                              suffixText: '大卡',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '按包装标签或实际称重填写，数字会更接近真实摄入。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: AppColors.tertiary,
                  ),
                ),
                const SizedBox(height: 34),
                PrimaryButton(label: '加入这一餐', onPressed: save),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.secondary,
      ),
    );
  }
}

class ItemAmountSheet extends StatefulWidget {
  const ItemAmountSheet({super.key, required this.item});

  final MealItem item;

  @override
  State<ItemAmountSheet> createState() => _ItemAmountSheetState();
}

class _ItemAmountSheetState extends State<ItemAmountSheet> {
  late final TextEditingController grams = TextEditingController(
    text: formatNumber(widget.item.grams),
  );
  late final TextEditingController kcal = TextEditingController(
    text: formatNumber(widget.item.kcal),
  );

  @override
  void dispose() {
    grams.dispose();
    kcal.dispose();
    super.dispose();
  }

  void updateCalories(String value) {
    final weight = double.tryParse(value);
    if (weight != null && widget.item.grams > 0) {
      setState(() {
        kcal.text = formatNumber(widget.item.kcal * weight / widget.item.grams);
      });
    }
  }

  void save() {
    final weight = double.tryParse(grams.text.trim());
    final calories = double.tryParse(kcal.text.trim());
    if (weight == null || weight <= 0 || calories == null || calories < 0) {
      showAppMessage(context, '请输入有效克数和热量');
      return;
    }
    Navigator.pop(context, widget.item.copyWith(grams: weight, kcal: calories));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeading(
            title: widget.item.name,
            subtitle: '调整分量后，热量会按比例更新。',
            onClose: () => Navigator.pop(context),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: grams,
                  onChanged: updateCalories,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '分量',
                    suffixText: '克',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: kcal,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '总热量',
                    suffixText: '大卡',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          PrimaryButton(label: '完成', onPressed: save),
        ],
      ),
    );
  }
}
