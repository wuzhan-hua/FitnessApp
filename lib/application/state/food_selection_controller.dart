import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/diet_record_service.dart';
import '../../domain/entities/diet_models.dart';
import 'food_selection_state.dart';

class FoodSelectionController extends StateNotifier<FoodSelectionState> {
  FoodSelectionController(this._service, MealType mealType)
    : super(FoodSelectionState.initial(mealType));

  final DietRecordService _service;

  void addOrUpdateFood(FoodItem food, double grams) {
    if (grams <= 0) {
      state = state.copyWith(error: '请输入大于 0 的克数');
      return;
    }
    final existingIndex = state.items.indexWhere(
      (item) => item.foodCode == food.foodCode,
    );
    final nextItems = [...state.items];
    final entry = SelectedFoodEntry(
      foodCode: food.foodCode,
      food: food,
      grams: grams,
    );
    if (existingIndex >= 0) {
      nextItems[existingIndex] = entry;
    } else {
      nextItems.add(entry);
    }
    state = state.copyWith(items: nextItems, error: null);
  }

  void updateGrams(String foodCode, String gramsInput) {
    final grams = double.tryParse(gramsInput.trim()) ?? 0;
    if (grams <= 0) {
      state = state.copyWith(error: '请输入大于 0 的克数');
      return;
    }
    final nextItems = [
      for (final item in state.items)
        if (item.foodCode == foodCode) item.copyWith(grams: grams) else item,
    ];
    state = state.copyWith(items: nextItems, error: null);
  }

  void removeFood(String foodCode) {
    final nextItems = state.items
        .where((item) => item.foodCode != foodCode)
        .toList();
    state = state.copyWith(items: nextItems, error: null);
  }

  Future<void> saveAll(DateTime consumedAt) async {
    if (state.items.isEmpty) {
      state = state.copyWith(error: '请先选择食物');
      return;
    }
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _service.addDietRecords(
        entries: state.items,
        mealType: state.mealType,
        consumedAt: consumedAt,
      );
      state = state.copyWith(isSubmitting: false, error: null);
    } catch (error) {
      state = state.copyWith(isSubmitting: false, error: '$error');
      rethrow;
    }
  }
}
