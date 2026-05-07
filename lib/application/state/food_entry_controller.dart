import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/diet_record_service.dart';
import '../../domain/entities/diet_models.dart';
import 'food_entry_state.dart';

class FoodEntryController extends StateNotifier<FoodEntryState> {
  FoodEntryController(this._service, this._food)
    : super(FoodEntryState.initial);

  final DietRecordService _service;
  final FoodItem _food;

  DietEntryCalculation get calculation =>
      DietEntryCalculation.fromFood(_food, state.grams);

  void updateGrams(String value) {
    state = state.copyWith(gramsInput: value, error: null);
  }

  void updateMealType(MealType mealType) {
    state = state.copyWith(mealType: mealType, error: null);
  }

  Future<void> submit(DateTime consumedAt) async {
    final grams = state.grams;
    if (grams <= 0) {
      state = state.copyWith(error: '请输入大于 0 的克数');
      return;
    }
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _service.addDietRecord(
        food: _food,
        mealType: state.mealType,
        grams: grams,
        consumedAt: consumedAt,
      );
      state = state.copyWith(isSubmitting: false, error: null);
    } catch (error) {
      state = state.copyWith(isSubmitting: false, error: '$error');
      rethrow;
    }
  }
}
