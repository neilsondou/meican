import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'sync_merge.dart';

class AppState extends ChangeNotifier {
  static const String _storageKey = 'meican_state_v1';

  final List<MealEntry> meals = [];
  final List<WeightEntry> weights = [];
  final Map<String, DateTime> deletedMeals = {};
  final Map<String, DateTime> deletedWeights = {};
  UserProfile profile = const UserProfile();
  DateTime? profileUpdatedAt;
  int mutationVersion = 0;
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
        profileUpdatedAt = _dateOrNull(data['profileUpdatedAt']);
        deletedMeals
          ..clear()
          ..addAll(_tombstones(data['deletedMeals']));
        deletedWeights
          ..clear()
          ..addAll(_tombstones(data['deletedWeights']));
      } catch (_) {
        // 损坏的本地数据不应阻止应用启动；保留安全的默认状态。
      }
    }

    ready = true;
    notifyListeners();
  }

  Future<void> addMeal(MealEntry meal) async {
    final now = DateTime.now();
    meals.add(meal.copyWith(updatedAt: now));
    deletedMeals.remove(meal.id);
    _markMutation();
    await _persist();
  }

  Future<void> updateMeal(MealEntry meal) async {
    final now = DateTime.now();
    final updated = meal.copyWith(updatedAt: now);
    final index = meals.indexWhere((entry) => entry.id == meal.id);
    if (index == -1) {
      meals.add(updated);
    } else {
      meals[index] = updated;
    }
    deletedMeals.remove(meal.id);
    _markMutation();
    await _persist();
  }

  Future<void> deleteMeal(String id) async {
    final index = meals.indexWhere((meal) => meal.id == id);
    if (index == -1) return;
    meals.removeAt(index);
    deletedMeals[id] = DateTime.now();
    _markMutation();
    await _persist();
  }

  Future<void> addWeight(WeightEntry weight) async {
    final now = DateTime.now();
    final replaced = weights
        .where((entry) => _isSameDay(entry.date, weight.date))
        .map((entry) => entry.id)
        .toList();
    for (final id in replaced) {
      if (id != weight.id) deletedWeights[id] = now;
    }
    weights.removeWhere((entry) => _isSameDay(entry.date, weight.date));
    weights.add(weight.copyWith(updatedAt: now));
    deletedWeights.remove(weight.id);
    profile = profile.copyWith(weightKg: weight.kg);
    profileUpdatedAt = now;
    _markMutation();
    await _persist();
  }

  Future<void> deleteWeight(String id) async {
    final index = weights.indexWhere((weight) => weight.id == id);
    if (index == -1) return;
    weights.removeAt(index);
    deletedWeights[id] = DateTime.now();
    _markMutation();
    await _persist();
  }

  Future<void> updateProfile(UserProfile value) async {
    profile = value;
    profileUpdatedAt = DateTime.now();
    _markMutation();
    await _persist();
  }

  SyncSnapshot toSyncSnapshot() {
    return SyncSnapshot(
      meals: [
        for (final meal in meals)
          meal.updatedAt == null ? meal.copyWith(updatedAt: meal.date) : meal,
      ],
      weights: [
        for (final weight in weights)
          weight.updatedAt == null
              ? weight.copyWith(updatedAt: weight.date)
              : weight,
      ],
      profile: profile,
      profileUpdatedAt: profileUpdatedAt,
      deletedMeals: Map.of(deletedMeals),
      deletedWeights: Map.of(deletedWeights),
    );
  }

  /// 应用云端合并结果，不计入本机改动，避免重复上传。
  Future<void> applySyncSnapshot(SyncSnapshot snapshot) async {
    meals
      ..clear()
      ..addAll(snapshot.meals);
    weights
      ..clear()
      ..addAll(snapshot.weights);
    profile = snapshot.profile;
    profileUpdatedAt = snapshot.profileUpdatedAt;
    deletedMeals
      ..clear()
      ..addAll(snapshot.deletedMeals);
    deletedWeights
      ..clear()
      ..addAll(snapshot.deletedWeights);
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

  void _markMutation() {
    mutationVersion++;
    notifyListeners();
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'meals': meals.map((meal) => meal.toJson()).toList(),
      'weights': weights.map((weight) => weight.toJson()).toList(),
      'profile': profile.toJson(),
      'profileUpdatedAt': profileUpdatedAt?.toIso8601String(),
      'deletedMeals': {
        for (final entry in deletedMeals.entries)
          entry.key: entry.value.toIso8601String(),
      },
      'deletedWeights': {
        for (final entry in deletedWeights.entries)
          entry.key: entry.value.toIso8601String(),
      },
    };
    await preferences.setString(_storageKey, jsonEncode(data));
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  static Map<String, DateTime> _tombstones(Object? value) {
    if (value is! Map) return const {};
    final result = <String, DateTime>{};
    for (final entry in value.entries) {
      final date = _dateOrNull(entry.value);
      if (date != null && entry.key is String) {
        result[entry.key as String] = date;
      }
    }
    return result;
  }

  static bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
