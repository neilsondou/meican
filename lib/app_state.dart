import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AppState extends ChangeNotifier {
  static const String _storageKey = 'meican_state_v1';

  final List<MealEntry> meals = [];
  final List<WeightEntry> weights = [];
  UserProfile profile = const UserProfile();
  String apiKey = '';
  bool ready = false;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_storageKey);

    if (saved != null && saved.isNotEmpty) {
      try {
        final data = Map<String, dynamic>.from(
          jsonDecode(saved) as Map<dynamic, dynamic>,
        );
        final loadedMeals = (data['meals'] as List<dynamic>? ?? [])
            .map(
              (value) => MealEntry.fromJson(
                Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
              ),
            )
            .toList();
        final loadedWeights = (data['weights'] as List<dynamic>? ?? [])
            .map(
              (value) => WeightEntry.fromJson(
                Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
              ),
            )
            .toList();
        final profileData = data['profile'];
        final loadedProfile = profileData is Map
            ? UserProfile.fromJson(Map<String, dynamic>.from(profileData))
            : const UserProfile();

        meals
          ..clear()
          ..addAll(loadedMeals);
        weights
          ..clear()
          ..addAll(loadedWeights);
        profile = loadedProfile;
        apiKey = data['apiKey'] as String? ?? '';
      } catch (_) {
        // 损坏的本地数据不应阻止应用启动；保留安全的默认状态。
      }
    }

    ready = true;
    notifyListeners();
  }

  Future<void> addMeal(MealEntry meal) async {
    meals.add(meal);
    notifyListeners();
    await _persist();
  }

  Future<void> deleteMeal(String id) async {
    meals.removeWhere((meal) => meal.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> addWeight(WeightEntry weight) async {
    weights.removeWhere((entry) => _isSameDay(entry.date, weight.date));
    weights.add(weight);
    profile = profile.copyWith(weightKg: weight.kg);
    notifyListeners();
    await _persist();
  }

  Future<void> deleteWeight(String id) async {
    weights.removeWhere((weight) => weight.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> updateProfile(UserProfile value) async {
    profile = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setApiKey(String value) async {
    apiKey = value.trim();
    notifyListeners();
    await _persist();
  }

  List<MealEntry> mealsForDay(DateTime day) {
    return meals.where((meal) => _isSameDay(meal.date, day)).toList();
  }

  double caloriesForDay(DateTime day) {
    return mealsForDay(day).fold(0, (sum, meal) => sum + meal.totalKcal);
  }

  /// 最近 [days] 天中，仅将已结束且有饮食记录的自然日计入平均值。
  double recentAverageDeficit([int days = 7]) {
    if (days <= 0) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var totalDeficit = 0.0;
    var recordedDays = 0;

    for (var offset = days; offset >= 1; offset--) {
      final day = today.subtract(Duration(days: offset));
      if (mealsForDay(day).isEmpty) continue;
      totalDeficit += NutritionMath.deficit(caloriesForDay(day), profile);
      recordedDays++;
    }

    return recordedDays == 0 ? 0 : totalDeficit / recordedDays;
  }

  /// 按最近 7 天平均缺口和 7700 kcal/kg 粗略估算，仅供参考。
  int? predictDaysToTarget() {
    final remainingKg = profile.weightKg - profile.targetWeightKg;
    final averageDeficit = recentAverageDeficit();
    if (remainingKg <= 0 || averageDeficit <= 0) return null;

    return (remainingKg * NutritionMath.kcalPerKgFat / averageDeficit).ceil();
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'meals': meals.map((meal) => meal.toJson()).toList(),
      'weights': weights.map((weight) => weight.toJson()).toList(),
      'profile': profile.toJson(),
      'apiKey': apiKey,
    };
    await preferences.setString(_storageKey, jsonEncode(data));
  }

  static bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
