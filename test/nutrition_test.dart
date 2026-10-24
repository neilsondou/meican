import 'package:flutter_test/flutter_test.dart';
import 'package:meican/app_state.dart';
import 'package:meican/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('一餐热量是所有食物之和', () {
    final meal = MealEntry(
      id: '1',
      date: DateTime(2026, 10, 25),
      mealType: '午餐',
      source: 'test',
      items: [
        MealItem(id: 'rice', name: '米饭', grams: 150, kcal: 174),
        MealItem(id: 'chicken', name: '鸡胸肉', grams: 100, kcal: 133),
      ],
    );

    expect(meal.totalKcal, 307);
  });

  test('Mifflin-St Jeor 计算基础代谢与总消耗', () {
    const profile = UserProfile();

    expect(NutritionMath.bmr(profile), 1567.5);
    expect(NutritionMath.tdee(profile), closeTo(2155.3125, 0.001));
    expect(NutritionMath.deficit(1800, profile), closeTo(355.3125, 0.001));
  });

  test('同日体重覆盖并同步当前体重', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    final today = DateTime.now();
    await state.addWeight(WeightEntry(id: '1', date: today, kg: 70));
    await state.addWeight(WeightEntry(id: '2', date: today, kg: 69.5));

    expect(state.weights.length, 1);
    expect(state.weights.single.kg, 69.5);
    expect(state.profile.weightKg, 69.5);
  });
}
