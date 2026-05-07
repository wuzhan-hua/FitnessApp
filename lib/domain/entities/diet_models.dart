import 'package:flutter/foundation.dart';

import '../../utils/app_time.dart';

enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeX on MealType {
  String get value {
    switch (this) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
      case MealType.snack:
        return 'snack';
    }
  }

  String get label {
    switch (this) {
      case MealType.breakfast:
        return '早餐';
      case MealType.lunch:
        return '午餐';
      case MealType.dinner:
        return '晚餐';
      case MealType.snack:
        return '加餐';
    }
  }

  static MealType from(String? raw) {
    switch (raw) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      case 'snack':
      default:
        return MealType.snack;
    }
  }
}

double _parseNutritionValue(Object? raw, {double fallback = 0}) {
  if (raw == null) {
    return fallback;
  }
  final normalized = raw.toString().trim();
  if (normalized.isEmpty || normalized == '—') {
    return fallback;
  }
  if (normalized.toLowerCase() == 'tr') {
    return 0;
  }
  final sanitized = normalized.replaceAll('*', '');
  return double.tryParse(sanitized) ?? fallback;
}

@immutable
class FoodItem {
  const FoodItem({
    required this.foodCode,
    required this.foodName,
    required this.category,
    required this.edible,
    required this.energyKCal,
    required this.energyKJ,
    required this.protein,
    required this.fat,
    required this.carb,
    required this.dietaryFiber,
    required this.cholesterol,
    required this.sodium,
    this.remark,
  });

  final String foodCode;
  final String foodName;
  final String category;
  final double edible;
  final double energyKCal;
  final double energyKJ;
  final double protein;
  final double fat;
  final double carb;
  final double dietaryFiber;
  final double cholesterol;
  final double sodium;
  final String? remark;

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      foodCode: json['foodCode']?.toString() ?? '',
      foodName: json['foodName']?.toString() ?? '',
      category: json['category']?.toString() ?? '未分类',
      edible: _parseNutritionValue(json['edible'], fallback: 100),
      energyKCal: _parseNutritionValue(json['energyKCal']),
      energyKJ: _parseNutritionValue(json['energyKJ']),
      protein: _parseNutritionValue(json['protein']),
      fat: _parseNutritionValue(json['fat']),
      carb: _parseNutritionValue(json['CHO']),
      dietaryFiber: _parseNutritionValue(json['dietaryFiber']),
      cholesterol: _parseNutritionValue(json['cholesterol']),
      sodium: _parseNutritionValue(json['Na']),
      remark: json['remark']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'foodCode': foodCode,
      'foodName': foodName,
      'category': category,
      'edible': edible,
      'energyKCal': energyKCal,
      'energyKJ': energyKJ,
      'protein': protein,
      'fat': fat,
      'CHO': carb,
      'dietaryFiber': dietaryFiber,
      'cholesterol': cholesterol,
      'Na': sodium,
      'remark': remark,
    };
  }
}

@immutable
class DietRecord {
  const DietRecord({
    required this.id,
    required this.userId,
    required this.foodCode,
    required this.foodName,
    required this.foodCategory,
    required this.mealType,
    required this.grams,
    required this.consumedAt,
    required this.energyKCal,
    required this.protein,
    required this.fat,
    required this.carb,
    required this.dietaryFiber,
    required this.cholesterol,
    required this.sodium,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String foodCode;
  final String foodName;
  final String foodCategory;
  final MealType mealType;
  final double grams;
  final DateTime consumedAt;
  final double energyKCal;
  final double protein;
  final double fat;
  final double carb;
  final double dietaryFiber;
  final double cholesterol;
  final double sodium;
  final DateTime createdAt;

  factory DietRecord.fromJson(Map<String, dynamic> json) {
    return DietRecord(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      foodCode: json['food_code']?.toString() ?? '',
      foodName: json['food_name']?.toString() ?? '',
      foodCategory: json['food_category']?.toString() ?? '未分类',
      mealType: MealTypeX.from(json['meal_type']?.toString()),
      grams: _parseNutritionValue(json['grams']),
      consumedAt: AppTime.parseToLocalDateTime(json['consumed_at']),
      energyKCal: _parseNutritionValue(json['energy_kcal']),
      protein: _parseNutritionValue(json['protein']),
      fat: _parseNutritionValue(json['fat']),
      carb: _parseNutritionValue(json['carb']),
      dietaryFiber: _parseNutritionValue(json['dietary_fiber']),
      cholesterol: _parseNutritionValue(json['cholesterol']),
      sodium: _parseNutritionValue(json['sodium']),
      createdAt: AppTime.parseToLocalDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'food_code': foodCode,
      'food_name': foodName,
      'food_category': foodCategory,
      'meal_type': mealType.value,
      'grams': grams,
      'consumed_at': AppTime.toUtcIsoString(consumedAt),
      'energy_kcal': energyKCal,
      'protein': protein,
      'fat': fat,
      'carb': carb,
      'dietary_fiber': dietaryFiber,
      'cholesterol': cholesterol,
      'sodium': sodium,
      'created_at': AppTime.toUtcIsoString(createdAt),
    };
  }
}

@immutable
class DailyDietSummary {
  const DailyDietSummary({
    required this.date,
    required this.totalEnergyKCal,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarb,
    required this.totalDietaryFiber,
    required this.recordCount,
    required this.mealGroups,
  });

  final DateTime date;
  final double totalEnergyKCal;
  final double totalProtein;
  final double totalFat;
  final double totalCarb;
  final double totalDietaryFiber;
  final int recordCount;
  final Map<MealType, List<DietRecord>> mealGroups;

  static DailyDietSummary fromRecords(DateTime date, List<DietRecord> records) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final groups = <MealType, List<DietRecord>>{
      for (final meal in MealType.values) meal: <DietRecord>[],
    };
    double totalEnergyKCal = 0;
    double totalProtein = 0;
    double totalFat = 0;
    double totalCarb = 0;
    double totalDietaryFiber = 0;

    for (final record in records) {
      groups[record.mealType]!.add(record);
      totalEnergyKCal += record.energyKCal;
      totalProtein += record.protein;
      totalFat += record.fat;
      totalCarb += record.carb;
      totalDietaryFiber += record.dietaryFiber;
    }

    for (final meal in groups.keys) {
      groups[meal]!.sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
    }

    return DailyDietSummary(
      date: normalizedDate,
      totalEnergyKCal: totalEnergyKCal,
      totalProtein: totalProtein,
      totalFat: totalFat,
      totalCarb: totalCarb,
      totalDietaryFiber: totalDietaryFiber,
      recordCount: records.length,
      mealGroups: groups,
    );
  }
}

@immutable
class DietEntryCalculation {
  const DietEntryCalculation({
    required this.energyKCal,
    required this.protein,
    required this.fat,
    required this.carb,
    required this.dietaryFiber,
    required this.cholesterol,
    required this.sodium,
  });

  final double energyKCal;
  final double protein;
  final double fat;
  final double carb;
  final double dietaryFiber;
  final double cholesterol;
  final double sodium;

  factory DietEntryCalculation.fromFood(FoodItem food, double grams) {
    final factor = grams <= 0 ? 0 : grams / 100;
    return DietEntryCalculation(
      energyKCal: food.energyKCal * factor,
      protein: food.protein * factor,
      fat: food.fat * factor,
      carb: food.carb * factor,
      dietaryFiber: food.dietaryFiber * factor,
      cholesterol: food.cholesterol * factor,
      sodium: food.sodium * factor,
    );
  }
}

@immutable
class SelectedFoodEntry {
  const SelectedFoodEntry({
    required this.foodCode,
    required this.food,
    required this.grams,
  });

  final String foodCode;
  final FoodItem food;
  final double grams;

  DietEntryCalculation get calculation =>
      DietEntryCalculation.fromFood(food, grams);

  SelectedFoodEntry copyWith({double? grams}) {
    return SelectedFoodEntry(
      foodCode: foodCode,
      food: food,
      grams: grams ?? this.grams,
    );
  }
}
