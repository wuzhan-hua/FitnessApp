import 'package:flutter/foundation.dart';

import '../../domain/entities/workout_models.dart';

enum SessionEditorSavingAction { none, saveProgress, completeSession, autoSave }

@immutable
class SessionEditorState {
  const SessionEditorState({
    required this.isLoading,
    required this.hasUnsavedChanges,
    required this.savingAction,
    required this.session,
    required this.error,
  });

  final bool isLoading;
  final bool hasUnsavedChanges;
  final SessionEditorSavingAction savingAction;
  final WorkoutSession? session;
  final String? error;

  bool get isSaving => savingAction != SessionEditorSavingAction.none;

  SessionEditorState copyWith({
    bool? isLoading,
    bool? hasUnsavedChanges,
    SessionEditorSavingAction? savingAction,
    WorkoutSession? session,
    String? error,
  }) {
    return SessionEditorState(
      isLoading: isLoading ?? this.isLoading,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      savingAction: savingAction ?? this.savingAction,
      session: session ?? this.session,
      error: error,
    );
  }

  static const initial = SessionEditorState(
    isLoading: true,
    hasUnsavedChanges: false,
    savingAction: SessionEditorSavingAction.none,
    session: null,
    error: null,
  );
}
