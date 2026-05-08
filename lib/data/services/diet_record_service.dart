import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/diet_models.dart';
import '../../utils/app_error.dart';
import '../../utils/app_logger.dart';
import '../../utils/app_time.dart';

class DietRecordService {
  const DietRecordService(this._client);

  final SupabaseClient _client;

  Future<void> addDietRecord({
    required FoodItem food,
    required MealType mealType,
    required double grams,
    required DateTime consumedAt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const AppError(message: '请先登录后再记录饮食。', code: 'auth_required');
    }
    final calculation = DietEntryCalculation.fromFood(food, grams);
    try {
      await _client.from('diet_records').insert({
        'user_id': userId,
        'consumed_at': AppTime.toUtcIsoString(consumedAt),
        'meal_type': mealType.value,
        'food_code': food.foodCode,
        'food_name': food.foodName,
        'food_category': food.category,
        'grams': grams,
        'energy_kcal': calculation.energyKCal,
        'protein': calculation.protein,
        'fat': calculation.fat,
        'carb': calculation.carb,
        'dietary_fiber': calculation.dietaryFiber,
        'cholesterol': calculation.cholesterol,
        'sodium': calculation.sodium,
      });
    } catch (error, stackTrace) {
      AppLogger.error('保存饮食记录失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '保存饮食记录失败，请稍后重试。');
    }
  }

  Future<void> addDietRecords({
    required List<SelectedFoodEntry> entries,
    required MealType mealType,
    required DateTime consumedAt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const AppError(message: '请先登录后再记录饮食。', code: 'auth_required');
    }
    if (entries.isEmpty) {
      throw const AppError(message: '请先选择食物。');
    }
    try {
      final payload = entries.map((entry) {
        final calculation = entry.calculation;
        return {
          'user_id': userId,
          'consumed_at': AppTime.toUtcIsoString(consumedAt),
          'meal_type': mealType.value,
          'food_code': entry.food.foodCode,
          'food_name': entry.food.foodName,
          'food_category': entry.food.category,
          'grams': entry.grams,
          'energy_kcal': calculation.energyKCal,
          'protein': calculation.protein,
          'fat': calculation.fat,
          'carb': calculation.carb,
          'dietary_fiber': calculation.dietaryFiber,
          'cholesterol': calculation.cholesterol,
          'sodium': calculation.sodium,
        };
      }).toList();
      await _client.from('diet_records').insert(payload);
    } catch (error, stackTrace) {
      AppLogger.error('批量保存饮食记录失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '保存饮食记录失败，请稍后重试。');
    }
  }

  Future<List<DietRecord>> getDietRecordsByDate(DateTime date) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return const [];
    }
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    try {
      final rows = await _client
          .from('diet_records')
          .select()
          .eq('user_id', userId)
          .gte('consumed_at', AppTime.toUtcIsoString(start))
          .lt('consumed_at', AppTime.toUtcIsoString(end))
          .order('consumed_at');
      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(DietRecord.fromJson)
          .toList();
    } catch (error, stackTrace) {
      AppLogger.error('加载饮食记录失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '加载饮食记录失败，请稍后重试。');
    }
  }

  Future<List<DietRecord>> getDietRecordsInRange({
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return const [];
    }
    try {
      final rows = await _client
          .from('diet_records')
          .select()
          .eq('user_id', userId)
          .gte('consumed_at', AppTime.toUtcIsoString(fromInclusive))
          .lt('consumed_at', AppTime.toUtcIsoString(toExclusive))
          .order('consumed_at');
      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(DietRecord.fromJson)
          .toList();
    } catch (error, stackTrace) {
      AppLogger.error('加载月度饮食记录失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '加载饮食记录失败，请稍后重试。');
    }
  }

  Future<DailyDietSummary> getDailyDietSummary(DateTime date) async {
    final records = await getDietRecordsByDate(date);
    return DailyDietSummary.fromRecords(date, records);
  }

  Future<void> updateDietRecordGrams({
    required DietRecord record,
    required double grams,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const AppError(message: '请先登录后再操作饮食记录。', code: 'auth_required');
    }
    if (grams <= 0) {
      throw const AppError(message: '请输入大于 0 的克数。');
    }
    final calculation = DietEntryCalculation.fromRecord(record, grams);
    try {
      await _client
          .from('diet_records')
          .update({
            'grams': grams,
            'energy_kcal': calculation.energyKCal,
            'protein': calculation.protein,
            'fat': calculation.fat,
            'carb': calculation.carb,
            'dietary_fiber': calculation.dietaryFiber,
            'cholesterol': calculation.cholesterol,
            'sodium': calculation.sodium,
          })
          .eq('id', record.id)
          .eq('user_id', userId);
    } catch (error, stackTrace) {
      AppLogger.error('更新饮食记录失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '更新饮食记录失败，请稍后重试。');
    }
  }

  Future<void> updateDietRecordByEntry({
    required String recordId,
    required SelectedFoodEntry entry,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const AppError(message: '请先登录后再操作饮食记录。', code: 'auth_required');
    }
    if (entry.grams <= 0) {
      throw const AppError(message: '请输入大于 0 的克数。');
    }
    final calculation = entry.calculation;
    try {
      await _client
          .from('diet_records')
          .update({
            'food_code': entry.food.foodCode,
            'food_name': entry.food.foodName,
            'food_category': entry.food.category,
            'grams': entry.grams,
            'energy_kcal': calculation.energyKCal,
            'protein': calculation.protein,
            'fat': calculation.fat,
            'carb': calculation.carb,
            'dietary_fiber': calculation.dietaryFiber,
            'cholesterol': calculation.cholesterol,
            'sodium': calculation.sodium,
          })
          .eq('id', recordId)
          .eq('user_id', userId)
          .select('id')
          .single();
    } catch (error, stackTrace) {
      AppLogger.error('更新饮食记录失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '更新饮食记录失败，请稍后重试。');
    }
  }

  Future<void> deleteDietRecord(String recordId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const AppError(message: '请先登录后再操作饮食记录。', code: 'auth_required');
    }
    try {
      await _client
          .from('diet_records')
          .delete()
          .eq('id', recordId)
          .eq('user_id', userId)
          .select('id')
          .single();
    } catch (error, stackTrace) {
      AppLogger.error('删除饮食记录失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '删除饮食记录失败，请稍后重试。');
    }
  }
}
