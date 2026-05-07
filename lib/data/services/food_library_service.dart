import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/diet_models.dart';
import '../../utils/app_error.dart';
import '../../utils/app_logger.dart';

class FoodLibraryService {
  static const Map<String, String> _categoryMap = {
    'merged_AnimalFat.json': '动物油脂',
    'merged_CerealsAndCerealProducts.json': '谷物及制品',
    'merged_DriedLegumesAndLegumeProducts.json': '豆类及制品',
    'merged_EggsAndEggProducts.json': '蛋类及制品',
    'merged_FishShellfishAndMollusc.json': '鱼虾贝类',
    'merged_FruitsAndFruitProducts.json': '水果及制品',
    'merged_FungiAndAlgae.json': '菌藻类',
    'merged_InfantFoods.json': '婴幼儿食品',
    'merged_MeatAndMeatProduncts.json': '畜肉及制品',
    'merged_MilkAndMilkProducts.json': '奶类及制品',
    'merged_NutsAndSeeds.json': '坚果与种子',
    'merged_Others.json': '其他',
    'merged_PlantOil.json': '植物油',
    'merged_PoultryAndPoultryProducts.json': '禽类及制品',
    'merged_TubersStarchesAndProducts.json': '薯类淀粉及制品',
    'merged_VegetablesAndVegetableProducts.json': '蔬菜及制品',
  };

  List<FoodItem>? _cache;

  Future<List<FoodItem>> loadFoods() async {
    if (_cache != null) {
      return _cache!;
    }
    try {
      final allFoods = <FoodItem>[];
      for (final entry in _categoryMap.entries) {
        final raw = await rootBundle.loadString(
          'assets/datasets/china-food-composition/${entry.key}',
        );
        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          continue;
        }
        for (final item in decoded) {
          if (item is! Map<String, dynamic>) {
            continue;
          }
          final enriched = Map<String, dynamic>.from(item)
            ..['category'] = entry.value;
          final food = FoodItem.fromJson(enriched);
          if (food.foodCode.isEmpty || food.foodName.trim().isEmpty) {
            continue;
          }
          allFoods.add(food);
        }
      }
      allFoods.sort((a, b) => a.foodName.compareTo(b.foodName));
      _cache = allFoods;
      return allFoods;
    } catch (error, stackTrace) {
      AppLogger.error('加载食物库失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '加载食物库失败，请稍后重试。');
    }
  }

  Future<List<String>> getCategories() async {
    final foods = await loadFoods();
    final categories = foods.map((food) => food.category).toSet().toList()
      ..sort();
    return categories;
  }

  Future<FoodItem?> getFoodByCode(String foodCode) async {
    final foods = await loadFoods();
    for (final food in foods) {
      if (food.foodCode == foodCode) {
        return food;
      }
    }
    return null;
  }

  Future<List<FoodItem>> searchFoods({
    String keyword = '',
    String? category,
  }) async {
    final foods = await loadFoods();
    final normalizedKeyword = keyword.trim().toLowerCase();
    return foods.where((food) {
      final matchCategory =
          category == null || category.isEmpty || food.category == category;
      final matchKeyword =
          normalizedKeyword.isEmpty ||
          food.foodName.toLowerCase().contains(normalizedKeyword);
      return matchCategory && matchKeyword;
    }).toList();
  }
}
