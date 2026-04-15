import 'package:flutter/foundation.dart';

import '../../domain/entities/workout_models.dart';

@immutable
class SessionEditorState {
  const SessionEditorState({
    required this.isLoading,
    required this.isSaving,
    required this.session,
    required this.error,
  });

  final bool isLoading;
  final bool isSaving;
  final WorkoutSession? session;
  final String? error;

  SessionEditorState copyWith({
    bool? isLoading,
    bool? isSaving,
    WorkoutSession? session,
    String? error,
  }) {
    return SessionEditorState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      session: session ?? this.session,
      error: error,
    );
  }

  static const initial = SessionEditorState(
    isLoading: true,
    isSaving: false,
    session: null,
    error: null,
  );
}
