import 'package:fitness_client/application/providers/providers.dart';
import 'package:fitness_client/application/state/session_editor_controller.dart';
import 'package:fitness_client/data/repositories/mock_workout_repository.dart';
import 'package:fitness_client/data/services/exercise_catalog_service.dart';
import 'package:fitness_client/domain/entities/workout_models.dart';
import 'package:fitness_client/presentation/pages/session_editor_page.dart';
import 'package:fitness_client/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('past backfill shows only complete backfill action', (
    tester,
  ) async {
    final past = DateTime.now().subtract(const Duration(days: 1));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutRepositoryProvider.overrideWithValue(MockWorkoutRepository()),
          exerciseCatalogServiceProvider.overrideWithValue(
            ExerciseCatalogService(
              SupabaseClient(
                'http://localhost',
                'test-key',
                authOptions: const AuthClientOptions(autoRefreshToken: false),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: SessionEditorPage(
            args: SessionEditorArgs(
              date: past,
              mode: SessionMode.backfill,
              createOnSaveOnly: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('完成补录'), findsOneWidget);
    expect(find.text('保存进度'), findsNothing);
    expect(find.text('完成训练'), findsNothing);
  });

  testWidgets('createOnSaveOnly draft does not preselect training type', (
    tester,
  ) async {
    final past = DateTime.now().subtract(const Duration(days: 2));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutRepositoryProvider.overrideWithValue(MockWorkoutRepository()),
          exerciseCatalogServiceProvider.overrideWithValue(
            ExerciseCatalogService(
              SupabaseClient(
                'http://localhost',
                'test-key',
                authOptions: const AuthClientOptions(autoRefreshToken: false),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: SessionEditorPage(
            args: SessionEditorArgs(
              date: past,
              mode: SessionMode.backfill,
              createOnSaveOnly: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('请先选择训练类型'), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '胸部')).selected,
      isFalse,
    );
  });
}
