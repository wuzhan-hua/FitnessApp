import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/diet_models.dart';
import '../../utils/app_error.dart';
import '../../utils/app_logger.dart';

class FoodLibraryService {
  FoodLibraryService(this._client, {bool useRemote = true})
    : _useRemote = useRemote;

  final SupabaseClient _client;
  final bool _useRemote;

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

  static const List<String> preferredCategoryOrder = [
    '畜肉及制品',
    '禽类及制品',
    '蛋类及制品',
    '鱼虾贝类',
    '奶类及制品',
    '豆类及制品',
    '谷物及制品',
    '薯类淀粉及制品',
    '蔬菜及制品',
    '水果及制品',
    '坚果与种子',
    '菌藻类',
    '动物油脂',
    '植物油',
    '婴幼儿食品',
    '其他',
  ];

  List<FoodItem>? _remoteFoodCache;
  List<FoodItem>? _assetFoodCache;
  List<FoodCategory>? _remoteCategoryCache;

  Future<List<FoodItem>> loadFoods() async {
    if (!_useRemote) {
      return _loadAssetFoods();
    }
    try {
      return await _loadRemoteFoods(activeOnly: true);
    } catch (error, stackTrace) {
      AppLogger.error(
        '加载 Supabase 食物库失败，回退本地食物库',
        error: error,
        stackTrace: stackTrace,
      );
      return _loadAssetFoods();
    }
  }

  Future<List<FoodCategory>> getFoodCategories({bool activeOnly = true}) async {
    if (!_useRemote) {
      if (!activeOnly) {
        throw const AppError(message: '当前环境未连接 Supabase，无法管理食物分类。');
      }
      return _loadAssetCategories();
    }
    try {
      if (activeOnly && _remoteCategoryCache != null) {
        return _remoteCategoryCache!;
      }
      var query = _client
          .from('food_categories')
          .select('id,name,sort_order,is_active');
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      final rows = await query.order('sort_order').order('name');
      final categories = List<Map<String, dynamic>>.from(rows as List<dynamic>)
          .map(FoodCategory.fromJson)
          .where(
            (category) => category.id.isNotEmpty && category.name.isNotEmpty,
          )
          .toList();
      if (activeOnly) {
        _remoteCategoryCache = categories;
      }
      return categories;
    } catch (error, stackTrace) {
      AppLogger.error('加载食物分类失败', error: error, stackTrace: stackTrace);
      if (!activeOnly) {
        throw AppError.from(error, fallbackMessage: '加载食物分类失败，请稍后重试。');
      }
      return _loadAssetCategories();
    }
  }

  Future<List<String>> getCategories() async {
    final categories = await getFoodCategories();
    return categories.map((category) => category.name).toList();
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
    final tokens = _buildSearchTokens(keyword);
    return foods.where((food) {
      final hasKeyword = tokens.isNotEmpty;
      final matchCategory =
          hasKeyword ||
          category == null ||
          category.isEmpty ||
          food.category == category;
      final haystack =
          '${food.foodName} ${food.searchKeywords} ${food.category}'
              .toLowerCase();
      final matchKeyword =
          !hasKeyword || tokens.any((token) => haystack.contains(token));
      return matchCategory && matchKeyword;
    }).toList();
  }

  Future<List<FoodItem>> getAdminFoods({String? categoryId}) async {
    try {
      var query = _client
          .from('food_catalog_items')
          .select('*,food_categories(id,name,sort_order,is_active)');
      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.eq('category_id', categoryId);
      }
      final rows = await query.order('sort_order').order('food_name');
      return List<Map<String, dynamic>>.from(
        rows as List<dynamic>,
      ).map(FoodItem.fromJson).toList();
    } catch (error, stackTrace) {
      AppLogger.error('加载管理食物列表失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '加载食物列表失败，请稍后重试。');
    }
  }

  Future<void> createFood({
    required FoodItem food,
    required String categoryId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const AppError(message: '请先登录后再管理食物。', code: 'auth_required');
    }
    try {
      await _client
          .from('food_catalog_items')
          .insert(
            food
                .toSupabaseJson(categoryId: categoryId, createdBy: user.id)
                .map((key, value) => MapEntry(key, value)),
          );
      clearCache();
    } catch (error, stackTrace) {
      AppLogger.error('新增食物失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '新增食物失败，请稍后重试。');
    }
  }

  Future<void> updateFood({
    required String id,
    required FoodItem food,
    required String categoryId,
  }) async {
    try {
      await _client
          .from('food_catalog_items')
          .update(food.toSupabaseJson(categoryId: categoryId))
          .eq('id', id);
      clearCache();
    } catch (error, stackTrace) {
      AppLogger.error('更新食物失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '更新食物失败，请稍后重试。');
    }
  }

  Future<void> setFoodActive({
    required String id,
    required bool isActive,
  }) async {
    try {
      await _client
          .from('food_catalog_items')
          .update({'is_active': isActive})
          .eq('id', id);
      clearCache();
    } catch (error, stackTrace) {
      AppLogger.error('更新食物启用状态失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '更新食物状态失败，请稍后重试。');
    }
  }

  Future<void> saveFoodOrders({required List<String> orderedFoodIds}) async {
    try {
      for (final entry in orderedFoodIds.asMap().entries) {
        await _client
            .from('food_catalog_items')
            .update({'sort_order': entry.key})
            .eq('id', entry.value);
      }
      clearCache();
    } catch (error, stackTrace) {
      AppLogger.error('保存食物排序失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '保存食物排序失败，请稍后重试。');
    }
  }

  Future<FoodCategory> createCategory(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const AppError(message: '分类名称不能为空。');
    }
    try {
      final current = await getFoodCategories(activeOnly: false);
      final sortOrder = current.length;
      final row = await _client
          .from('food_categories')
          .insert({
            'name': normalized,
            'sort_order': sortOrder,
            'is_active': true,
          })
          .select('id,name,sort_order,is_active')
          .single();
      _remoteCategoryCache = null;
      return FoodCategory.fromJson(row);
    } catch (error, stackTrace) {
      AppLogger.error('新增食物分类失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '新增食物分类失败，请稍后重试。');
    }
  }

  void clearCache() {
    _remoteFoodCache = null;
    _remoteCategoryCache = null;
  }

  Future<List<FoodItem>> _loadRemoteFoods({required bool activeOnly}) async {
    if (activeOnly && _remoteFoodCache != null) {
      return _remoteFoodCache!;
    }
    var query = _client
        .from('food_catalog_items')
        .select('*,food_categories(id,name,sort_order,is_active)');
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final rows = await query.order('sort_order').order('food_name');
    final foods = List<Map<String, dynamic>>.from(
      rows as List<dynamic>,
    ).map(FoodItem.fromJson).toList();
    if (activeOnly) {
      _remoteFoodCache = foods;
    }
    return foods;
  }

  Future<List<FoodItem>> _loadAssetFoods() async {
    if (_assetFoodCache != null) {
      return _assetFoodCache!;
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
      allFoods.sort((a, b) {
        final categoryCompare = _compareCategoryName(a.category, b.category);
        if (categoryCompare != 0) {
          return categoryCompare;
        }
        return a.foodName.compareTo(b.foodName);
      });
      _assetFoodCache = allFoods;
      return allFoods;
    } catch (error, stackTrace) {
      AppLogger.error('加载本地食物库失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '加载食物库失败，请稍后重试。');
    }
  }

  Future<List<FoodCategory>> _loadAssetCategories() async {
    final foods = await _loadAssetFoods();
    final names = foods.map((food) => food.category).toSet().toList()
      ..sort(_compareCategoryName);
    return names
        .asMap()
        .entries
        .map(
          (entry) => FoodCategory(
            id: entry.value,
            name: entry.value,
            sortOrder: entry.key,
            isActive: true,
          ),
        )
        .toList();
  }

  List<String> _buildSearchTokens(String keyword) {
    final normalized = keyword.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }
    final tokens = <String>{normalized};
    for (final char in normalized.split('')) {
      if (RegExp(r'[\u4e00-\u9fa5a-zA-Z0-9]').hasMatch(char)) {
        tokens.add(char);
      }
    }
    return tokens.toList();
  }

  int _compareCategoryName(String a, String b) {
    final aIndex = preferredCategoryOrder.indexOf(a);
    final bIndex = preferredCategoryOrder.indexOf(b);
    if (aIndex >= 0 && bIndex >= 0) {
      return aIndex.compareTo(bIndex);
    }
    if (aIndex >= 0) {
      return -1;
    }
    if (bIndex >= 0) {
      return 1;
    }
    return a.compareTo(b);
  }
}
