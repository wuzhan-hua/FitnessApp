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

  void initializeWithRecords(List<DietRecord> records) {
    final items = [
      for (final record in records)
        SelectedFoodEntry(
          foodCode: record.foodCode,
          food: FoodItem(
            foodCode: record.foodCode,
            foodName: record.foodName,
            category: record.foodCategory,
            edible: 100,
            energyKCal: record.grams <= 0
                ? 0
                : record.energyKCal / record.grams * 100,
            energyKJ: 0,
            protein: record.grams <= 0
                ? 0
                : record.protein / record.grams * 100,
            fat: record.grams <= 0 ? 0 : record.fat / record.grams * 100,
            carb: record.grams <= 0 ? 0 : record.carb / record.grams * 100,
            dietaryFiber: record.grams <= 0
                ? 0
                : record.dietaryFiber / record.grams * 100,
            cholesterol: record.grams <= 0
                ? 0
                : record.cholesterol / record.grams * 100,
            sodium: record.grams <= 0 ? 0 : record.sodium / record.grams * 100,
          ),
          grams: record.grams,
          recordId: record.id,
        ),
    ];
    state = state.copyWith(items: items, baselineItems: items, error: null);
  }

  void resetSelection() {
    state = FoodSelectionState.initial(state.mealType);
  }

  Future<void> saveAll(DateTime consumedAt) async {
    if (state.items.isEmpty) {
      if (state.baselineItems.isEmpty) {
        state = state.copyWith(error: '请先选择食物');
        return;
      }
    }
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final baselineByRecordId = {
        for (final item in state.baselineItems)
          if (item.recordId != null && item.recordId!.isNotEmpty)
            item.recordId!: item,
      };
      final currentByRecordId = {
        for (final item in state.items)
          if (item.recordId != null && item.recordId!.isNotEmpty)
            item.recordId!: item,
      };

      for (final baseline in state.baselineItems) {
        final recordId = baseline.recordId;
        if (recordId == null || recordId.isEmpty) {
          continue;
        }
        final current = currentByRecordId[recordId];
        if (current == null) {
          await _service.deleteDietRecord(recordId);
          continue;
        }
        if ((current.grams - baseline.grams).abs() > 0.01) {
          await _service.updateDietRecordByEntry(
            recordId: recordId,
            entry: current,
          );
        }
      }

      final newEntries = state.items
          .where(
            (item) =>
                item.recordId == null ||
                item.recordId!.isEmpty ||
                !baselineByRecordId.containsKey(item.recordId),
          )
          .toList();
      if (newEntries.isNotEmpty) {
        await _service.addDietRecords(
          entries: newEntries,
          mealType: state.mealType,
          consumedAt: consumedAt,
        );
      }
      state = state.copyWith(
        isSubmitting: false,
        baselineItems: state.items,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(isSubmitting: false, error: '$error');
      rethrow;
    }
  }
}
