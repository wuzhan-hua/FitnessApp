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
    this.id,
    required this.foodCode,
    required this.foodName,
    required this.category,
    this.categoryId,
    required this.edible,
    required this.water,
    required this.energyKCal,
    required this.energyKJ,
    required this.protein,
    required this.fat,
    required this.carb,
    required this.dietaryFiber,
    required this.cholesterol,
    required this.ash,
    required this.vitaminA,
    required this.carotene,
    required this.retinol,
    required this.thiamin,
    required this.riboflavin,
    required this.niacin,
    required this.vitaminC,
    required this.vitaminETotal,
    required this.vitaminE1,
    required this.vitaminE2,
    required this.vitaminE3,
    required this.calcium,
    required this.phosphorus,
    required this.potassium,
    required this.sodium,
    required this.magnesium,
    required this.iron,
    required this.zinc,
    required this.selenium,
    required this.copper,
    required this.manganese,
    this.remark,
    this.searchKeywords = '',
    this.sortOrder = 0,
    this.source = 'china-food-composition',
    this.isActive = true,
  });

  final String? id;
  final String foodCode;
  final String foodName;
  final String category;
  final String? categoryId;
  final double edible;
  final double water;
  final double energyKCal;
  final double energyKJ;
  final double protein;
  final double fat;
  final double carb;
  final double dietaryFiber;
  final double cholesterol;
  final double ash;
  final double vitaminA;
  final double carotene;
  final double retinol;
  final double thiamin;
  final double riboflavin;
  final double niacin;
  final double vitaminC;
  final double vitaminETotal;
  final double vitaminE1;
  final double vitaminE2;
  final double vitaminE3;
  final double calcium;
  final double phosphorus;
  final double potassium;
  final double sodium;
  final double magnesium;
  final double iron;
  final double zinc;
  final double selenium;
  final double copper;
  final double manganese;
  final String? remark;
  final String searchKeywords;
  final int sortOrder;
  final String source;
  final bool isActive;

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final categoryRow = json['food_categories'];
    final categoryName = categoryRow is Map<String, dynamic>
        ? categoryRow['name']?.toString()
        : null;
    return FoodItem(
      id: json['id']?.toString(),
      foodCode: (json['foodCode'] ?? json['food_code'])?.toString() ?? '',
      foodName: (json['foodName'] ?? json['food_name'])?.toString() ?? '',
      category: categoryName ?? json['category']?.toString() ?? '未分类',
      categoryId: json['category_id']?.toString(),
      edible: _parseNutritionValue(json['edible'], fallback: 100),
      water: _parseNutritionValue(json['water']),
      energyKCal: _parseNutritionValue(
        json['energyKCal'] ?? json['energy_kcal'],
      ),
      energyKJ: _parseNutritionValue(json['energyKJ'] ?? json['energy_kj']),
      protein: _parseNutritionValue(json['protein']),
      fat: _parseNutritionValue(json['fat']),
      carb: _parseNutritionValue(json['CHO'] ?? json['carb']),
      dietaryFiber: _parseNutritionValue(
        json['dietaryFiber'] ?? json['dietary_fiber'],
      ),
      cholesterol: _parseNutritionValue(json['cholesterol']),
      ash: _parseNutritionValue(json['ash']),
      vitaminA: _parseNutritionValue(json['vitaminA'] ?? json['vitamin_a']),
      carotene: _parseNutritionValue(json['carotene']),
      retinol: _parseNutritionValue(json['retinol']),
      thiamin: _parseNutritionValue(json['thiamin']),
      riboflavin: _parseNutritionValue(json['riboflavin']),
      niacin: _parseNutritionValue(json['niacin']),
      vitaminC: _parseNutritionValue(json['vitaminC'] ?? json['vitamin_c']),
      vitaminETotal: _parseNutritionValue(
        json['vitaminETotal'] ?? json['vitamin_e_total'],
      ),
      vitaminE1: _parseNutritionValue(json['vitaminE1'] ?? json['vitamin_e1']),
      vitaminE2: _parseNutritionValue(json['vitaminE2'] ?? json['vitamin_e2']),
      vitaminE3: _parseNutritionValue(json['vitaminE3'] ?? json['vitamin_e3']),
      calcium: _parseNutritionValue(json['Ca'] ?? json['calcium']),
      phosphorus: _parseNutritionValue(json['P'] ?? json['phosphorus']),
      potassium: _parseNutritionValue(json['K'] ?? json['potassium']),
      sodium: _parseNutritionValue(json['Na'] ?? json['sodium']),
      magnesium: _parseNutritionValue(json['Mg'] ?? json['magnesium']),
      iron: _parseNutritionValue(json['Fe'] ?? json['iron']),
      zinc: _parseNutritionValue(json['Zn'] ?? json['zinc']),
      selenium: _parseNutritionValue(json['Se'] ?? json['selenium']),
      copper: _parseNutritionValue(json['Cu'] ?? json['copper']),
      manganese: _parseNutritionValue(json['Mn'] ?? json['manganese']),
      remark: json['remark']?.toString(),
      searchKeywords: json['search_keywords']?.toString() ?? '',
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
      source: json['source']?.toString() ?? 'china-food-composition',
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'foodCode': foodCode,
      'foodName': foodName,
      'category': category,
      if (categoryId != null) 'category_id': categoryId,
      'edible': edible,
      'water': water,
      'energyKCal': energyKCal,
      'energyKJ': energyKJ,
      'protein': protein,
      'fat': fat,
      'CHO': carb,
      'dietaryFiber': dietaryFiber,
      'cholesterol': cholesterol,
      'ash': ash,
      'vitaminA': vitaminA,
      'carotene': carotene,
      'retinol': retinol,
      'thiamin': thiamin,
      'riboflavin': riboflavin,
      'niacin': niacin,
      'vitaminC': vitaminC,
      'vitaminETotal': vitaminETotal,
      'vitaminE1': vitaminE1,
      'vitaminE2': vitaminE2,
      'vitaminE3': vitaminE3,
      'Ca': calcium,
      'P': phosphorus,
      'K': potassium,
      'Na': sodium,
      'Mg': magnesium,
      'Fe': iron,
      'Zn': zinc,
      'Se': selenium,
      'Cu': copper,
      'Mn': manganese,
      'remark': remark,
      'search_keywords': searchKeywords,
      'sort_order': sortOrder,
      'source': source,
      'is_active': isActive,
    };
  }

  Map<String, dynamic> toSupabaseJson({
    required String categoryId,
    String? createdBy,
  }) {
    final json = {
      'food_code': foodCode,
      'food_name': foodName,
      'category_id': categoryId,
      'edible': edible,
      'water': water,
      'energy_kcal': energyKCal,
      'energy_kj': energyKJ,
      'protein': protein,
      'fat': fat,
      'carb': carb,
      'dietary_fiber': dietaryFiber,
      'cholesterol': cholesterol,
      'ash': ash,
      'vitamin_a': vitaminA,
      'carotene': carotene,
      'retinol': retinol,
      'thiamin': thiamin,
      'riboflavin': riboflavin,
      'niacin': niacin,
      'vitamin_c': vitaminC,
      'vitamin_e_total': vitaminETotal,
      'vitamin_e1': vitaminE1,
      'vitamin_e2': vitaminE2,
      'vitamin_e3': vitaminE3,
      'calcium': calcium,
      'phosphorus': phosphorus,
      'potassium': potassium,
      'sodium': sodium,
      'magnesium': magnesium,
      'iron': iron,
      'zinc': zinc,
      'selenium': selenium,
      'copper': copper,
      'manganese': manganese,
      'remark': remark,
      'search_keywords': searchKeywords,
      'sort_order': sortOrder,
      'source': source,
      'is_active': isActive,
    };
    if (createdBy != null) {
      json['created_by'] = createdBy;
    }
    return json;
  }
}

@immutable
class FoodCategory {
  const FoodCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  factory FoodCategory.fromJson(Map<String, dynamic> json) {
    return FoodCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
      isActive: json['is_active'] != false,
    );
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

  factory DietEntryCalculation.fromRecord(DietRecord record, double grams) {
    final factor = record.grams <= 0 ? 0 : grams / record.grams;
    return DietEntryCalculation(
      energyKCal: record.energyKCal * factor,
      protein: record.protein * factor,
      fat: record.fat * factor,
      carb: record.carb * factor,
      dietaryFiber: record.dietaryFiber * factor,
      cholesterol: record.cholesterol * factor,
      sodium: record.sodium * factor,
    );
  }
}

@immutable
class SelectedFoodEntry {
  const SelectedFoodEntry({
    required this.foodCode,
    required this.food,
    required this.grams,
    this.recordId,
  });

  final String foodCode;
  final FoodItem food;
  final double grams;
  final String? recordId;

  DietEntryCalculation get calculation =>
      DietEntryCalculation.fromFood(food, grams);

  SelectedFoodEntry copyWith({double? grams, String? recordId}) {
    return SelectedFoodEntry(
      foodCode: foodCode,
      food: food,
      grams: grams ?? this.grams,
      recordId: recordId ?? this.recordId,
    );
  }
}
