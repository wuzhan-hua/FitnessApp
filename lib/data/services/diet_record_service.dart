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

  Future<DailyDietSummary> getDailyDietSummary(DateTime date) async {
    final records = await getDietRecordsByDate(date);
    return DailyDietSummary.fromRecords(date, records);
  }
}
