import 'package:flutter/foundation.dart';

import '../../domain/entities/diet_models.dart';

@immutable
class FoodSelectionState {
  const FoodSelectionState({
    required this.mealType,
    required this.items,
    required this.baselineItems,
    required this.isSubmitting,
    required this.error,
  });

  final MealType mealType;
  final List<SelectedFoodEntry> items;
  final List<SelectedFoodEntry> baselineItems;
  final bool isSubmitting;
  final String? error;

  int get itemCount => items.length;

  FoodSelectionState copyWith({
    MealType? mealType,
    List<SelectedFoodEntry>? items,
    List<SelectedFoodEntry>? baselineItems,
    bool? isSubmitting,
    String? error,
  }) {
    return FoodSelectionState(
      mealType: mealType ?? this.mealType,
      items: items ?? this.items,
      baselineItems: baselineItems ?? this.baselineItems,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }

  factory FoodSelectionState.initial(MealType mealType) {
    return FoodSelectionState(
      mealType: mealType,
      items: const [],
      baselineItems: const [],
      isSubmitting: false,
      error: null,
    );
  }
}
