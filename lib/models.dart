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

enum WeightUnit {
  kilograms('kg', '公斤', 1),
  jin('jin', '市斤', 2);

  const WeightUnit(this.symbol, this.label, this.perKilogram);

  /// 存储与接口使用的英文缩写，界面上统一显示 [label]。
  final String symbol;
  final String label;

  /// 1 公斤等于 2 市斤。
  final double perKilogram;

  static WeightUnit fromStorage(Object? value) {
    final text = value is String ? value.trim().toLowerCase() : '';
    if (text == 'jin' || text == '市斤' || text == '斤') return jin;
    // 旧版本偏好里的 g/克 只是显示单位，存储一直是公斤。
    return kilograms;
  }

  double toDisplay(double kg) => kg * perKilogram;

  double toKilograms(double value) => value / perKilogram;

  double displayInput(double kg) => (toDisplay(kg) * 10).roundToDouble() / 10;

  String formatValue(double kg) {
    final value = toDisplay(kg);
    final rounded = (value * 10).roundToDouble() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(1);
  }

  String format(double kg) => '${formatValue(kg)} $label';
}

class UserProfile {
  const UserProfile({
    this.heightCm = 170,
    this.weightKg = 65,
    this.age = 30,
    this.sex = 'male',
    this.activity = 1.375,
    this.targetWeightKg = 60,
    this.weightUnit = WeightUnit.kilograms,
  });

  final double heightCm;
  final double weightKg;
  final int age;
  final String sex;
  final double activity;
  final double targetWeightKg;
  final WeightUnit weightUnit;

  UserProfile copyWith({
    double? heightCm,
    double? weightKg,
    int? age,
    String? sex,
    double? activity,
    double? targetWeightKg,
    WeightUnit? weightUnit,
  }) {
    return UserProfile(
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      activity: activity ?? this.activity,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      weightUnit: weightUnit ?? this.weightUnit,
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
      'weightUnit': weightUnit.symbol,
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
      weightUnit: WeightUnit.fromStorage(json['weightUnit']),
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

  /// Deurenberg 公式的粗略体脂率估算，仅用于观察趋势。
  static double bodyFatPercent(UserProfile profile, {double? weightKg}) {
    final weight = weightKg ?? profile.weightKg;
    final heightM = profile.heightCm / 100;
    if (heightM <= 0 || weight <= 0) return 0;
    final bmi = weight / (heightM * heightM);
    final sexFactor = profile.sex == 'female' ? 0 : 1;
    final estimate = 1.20 * bmi + 0.23 * profile.age - 10.8 * sexFactor - 5.4;
    return estimate.clamp(3.0, 65.0).toDouble();
  }

  static String bodyFatLabel(double percent, String sex) {
    final threshold = sex == 'female'
        ? (low: 14.0, standard: 25.0, high: 32.0)
        : (low: 6.0, standard: 18.0, high: 25.0);
    if (percent < threshold.low) return '偏低';
    if (percent < threshold.standard) return '标准';
    if (percent < threshold.high) return '偏高';
    return '较高';
  }

  /// 减重估算采用的脂肪能量换算值（kcal/kg），仅供粗略估算。
  static const double kcalPerKgFat = 7700;
}
