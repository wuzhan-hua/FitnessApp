import 'package:flutter/foundation.dart';

import '../../domain/entities/diet_models.dart';

@immutable
class FoodEntryState {
  const FoodEntryState({
    required this.gramsInput,
    required this.mealType,
    required this.isSubmitting,
    required this.error,
  });

  final String gramsInput;
  final MealType mealType;
  final bool isSubmitting;
  final String? error;

  double get grams => double.tryParse(gramsInput.trim()) ?? 0;

  FoodEntryState copyWith({
    String? gramsInput,
    MealType? mealType,
    bool? isSubmitting,
    String? error,
  }) {
    return FoodEntryState(
      gramsInput: gramsInput ?? this.gramsInput,
      mealType: mealType ?? this.mealType,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }

  static const initial = FoodEntryState(
    gramsInput: '100',
    mealType: MealType.breakfast,
    isSubmitting: false,
    error: null,
  );
}
