import 'package:fitness_client/application/providers/providers.dart';
import 'package:fitness_client/application/state/session_editor_controller.dart';
import 'package:fitness_client/data/repositories/mock_workout_repository.dart';
import 'package:fitness_client/data/repositories/workout_repository.dart';
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

    expect(find.text('未选择'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '胸部'), findsNothing);
    expect(find.text('请先选择训练肌群'), findsOneWidget);
  });

  testWidgets('training type dialog updates title on every selection', (
    tester,
  ) async {
    final past = DateTime.now().subtract(const Duration(days: 2));

    await tester.pumpWidget(
      _buildSessionEditorApp(
        repository: MockWorkoutRepository(),
        args: SessionEditorArgs(
          date: past,
          mode: SessionMode.backfill,
          createOnSaveOnly: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('选择训练肌群'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '胸部'));
    await tester.pumpAndSettle();

    expect(find.text('胸部训练日'), findsOneWidget);
    expect(find.text('胸部'), findsOneWidget);

    await tester.tap(find.text('更换训练肌群'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '有氧'));
    await tester.pumpAndSettle();

    expect(find.text('有氧训练日'), findsOneWidget);
    expect(find.text('胸部训练日'), findsNothing);
    expect(find.text('有氧'), findsOneWidget);
  });

  testWidgets('back with unsaved changes shows leave confirmation dialog', (
    tester,
  ) async {
    SessionEditorExitResult? result;

    await tester.pumpWidget(
      _buildPushedSessionEditorApp(
        repository: _CountingWorkoutRepository(),
        args: SessionEditorArgs(
          date: DateTime.now().subtract(const Duration(days: 2)),
          mode: SessionMode.backfill,
          createOnSaveOnly: true,
        ),
        onResult: (value) => result = value,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('选择训练肌群'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '胸部'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('保存当前修改？'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('保存当前修改？'), findsNothing);
    expect(find.byType(SessionEditorPage), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('discard leaves without saving local draft', (tester) async {
    final repository = _CountingWorkoutRepository();
    SessionEditorExitResult? result;

    await tester.pumpWidget(
      _buildPushedSessionEditorApp(
        repository: repository,
        args: SessionEditorArgs(
          date: DateTime.now().subtract(const Duration(days: 2)),
          mode: SessionMode.backfill,
          createOnSaveOnly: true,
        ),
        onResult: (value) => result = value,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('选择训练肌群'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '胸部'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('不保存'));
    await tester.pumpAndSettle();

    expect(repository.saveSessionCalls, 0);
    expect(result, SessionEditorExitResult.discarded);
  });
}

Widget _buildSessionEditorApp({
  required WorkoutRepository repository,
  required SessionEditorArgs args,
}) {
  return ProviderScope(
    overrides: [
      workoutRepositoryProvider.overrideWithValue(repository),
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
      home: SessionEditorPage(args: args),
    ),
  );
}

Widget _buildPushedSessionEditorApp({
  required WorkoutRepository repository,
  required SessionEditorArgs args,
  required ValueChanged<SessionEditorExitResult?> onResult,
}) {
  return ProviderScope(
    overrides: [
      workoutRepositoryProvider.overrideWithValue(repository),
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
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final value = await Navigator.of(context)
                    .push<SessionEditorExitResult>(
                      MaterialPageRoute<SessionEditorExitResult>(
                        builder: (_) => SessionEditorPage(args: args),
                      ),
                    );
                onResult(value);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CountingWorkoutRepository extends MockWorkoutRepository {
  int saveSessionCalls = 0;

  @override
  Future<WorkoutSession> saveSession(WorkoutSession session) async {
    saveSessionCalls += 1;
    return super.saveSession(session);
  }
}
