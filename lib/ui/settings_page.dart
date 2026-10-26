import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../cloud_sync.dart';
import '../export_service.dart' deferred as exporter;
import '../models.dart';
import 'components.dart';
import 'theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.state, required this.cloud});

  final AppState state;
  final CloudSync cloud;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? exporting;

  Future<void> export(String type) async {
    if (exporting != null) return;
    setState(() => exporting = type);
    try {
      await exporter.loadLibrary();
      if (type == 'CSV') {
        await exporter.ExportService.exportCsv(widget.state);
      } else {
        await exporter.ExportService.exportPdf(widget.state);
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
        const SectionHeader(title: '显示与输入'),
        SurfaceCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
          child: Row(
            children: [
              IconBadge(
                icon: CupertinoIcons.circle_lefthalf_fill,
                color: AppColors.accentDeep,
                background: AppColors.accentSoft,
                size: 40,
                iconSize: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '外观',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '暗色更沉稳，亮色是带一点米色的暖白',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 132,
                child: PillSegmented<bool>(
                  options: const [
                    SegmentedOption(value: true, label: '暗色'),
                    SegmentedOption(value: false, label: '亮色'),
                  ],
                  value: AppThemeController.instance.isDark,
                  onChanged: (value) =>
                      AppThemeController.instance.setDark(value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SurfaceCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
          child: Row(
            children: [
              IconBadge(
                icon: CupertinoIcons.gauge,
                color: AppColors.accentDeep,
                background: AppColors.accentSoft,
                size: 40,
                iconSize: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '体重单位',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '切换后全局显示与输入都会换算，1 公斤 = 2 市斤',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 132,
                child: PillSegmented<WeightUnit>(
                  options: const [
                    SegmentedOption(value: WeightUnit.kilograms, label: '公斤'),
                    SegmentedOption(value: WeightUnit.jin, label: '市斤'),
                  ],
                  value: state.profile.weightUnit,
                  onChanged: _setWeightUnit,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '记录仍以统一数据保存并参与云同步；切换只改变你看到的数字。',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.55,
              color: AppColors.tertiary,
            ),
          ),
        ),
        const SizedBox(height: 44),
        const SectionHeader(title: '同步'),
        AnimatedBuilder(
          animation: widget.cloud,
          builder: (context, _) => _CloudSyncCard(
            cloud: widget.cloud,
            onTap: () => showCloudSyncSheet(context, widget.cloud),
          ),
        ),
        const SizedBox(height: 44),
        const SectionHeader(title: '导出'),
        GroupedCard(
          children: [
            GroupedRow(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
              leading: IconBadge(
                icon: CupertinoIcons.square_arrow_up,
                color: AppColors.warm,
                background: AppColors.warm.withValues(alpha: 0.12),
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
              leading: IconBadge(
                icon: CupertinoIcons.doc_text,
                color: AppColors.warm,
                background: AppColors.warm.withValues(alpha: 0.12),
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
        Center(
          child: Column(
            children: [
              Text(
                'Mei Can',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
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

  Future<void> _setWeightUnit(WeightUnit unit) async {
    if (widget.state.profile.weightUnit == unit) return;
    await widget.state.updateProfile(
      widget.state.profile.copyWith(weightUnit: unit),
    );
    if (mounted) {
      showAppMessage(context, '体重已切换为${unit.label}');
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.state, required this.onTap});

  final AppState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    final unit = profile.weightUnit;
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
              IconBadge(
                icon: CupertinoIcons.person_fill,
                color: AppColors.accentDeep,
                background: AppColors.accentSoft,
                size: 46,
                iconSize: 21,
              ),
              const SizedBox(width: 14),
              Expanded(
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
              Icon(
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
                unit.formatValue(profile.weightKg),
                style: AppTextStyles.numericLarge,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 4),
                child: Text(
                  unit.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Tag(
                  label: '目标 ${unit.format(profile.targetWeightKg)}',
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
            style: TextStyle(
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
          style: TextStyle(fontSize: 11.5, color: AppColors.tertiary),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
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
  late final WeightUnit unit = widget.state.profile.weightUnit;
  late final height = TextEditingController(
    text: formatNumber(widget.state.profile.heightCm),
  );
  late final weight = TextEditingController(
    text: unit.formatValue(widget.state.profile.weightKg),
  );
  late final age = TextEditingController(
    text: widget.state.profile.age.toString(),
  );
  late final target = TextEditingController(
    text: unit.formatValue(widget.state.profile.targetWeightKg),
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
    final weightInput = double.tryParse(weight.text.trim().replaceAll(',', ''));
    final ageValue = int.tryParse(age.text.trim());
    final targetInput = double.tryParse(target.text.trim().replaceAll(',', ''));
    if (heightValue == null ||
        heightValue < 100 ||
        heightValue > 250 ||
        weightInput == null ||
        ageValue == null ||
        ageValue < 10 ||
        ageValue > 100 ||
        targetInput == null) {
      return null;
    }
    final weightValue = unit.toKilograms(weightInput);
    final targetValue = unit.toKilograms(targetInput);
    if (weightValue < 25 ||
        weightValue > 400 ||
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
                  decoration: InputDecoration(
                    labelText: '体重',
                    suffixText: unit.label,
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
                  decoration: InputDecoration(
                    labelText: '目标体重',
                    suffixText: unit.label,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text('生理性别', style: AppTextStyles.eyebrow),
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
          Text('日常活动', style: AppTextStyles.eyebrow),
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
          style: TextStyle(fontSize: 10.5, color: AppColors.secondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
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

class _CloudSyncCard extends StatelessWidget {
  const _CloudSyncCard({required this.cloud, required this.onTap});

  final CloudSync cloud;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lastSync = cloud.lastSyncAt;
    final subtitle = !cloud.isLoggedIn
        ? '登录后自动备份与合并本机记录'
        : lastSync == null
        ? '已登录，等待首次同步'
        : '最后同步 ${DateFormat('M月d日 HH:mm').format(lastSync)}';
    return GroupedCard(
      children: [
        GroupedRow(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
          leading: IconBadge(
            icon: cloud.isLoggedIn
                ? CupertinoIcons.cloud_fill
                : CupertinoIcons.cloud,
            color: AppColors.accentDeep,
            background: AppColors.accentSoft,
            size: 40,
            iconSize: 18,
          ),
          title: '云同步',
          subtitle: subtitle,
          detail: cloud.busy
              ? '同步中'
              : cloud.isLoggedIn
              ? '已开启'
              : '未登录',
          onTap: onTap,
        ),
      ],
    );
  }
}

Future<void> showCloudSyncSheet(BuildContext context, CloudSync cloud) {
  return showAppSheet<void>(context, _CloudSyncSheet(cloud: cloud));
}

class _CloudSyncSheet extends StatefulWidget {
  const _CloudSyncSheet({required this.cloud});

  final CloudSync cloud;

  @override
  State<_CloudSyncSheet> createState() => _CloudSyncSheetState();
}

class _CloudSyncSheetState extends State<_CloudSyncSheet> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool reveal = false;
  bool submitting = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (submitting || widget.cloud.busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.cloud.login(username.text, password.text);
      if (mounted) password.clear();
    } on CloudSyncException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '退出云同步？',
      message: '本机记录不会被删除。重新登录后会再次与云端合并。',
      confirmLabel: '退出',
    );
    if (!confirmed || !mounted) return;
    await widget.cloud.logout();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.cloud,
      builder: (context, _) {
        final cloud = widget.cloud;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetHeading(
                title: '云同步',
                subtitle: cloud.isLoggedIn
                    ? '记录会在后台自动上传，其他设备登录后自动合并。'
                    : '登录后，本机记录会在后台自动同步到你的云端。',
                onClose: () => Navigator.pop(context),
              ),
              if (!cloud.isLoggedIn) ...[
                const _SyncPrompt(),
                const SizedBox(height: 18),
                TextField(
                  controller: username,
                  enabled: !submitting,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '账号'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  enabled: !submitting,
                  obscureText: !reveal,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => login(),
                  decoration: InputDecoration(
                    labelText: '密码',
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Pressable(
                        onTap: () => setState(() => reveal = !reveal),
                        scale: 0.88,
                        semanticLabel: reveal ? '隐藏密码' : '显示密码',
                        child: SizedBox.square(
                          dimension: 40,
                          child: Center(
                            child: Icon(
                              reveal
                                  ? CupertinoIcons.eye_slash
                                  : CupertinoIcons.eye,
                              size: 19,
                              color: AppColors.tertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.warning,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                PrimaryButton(
                  label: '登录并同步',
                  busy: submitting || cloud.busy,
                  onPressed: login,
                ),
                const SizedBox(height: 12),
                Text(
                  '登录只保存在本机，不会影响本地记录。忘记账号密码请联系作者。',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.6,
                    color: AppColors.tertiary,
                  ),
                ),
              ] else ...[
                _SyncStatus(cloud: cloud),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: '立即同步',
                  busy: cloud.busy,
                  onPressed: cloud.busy
                      ? null
                      : () => cloud.syncNow(manual: true),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Pressable(
                    onTap: cloud.busy ? null : logout,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        '退出登录',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _SyncLogs(logs: cloud.logs),
            ],
          ),
        );
      },
    );
  }
}

class _SyncPrompt extends StatelessWidget {
  const _SyncPrompt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.lock, size: 16, color: AppColors.accentDeep),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '想要账号密码请联系作者',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.accentDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.cloud});

  final CloudSync cloud;

  @override
  Widget build(BuildContext context) {
    final lastSync = cloud.lastSyncAt;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: CupertinoIcons.cloud_fill,
                color: AppColors.accentDeep,
                background: AppColors.accentSoft,
                size: 40,
                iconSize: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cloud.username ?? '已登录',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lastSync == null
                          ? '尚未完成首次同步'
                          : '最后同步 ${DateFormat('M月d日 HH:mm').format(lastSync)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Tag(
                label: cloud.busy ? '同步中' : '已开启',
                color: AppColors.accentDeep,
                background: AppColors.accentSoft,
              ),
            ],
          ),
          if (cloud.revision > 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: HairLine(),
            ),
            Text(
              '云端版本 ${cloud.revision} · 每次修改都会在后台自动上传',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.tertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SyncLogs extends StatelessWidget {
  const _SyncLogs({required this.logs});

  final List<CloudLog> logs;

  @override
  Widget build(BuildContext context) {
    final recent = logs.reversed.take(12).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('同步日志', style: AppTextStyles.eyebrow),
        const SizedBox(height: 10),
        SurfaceCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: recent.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '还没有同步记录。',
                    style: TextStyle(fontSize: 12.5, color: AppColors.tertiary),
                  ),
                )
              : Column(
                  children: [
                    for (var index = 0; index < recent.length; index++) ...[
                      if (index > 0) const SizedBox(height: 9),
                      _SyncLogRow(log: recent[index]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _SyncLogRow extends StatelessWidget {
  const _SyncLogRow({required this.log});

  final CloudLog log;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            DateFormat('HH:mm:ss').format(log.time),
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.tertiary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            log.message,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: log.error ? AppColors.warning : AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }
}
