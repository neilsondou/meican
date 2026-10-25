import 'dart:convert';
import 'dart:math' as math;

import 'models.dart';

const int syncSnapshotVersion = 1;

class SyncSnapshot {
  SyncSnapshot({
    required this.meals,
    required this.weights,
    required this.profile,
    required this.profileUpdatedAt,
    required this.deletedMeals,
    required this.deletedWeights,
  });

  final List<MealEntry> meals;
  final List<WeightEntry> weights;
  final UserProfile profile;
  final DateTime? profileUpdatedAt;
  final Map<String, DateTime> deletedMeals;
  final Map<String, DateTime> deletedWeights;

  factory SyncSnapshot.empty() {
    return SyncSnapshot(
      meals: const [],
      weights: const [],
      profile: const UserProfile(),
      profileUpdatedAt: null,
      deletedMeals: const {},
      deletedWeights: const {},
    );
  }

  factory SyncSnapshot.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version != null && version != syncSnapshotVersion) {
      throw const FormatException('同步数据版本不受支持');
    }
    final rawMeals = json['meals'];
    final rawWeights = json['weights'];
    final rawProfile = json['profile'];
    if (rawMeals is! List || rawWeights is! List || rawProfile is! Map) {
      throw const FormatException('同步数据格式不完整');
    }

    final meals = <String, MealEntry>{};
    for (final raw in rawMeals) {
      if (raw is! Map) continue;
      final meal = MealEntry.fromJson(Map<String, dynamic>.from(raw));
      final normalized = meal.updatedAt == null
          ? meal.copyWith(updatedAt: meal.date)
          : meal;
      final existing = meals[normalized.id];
      if (existing == null || _mealTime(normalized) > _mealTime(existing)) {
        meals[normalized.id] = normalized;
      }
    }

    final weights = <String, WeightEntry>{};
    for (final raw in rawWeights) {
      if (raw is! Map) continue;
      final weight = WeightEntry.fromJson(Map<String, dynamic>.from(raw));
      final normalized = weight.updatedAt == null
          ? weight.copyWith(updatedAt: weight.date)
          : weight;
      final existing = weights[normalized.id];
      if (existing == null || _weightTime(normalized) > _weightTime(existing)) {
        weights[normalized.id] = normalized;
      }
    }

    return SyncSnapshot(
      meals: meals.values.toList(),
      weights: weights.values.toList(),
      profile: UserProfile.fromJson(Map<String, dynamic>.from(rawProfile)),
      profileUpdatedAt: _date(json['profileUpdatedAt']),
      deletedMeals: _dateMap(json['deletedMeals']),
      deletedWeights: _dateMap(json['deletedWeights']),
    );
  }

  Map<String, dynamic> toJson() {
    final sortedMeals = [...meals]..sort(_compareMeals);
    final sortedWeights = [...weights]..sort(_compareWeights);
    return {
      'version': syncSnapshotVersion,
      'meals': sortedMeals.map((meal) => meal.toJson()).toList(),
      'weights': sortedWeights.map((weight) => weight.toJson()).toList(),
      'profile': profile.toJson(),
      'profileUpdatedAt': profileUpdatedAt?.toUtc().toIso8601String(),
      'deletedMeals': {
        for (final entry in deletedMeals.entries)
          entry.key: entry.value.toUtc().toIso8601String(),
      },
      'deletedWeights': {
        for (final entry in deletedWeights.entries)
          entry.key: entry.value.toUtc().toIso8601String(),
      },
    };
  }

  String get canonical => canonicalJson(toJson());
}

class SyncMergeResult {
  const SyncMergeResult({
    required this.snapshot,
    required this.localChanged,
    required this.remoteChanged,
  });

  final SyncSnapshot snapshot;
  final bool localChanged;
  final bool remoteChanged;
}

SyncMergeResult mergeSyncSnapshots(SyncSnapshot local, SyncSnapshot? remote) {
  final mergedMeals = <String, MealEntry>{};
  final deletedMeals = <String, DateTime>{};
  final mergedWeights = <String, WeightEntry>{};
  final deletedWeights = <String, DateTime>{};

  final remoteMeals = {
    for (final meal in remote?.meals ?? const []) meal.id: meal,
  };
  final remoteWeights = {
    for (final weight in remote?.weights ?? const []) weight.id: weight,
  };
  final localMeals = {for (final meal in local.meals) meal.id: meal};
  final localWeights = {for (final weight in local.weights) weight.id: weight};
  final remoteDeletedMeals = remote?.deletedMeals ?? const <String, DateTime>{};
  final remoteDeletedWeights =
      remote?.deletedWeights ?? const <String, DateTime>{};

  final mealIds = <String>{
    ...localMeals.keys,
    ...remoteMeals.keys,
    ...local.deletedMeals.keys,
    ...remoteDeletedMeals.keys,
  };
  for (final id in mealIds) {
    final entry = _pickMeal(localMeals[id], remoteMeals[id]);
    final tombstone = _latestDate(
      local.deletedMeals[id],
      remoteDeletedMeals[id],
    );
    if (entry == null) {
      if (tombstone != null) deletedMeals[id] = tombstone;
      continue;
    }
    if (tombstone != null &&
        _mealTime(entry) < tombstone.millisecondsSinceEpoch) {
      deletedMeals[id] = tombstone;
    } else {
      mergedMeals[id] = entry;
    }
  }

  final weightIds = <String>{
    ...localWeights.keys,
    ...remoteWeights.keys,
    ...local.deletedWeights.keys,
    ...remoteDeletedWeights.keys,
  };
  for (final id in weightIds) {
    final entry = _pickWeight(localWeights[id], remoteWeights[id]);
    final tombstone = _latestDate(
      local.deletedWeights[id],
      remoteDeletedWeights[id],
    );
    if (entry == null) {
      if (tombstone != null) deletedWeights[id] = tombstone;
      continue;
    }
    if (tombstone != null &&
        _weightTime(entry) < tombstone.millisecondsSinceEpoch) {
      deletedWeights[id] = tombstone;
    } else {
      mergedWeights[id] = entry;
    }
  }

  final localProfileTime = local.profileUpdatedAt?.millisecondsSinceEpoch ?? 0;
  final remoteProfileTime =
      remote?.profileUpdatedAt?.millisecondsSinceEpoch ?? 0;
  final useRemoteProfile =
      remote != null && remoteProfileTime >= localProfileTime;
  final profile = useRemoteProfile ? remote.profile : local.profile;
  final profileUpdatedAt = _dateFromMillis(
    math.max(localProfileTime, remoteProfileTime),
  );

  final merged = SyncSnapshot(
    meals: mergedMeals.values.toList(),
    weights: mergedWeights.values.toList(),
    profile: profile,
    profileUpdatedAt: profileUpdatedAt,
    deletedMeals: deletedMeals,
    deletedWeights: deletedWeights,
  );

  final mergedCanonical = merged.canonical;
  return SyncMergeResult(
    snapshot: merged,
    localChanged: mergedCanonical != local.canonical,
    remoteChanged: remote == null || mergedCanonical != remote.canonical,
  );
}

MealEntry? _pickMeal(MealEntry? local, MealEntry? remote) {
  if (local == null) return remote;
  if (remote == null) return local;
  final localTime = _mealTime(local);
  final remoteTime = _mealTime(remote);
  if (localTime > remoteTime) return local;
  // 时间相同时以云端为准，保证多设备最终一致。
  return remote;
}

WeightEntry? _pickWeight(WeightEntry? local, WeightEntry? remote) {
  if (local == null) return remote;
  if (remote == null) return local;
  final localTime = _weightTime(local);
  final remoteTime = _weightTime(remote);
  if (localTime > remoteTime) return local;
  return remote;
}

int _mealTime(MealEntry meal) {
  return (meal.updatedAt ?? meal.date).millisecondsSinceEpoch;
}

int _weightTime(WeightEntry weight) {
  return (weight.updatedAt ?? weight.date).millisecondsSinceEpoch;
}

DateTime? _latestDate(DateTime? first, DateTime? second) {
  if (first == null) return second;
  if (second == null) return first;
  return first.isAfter(second) ? first : second;
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

DateTime? _dateFromMillis(int millis) {
  if (millis <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

Map<String, DateTime> _dateMap(Object? value) {
  if (value is! Map) return const {};
  final result = <String, DateTime>{};
  for (final entry in value.entries) {
    final date = _date(entry.value);
    if (date != null && entry.key is String) {
      result[entry.key as String] = date;
    }
  }
  return result;
}

int _compareMeals(MealEntry first, MealEntry second) {
  final byDate = first.date.compareTo(second.date);
  return byDate != 0 ? byDate : first.id.compareTo(second.id);
}

int _compareWeights(WeightEntry first, WeightEntry second) {
  final byDate = first.date.compareTo(second.date);
  return byDate != 0 ? byDate : first.id.compareTo(second.id);
}

String canonicalJson(Object? value) {
  return jsonEncode(_canonicalize(value));
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: _canonicalize(value[key])};
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList();
  }
  return value;
}
