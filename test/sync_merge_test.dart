import 'package:flutter_test/flutter_test.dart';
import 'package:meican/models.dart';
import 'package:meican/sync_merge.dart';

void main() {
  final base = DateTime.utc(2026, 10, 1, 12);
  final later = base.add(const Duration(minutes: 5));
  final latest = base.add(const Duration(minutes: 10));

  MealEntry meal(String id, DateTime updatedAt, {String note = ''}) {
    return MealEntry(
      id: id,
      date: base,
      mealType: '午餐',
      items: const [MealItem(id: 'item', name: '米饭', grams: 150, kcal: 174)],
      note: note,
      source: 'manual',
      updatedAt: updatedAt,
    );
  }

  SyncSnapshot snapshot({
    List<MealEntry> meals = const [],
    List<WeightEntry> weights = const [],
    UserProfile profile = const UserProfile(),
    DateTime? profileUpdatedAt,
    Map<String, DateTime> deletedMeals = const {},
    Map<String, DateTime> deletedWeights = const {},
  }) {
    return SyncSnapshot(
      meals: meals,
      weights: weights,
      profile: profile,
      profileUpdatedAt: profileUpdatedAt,
      deletedMeals: deletedMeals,
      deletedWeights: deletedWeights,
    );
  }

  test('较新的云端餐次覆盖本机旧版本', () {
    final local = snapshot(meals: [meal('a', base, note: '本机')]);
    final remote = snapshot(meals: [meal('a', later, note: '云端')]);

    final result = mergeSyncSnapshots(local, remote);

    expect(result.snapshot.meals.single.note, '云端');
    expect(result.localChanged, isTrue);
    expect(result.remoteChanged, isFalse);
  });

  test('本机删除墓碑可以删除较旧的云端记录', () {
    final local = snapshot(deletedMeals: {'a': later});
    final remote = snapshot(meals: [meal('a', base)]);

    final result = mergeSyncSnapshots(local, remote);

    expect(result.snapshot.meals, isEmpty);
    expect(result.snapshot.deletedMeals, contains('a'));
    expect(result.localChanged, isFalse);
    expect(result.remoteChanged, isTrue);
  });

  test('云端较新的编辑可以恢复本机较旧的删除', () {
    final local = snapshot(deletedMeals: {'a': base});
    final remote = snapshot(meals: [meal('a', later, note: '后来补记')]);

    final result = mergeSyncSnapshots(local, remote);

    expect(result.snapshot.meals.single.note, '后来补记');
    expect(result.snapshot.deletedMeals, isEmpty);
    expect(result.localChanged, isTrue);
    expect(result.remoteChanged, isFalse);
  });

  test('较新的资料更新时间获胜', () {
    final localProfile = const UserProfile(weightKg: 70);
    final remoteProfile = const UserProfile(weightKg: 64);
    final local = snapshot(profile: localProfile, profileUpdatedAt: base);
    final remote = snapshot(profile: remoteProfile, profileUpdatedAt: later);

    final result = mergeSyncSnapshots(local, remote);

    expect(result.snapshot.profile.weightKg, 64);
    expect(result.localChanged, isTrue);
    expect(result.remoteChanged, isFalse);
  });

  test('本机独有改动需要上传', () {
    final local = snapshot(meals: [meal('local-only', base)]);
    final remote = snapshot();

    final result = mergeSyncSnapshots(local, remote);

    expect(result.snapshot.meals.single.id, 'local-only');
    expect(result.localChanged, isFalse);
    expect(result.remoteChanged, isTrue);
  });

  test('相同数据不同排序不会触发上传', () {
    final local = snapshot(meals: [meal('a', base), meal('b', later)]);
    final remote = snapshot(meals: [meal('b', later), meal('a', base)]);

    final result = mergeSyncSnapshots(local, remote);

    expect(result.localChanged, isFalse);
    expect(result.remoteChanged, isFalse);
  });

  test('没有云端数据时需要创建首次快照', () {
    final local = snapshot(meals: [meal('a', base)]);

    final result = mergeSyncSnapshots(local, null);

    expect(result.snapshot.meals.single.id, 'a');
    expect(result.localChanged, isFalse);
    expect(result.remoteChanged, isTrue);
  });

  test('快照 JSON 往返后保持结构', () {
    final value = snapshot(
      meals: [meal('a', latest, note: '备注')],
      deletedWeights: {'w': later},
      profileUpdatedAt: later,
    );

    final decoded = SyncSnapshot.fromJson(value.toJson());

    expect(decoded.meals.single.note, '备注');
    expect(decoded.deletedWeights, contains('w'));
    expect(decoded.profileUpdatedAt, later);
    expect(decoded.canonical, value.canonical);
  });
}
