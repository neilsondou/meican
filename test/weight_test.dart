import 'package:flutter_test/flutter_test.dart';
import 'package:meican/app_state.dart';
import 'package:meican/models.dart';
import 'package:meican/sync_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kg 与 g 的输入和显示按偏好换算', () {
    expect(WeightUnit.kilograms.toDisplay(65.2), 65.2);
    expect(WeightUnit.grams.toDisplay(65.2), 65200);
    expect(WeightUnit.grams.toKilograms(65200), 65.2);

    expect(WeightUnit.kilograms.formatValue(65.0), '65');
    expect(WeightUnit.kilograms.formatValue(65.24), '65.2');
    expect(WeightUnit.grams.formatValue(65.2), '65200');
    expect(WeightUnit.grams.format(65.2), '65200 克');
    expect(WeightUnit.kilograms.format(65.2), '65.2 公斤');
    expect(WeightUnit.kilograms.displayInput(65.24), 65.2);
    expect(WeightUnit.grams.displayInput(65.24), 65240);
  });

  test('单位偏好随资料 JSON 往返并兼容旧数据', () {
    final profile = const UserProfile(
      weightUnit: WeightUnit.grams,
    ).copyWith(weightKg: 62.5);

    final restored = UserProfile.fromJson(profile.toJson());

    expect(restored.weightUnit, WeightUnit.grams);
    expect(restored.weightKg, 62.5);

    final legacy = UserProfile.fromJson({
      'heightCm': 170,
      'weightKg': 65,
      'age': 30,
      'sex': 'male',
      'activity': 1.375,
      'targetWeightKg': 60,
    });
    expect(legacy.weightUnit, WeightUnit.kilograms);
  });

  test('Deurenberg 体脂估算与分类', () {
    const profile = UserProfile();
    final percent = NutritionMath.bodyFatPercent(profile);

    expect(percent, closeTo(17.69, 0.01));
    expect(NutritionMath.bodyFatLabel(percent, 'male'), '标准');
    expect(
      NutritionMath.bodyFatPercent(profile.copyWith(sex: 'female')),
      closeTo(28.49, 0.01),
    );

    final low = NutritionMath.bodyFatPercent(profile.copyWith(weightKg: 30));
    expect(low, greaterThanOrEqualTo(3));
  });

  test('补录旧日期不会覆盖更新的当前体重', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    final today = DateTime.now();
    final older = today.subtract(const Duration(days: 3));

    await state.importWeights([
      WeightEntry(id: 'old', date: older, kg: 70),
      WeightEntry(id: 'new', date: today, kg: 68),
    ]);
    expect(state.currentWeightKg, 68);

    await state.importWeights([
      WeightEntry(
        id: 'backfill',
        date: today.subtract(const Duration(days: 1)),
        kg: 71,
      ),
    ]);

    expect(state.weights.length, 3);
    expect(state.currentWeightKg, 68);
    expect(state.profile.weightKg, 68);
  });

  test('同一天只保留一条记录并留下删除墓碑', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    final day = DateTime.now().subtract(const Duration(days: 1));

    await state.upsertWeight(WeightEntry(id: 'a', date: day, kg: 70));
    await state.upsertWeight(WeightEntry(id: 'b', date: day, kg: 69.4));

    expect(state.weights.single.id, 'b');
    expect(state.weights.single.kg, 69.4);
    expect(state.deletedWeights, contains('a'));
    expect(state.currentWeightKg, 69.4);
  });

  test('单位偏好可以持久化并通过资料时间参与云端合并', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.updateProfile(
      state.profile.copyWith(weightUnit: WeightUnit.grams),
    );

    final reloaded = AppState();
    await reloaded.load();
    expect(reloaded.profile.weightUnit, WeightUnit.grams);

    final base = DateTime.utc(2026, 10, 1, 12);
    final local = SyncSnapshot(
      meals: const [],
      weights: const [],
      profile: const UserProfile(weightUnit: WeightUnit.grams),
      profileUpdatedAt: base.add(const Duration(minutes: 5)),
      deletedMeals: const {},
      deletedWeights: const {},
    );
    final remote = SyncSnapshot(
      meals: const [],
      weights: const [],
      profile: const UserProfile(),
      profileUpdatedAt: base,
      deletedMeals: const {},
      deletedWeights: const {},
    );

    final result = mergeSyncSnapshots(local, remote);
    expect(result.snapshot.profile.weightUnit, WeightUnit.grams);
  });
}
