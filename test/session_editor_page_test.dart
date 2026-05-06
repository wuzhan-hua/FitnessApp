import 'package:fitness_client/application/providers/providers.dart';
import 'package:fitness_client/application/state/settings_controller.dart';
import 'package:fitness_client/application/state/session_editor_controller.dart';
import 'package:fitness_client/data/repositories/mock_workout_repository.dart';
import 'package:fitness_client/data/repositories/workout_repository.dart';
import 'package:fitness_client/data/services/auth_service.dart';
import 'package:fitness_client/data/services/exercise_catalog_service.dart';
import 'package:fitness_client/data/services/user_profile_service.dart';
import 'package:fitness_client/domain/entities/workout_models.dart';
import 'package:fitness_client/domain/entities/user_profile.dart';
import 'package:fitness_client/presentation/pages/exercise_library_page.dart';
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

    expect(find.text('完成补录'), findsOneWidget);
    expect(find.text('保存进度'), findsNothing);
    expect(find.text('完成训练'), findsNothing);
  });

  testWidgets('createOnSaveOnly draft does not preselect training type', (
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

    expect(find.text('训练肌群：未选择'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '胸部'), findsNothing);
    expect(find.text('训练肌群：未选择'), findsOneWidget);
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
    expect(find.text('训练肌群：胸部'), findsOneWidget);

    await tester.tap(find.text('更换训练肌群'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '有氧'));
    await tester.pumpAndSettle();

    expect(find.text('有氧训练日'), findsOneWidget);
    expect(find.text('胸部训练日'), findsNothing);
    expect(find.text('训练肌群：有氧'), findsOneWidget);
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

  testWidgets('exercise list renders summary cards and no add-exercise card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSessionEditorApp(
        repository: MockWorkoutRepository(),
        args: SessionEditorArgs(
          date: DateTime.now(),
          mode: SessionMode.continueSession,
          sessionId: 'session-ongoing',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('新增动作'), findsNWidgets(2));
    expect(find.text('请先选择训练肌群'), findsNothing);
    expect(find.text('训练肌群：胸部'), findsOneWidget);
    expect(find.text('第1组'), findsNothing);
    expect(find.text('共 3 组 · 平均重量 77.5 kg'), findsOneWidget);
    await tester.ensureVisible(find.text('负重双杠臂屈伸'));
    expect(find.text('共 1 组 · 平均重量 25 kg'), findsOneWidget);
  });

  testWidgets('add action entry is rendered as section card instead of fab', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSessionEditorApp(
        repository: MockWorkoutRepository(),
        args: SessionEditorArgs(
          date: DateTime.now(),
          mode: SessionMode.continueSession,
          sessionId: 'session-ongoing',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('新增动作'), findsAtLeastNWidgets(1));
    expect(find.text('可切换肌群后添加力量或有氧动作'), findsOneWidget);
  });

  testWidgets('adding cardio exercise from non-cardio session uses cardio rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSessionEditorAppWithRoutes(
        repository: MockWorkoutRepository(),
        args: SessionEditorArgs(
          date: DateTime.now(),
          mode: SessionMode.continueSession,
          sessionId: 'session-ongoing',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增动作').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('有氧').last);
    await tester.tap(find.text('有氧'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跑步机慢跑'));
    await tester.pumpAndSettle();

    expect(find.textContaining('训练日'), findsOneWidget);
    expect(find.textContaining('训练肌群：'), findsOneWidget);
    expect(find.text('跑步机慢跑'), findsOneWidget);
    expect(find.textContaining('共 1 条'), findsOneWidget);
    expect(find.textContaining('20 分钟'), findsOneWidget);

    final cardioCard = find.ancestor(
      of: find.text('跑步机慢跑'),
      matching: find.byType(Card),
    ).first;
    await tester.ensureVisible(cardioCard);
    await tester.tap(cardioCard, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('时长'), findsOneWidget);
    expect(find.text('距离'), findsOneWidget);
    expect(find.text('重量'), findsNothing);
    expect(find.text('次数'), findsNothing);
  });

  testWidgets('newly added exercise is highlighted without auto opening sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSessionEditorAppWithRoutes(
        repository: MockWorkoutRepository(),
        args: SessionEditorArgs(
          date: DateTime.now(),
          mode: SessionMode.continueSession,
          sessionId: 'session-ongoing',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增动作').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('有氧').last);
    await tester.tap(find.text('有氧'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跑步机慢跑'));
    await tester.pumpAndSettle();

    expect(find.text('时长'), findsNothing);
    expect(find.text('距离'), findsNothing);

    final cardioCard = find.ancestor(
      of: find.text('跑步机慢跑'),
      matching: find.byType(Card),
    ).first;
    final highlightedCard = tester.widget<Card>(cardioCard);
    expect(highlightedCard.color, isNotNull);

    await tester.ensureVisible(cardioCard);
    await tester.tap(cardioCard, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('时长'), findsOneWidget);
    expect(find.text('距离'), findsOneWidget);
  });

  testWidgets('tap exercise summary opens bottom sheet detail editor', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSessionEditorApp(
        repository: MockWorkoutRepository(),
        args: SessionEditorArgs(
          date: DateTime.now(),
          mode: SessionMode.continueSession,
          sessionId: 'session-ongoing',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstExerciseCard = find.ancestor(
      of: find.text('杠铃卧推'),
      matching: find.byType(Card),
    ).first;
    await tester.ensureVisible(firstExerciseCard);
    await tester.tap(firstExerciseCard, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('第1组'), findsOneWidget);
    expect(find.text('+组'), findsOneWidget);
    expect(find.text('共 3 组 · 平均重量 77.5 kg'), findsNWidgets(2));
  });

  testWidgets('editing sets in bottom sheet updates summary', (tester) async {
    await tester.pumpWidget(
      _buildSessionEditorApp(
        repository: MockWorkoutRepository(),
        args: SessionEditorArgs(
          date: DateTime.now(),
          mode: SessionMode.continueSession,
          sessionId: 'session-ongoing',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstExerciseCard = find.ancestor(
      of: find.text('杠铃卧推'),
      matching: find.byType(Card),
    ).first;
    await tester.ensureVisible(firstExerciseCard);
    await tester.tap(firstExerciseCard, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+组'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    expect(find.text('共 4 组 · 平均重量 78.1 kg'), findsOneWidget);
  });
}

Widget _buildSessionEditorApp({
  required WorkoutRepository repository,
  required SessionEditorArgs args,
}) {
  final client = _buildTestSupabaseClient();
  return ProviderScope(
    overrides: [
      workoutRepositoryProvider.overrideWithValue(repository),
      authServiceProvider.overrideWithValue(_TestAuthService(client)),
      userProfileServiceProvider.overrideWithValue(_TestUserProfileService(client)),
      settingsProvider.overrideWith(
        (ref) => SettingsController(
          ref.watch(authServiceProvider),
          ref.watch(userProfileServiceProvider),
        ),
      ),
      exerciseCatalogServiceProvider.overrideWithValue(
        _TestExerciseCatalogService(client),
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
  final client = _buildTestSupabaseClient();
  return ProviderScope(
    overrides: [
      workoutRepositoryProvider.overrideWithValue(repository),
      authServiceProvider.overrideWithValue(_TestAuthService(client)),
      userProfileServiceProvider.overrideWithValue(_TestUserProfileService(client)),
      settingsProvider.overrideWith(
        (ref) => SettingsController(
          ref.watch(authServiceProvider),
          ref.watch(userProfileServiceProvider),
        ),
      ),
      exerciseCatalogServiceProvider.overrideWithValue(
        _TestExerciseCatalogService(client),
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

Widget _buildSessionEditorAppWithRoutes({
  required WorkoutRepository repository,
  required SessionEditorArgs args,
}) {
  final client = _buildTestSupabaseClient();
  return ProviderScope(
    overrides: [
      workoutRepositoryProvider.overrideWithValue(repository),
      authServiceProvider.overrideWithValue(_TestAuthService(client)),
      userProfileServiceProvider.overrideWithValue(_TestUserProfileService(client)),
      settingsProvider.overrideWith(
        (ref) => SettingsController(
          ref.watch(authServiceProvider),
          ref.watch(userProfileServiceProvider),
        ),
      ),
      exerciseCatalogServiceProvider.overrideWithValue(
        _RouteAwareExerciseCatalogService(client),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      onGenerateRoute: (settings) {
        if (settings.name == ExerciseLibraryPage.routeName) {
          return MaterialPageRoute<ExerciseSelectionResult?>(
            builder: (_) => ExerciseLibraryPage(
              args: settings.arguments as ExerciseLibraryPageArgs?,
            ),
          );
        }
        return null;
      },
      home: SessionEditorPage(args: args),
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

SupabaseClient _buildTestSupabaseClient() {
  return SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
}

class _TestAuthService extends AuthService {
  _TestAuthService(super.client);

  @override
  Session? get currentSession => null;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
}

class _TestUserProfileService extends UserProfileService {
  _TestUserProfileService(super.client);

  @override
  Future<UserProfile?> fetchCurrentUserProfile() async => null;
}

class _TestExerciseCatalogService extends ExerciseCatalogService {
  _TestExerciseCatalogService(super.client);

  @override
  Future<Set<String>> getDefaultZeroWeightExerciseIds(
    Iterable<String> exerciseIds,
  ) async {
    return const <String>{};
  }
}

class _RouteAwareExerciseCatalogService extends _TestExerciseCatalogService {
  _RouteAwareExerciseCatalogService(super.client);

  @override
  Future<List<String>> getPrimaryMuscleGroups() async => ['胸部', '腿部', '手臂', '有氧'];

  @override
  Future<List<String>> getEquipmentsByMuscleGroup(String muscleGroup) async =>
      const [];

  @override
  Future<List<ExerciseCatalogItem>> getExercises({
    required String muscleGroup,
    String? equipment,
  }) async {
    if (muscleGroup == '有氧') {
      return const [
        ExerciseCatalogItem(
          id: 'cardio-1',
          nameEn: 'Treadmill Jog',
          nameZh: '跑步机慢跑',
          primaryMusclesEn: ['cardio'],
          primaryMusclesZh: ['有氧'],
          categoryEn: 'cardio',
          categoryZh: '有氧',
        ),
      ];
    }
    return const [
      ExerciseCatalogItem(
        id: 'strength-1',
        nameEn: 'Bench Press',
        nameZh: '杠铃卧推',
        primaryMusclesEn: ['chest'],
        primaryMusclesZh: ['胸部'],
        categoryEn: 'strength',
      ),
    ];
  }
}
