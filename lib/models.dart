class MealItem {
  const MealItem({
    required this.id,
    required this.name,
    required this.grams,
    required this.kcal,
  });

  final String id;
  final String name;
  final double grams;

  /// 当前 [grams] 对应的总热量，而不是每 100 克热量。
  final double kcal;

  MealItem copyWith({String? id, String? name, double? grams, double? kcal}) {
    return MealItem(
      id: id ?? this.id,
      name: name ?? this.name,
      grams: grams ?? this.grams,
      kcal: kcal ?? this.kcal,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'grams': grams, 'kcal': kcal};
  }

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      id: json['id'] as String,
      name: json['name'] as String,
      grams: (json['grams'] as num).toDouble(),
      kcal: (json['kcal'] as num).toDouble(),
    );
  }
}

class MealEntry {
  const MealEntry({
    required this.id,
    required this.date,
    required this.mealType,
    required this.items,
    this.note = '',
    this.source = '',
    this.updatedAt,
  });

  final String id;
  final DateTime date;
  final String mealType;
  final List<MealItem> items;
  final String note;
  final String source;
  final DateTime? updatedAt;

  double get totalKcal => items.fold(0, (sum, item) => sum + item.kcal);

  MealEntry copyWith({
    String? id,
    DateTime? date,
    String? mealType,
    List<MealItem>? items,
    String? note,
    String? source,
    DateTime? updatedAt,
  }) {
    return MealEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      items: items ?? this.items,
      note: note ?? this.note,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toUtc().toIso8601String(),
      'mealType': mealType,
      'items': items.map((item) => item.toJson()).toList(),
      'note': note,
      'source': source,
      if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    };
  }

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    return MealEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String).toLocal(),
      mealType: json['mealType'] as String,
      items: (json['items'] as List<dynamic>)
          .map(
            (item) => MealItem.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
      note: json['note'] as String? ?? '',
      source: json['source'] as String? ?? '',
      updatedAt: _dateOrNull(json['updatedAt']),
    );
  }
}

class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.date,
    required this.kg,
    this.updatedAt,
  });

  final String id;
  final DateTime date;
  final double kg;
  final DateTime? updatedAt;

  WeightEntry copyWith({
    String? id,
    DateTime? date,
    double? kg,
    DateTime? updatedAt,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      kg: kg ?? this.kg,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toUtc().toIso8601String(),
      'kg': kg,
      if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    };
  }

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String).toLocal(),
      kg: (json['kg'] as num).toDouble(),
      updatedAt: _dateOrNull(json['updatedAt']),
    );
  }
}

DateTime? _dateOrNull(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}

class UserProfile {
  const UserProfile({
    this.heightCm = 170,
    this.weightKg = 65,
    this.age = 30,
    this.sex = 'male',
    this.activity = 1.375,
    this.targetWeightKg = 60,
  });

  final double heightCm;
  final double weightKg;
  final int age;
  final String sex;
  final double activity;
  final double targetWeightKg;

  UserProfile copyWith({
    double? heightCm,
    double? weightKg,
    int? age,
    String? sex,
    double? activity,
    double? targetWeightKg,
  }) {
    return UserProfile(
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      activity: activity ?? this.activity,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'heightCm': heightCm,
      'weightKg': weightKg,
      'age': age,
      'sex': sex,
      'activity': activity,
      'targetWeightKg': targetWeightKg,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      heightCm: (json['heightCm'] as num).toDouble(),
      weightKg: (json['weightKg'] as num).toDouble(),
      age: (json['age'] as num).toInt(),
      sex: json['sex'] as String,
      activity: (json['activity'] as num).toDouble(),
      targetWeightKg: (json['targetWeightKg'] as num).toDouble(),
    );
  }
}

abstract final class NutritionMath {
  /// Mifflin-St Jeor 基础代谢率（kcal/天）。
  static double bmr(UserProfile profile) {
    final sexAdjustment = profile.sex == 'male' ? 5 : -161;
    return 10 * profile.weightKg +
        6.25 * profile.heightCm -
        5 * profile.age +
        sexAdjustment;
  }

  static double tdee(UserProfile profile) => bmr(profile) * profile.activity;

  /// 正数表示热量缺口，负数表示热量盈余。
  static double deficit(double intake, UserProfile profile) {
    return tdee(profile) - intake;
  }

  /// 减重估算采用的脂肪能量换算值（kcal/kg），仅供粗略估算。
  static const double kcalPerKgFat = 7700;
}
