import 'package:fitness_client/application/providers/providers.dart';
import 'package:fitness_client/data/services/exercise_catalog_service.dart';
import 'package:fitness_client/presentation/pages/exercise_library_page.dart';
import 'package:fitness_client/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('selection mode prefers initial muscle group over stale state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPage(
        args: const ExerciseLibraryPageArgs(initialMuscleGroup: '手臂'),
        initialSelectedGroup: '胸部',
        initialSelectedEquipment: '杠铃',
      ),
    );
    await tester.pumpAndSettle();

    expect(_selectedSidebarLabel('手臂'), findsOneWidget);
    expect(_selectedSidebarLabel('胸部'), findsNothing);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '全部')).selected,
      isTrue,
    );
  });

  testWidgets('browse mode keeps existing selected group', (tester) async {
    await tester.pumpWidget(
      _buildPage(
        args: const ExerciseLibraryPageArgs(
          initialMuscleGroup: '手臂',
          mode: ExerciseLibraryMode.browse,
        ),
        initialSelectedGroup: '胸部',
      ),
    );
    await tester.pumpAndSettle();

    expect(_selectedSidebarLabel('胸部'), findsOneWidget);
    expect(_selectedSidebarLabel('手臂'), findsNothing);
  });

  testWidgets('selection mode allows manual sidebar switch after default', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPage(
        args: const ExerciseLibraryPageArgs(initialMuscleGroup: '腿部'),
      ),
    );
    await tester.pumpAndSettle();

    expect(_selectedSidebarLabel('腿部'), findsOneWidget);

    await tester.tap(find.text('胸部'));
    await tester.pumpAndSettle();

    expect(_selectedSidebarLabel('胸部'), findsOneWidget);
    expect(_selectedSidebarLabel('腿部'), findsNothing);
  });
}

Widget _buildPage({
  required ExerciseLibraryPageArgs args,
  String? initialSelectedGroup,
  String? initialSelectedEquipment,
}) {
  return ProviderScope(
    overrides: [
      exerciseCatalogServiceProvider.overrideWithValue(
        _FakeExerciseCatalogService(),
      ),
      exerciseMuscleGroupsProvider.overrideWith((ref) async => [
        '胸部',
        '腿部',
        '手臂',
        '有氧',
      ]),
      exerciseEquipmentsProvider.overrideWith((ref) async {
        final group = ref.watch(selectedExerciseMuscleGroupProvider);
        if (group == '手臂') {
          return ['绳索'];
        }
        if (group == '胸部') {
          return ['杠铃'];
        }
        if (group == '腿部') {
          return ['器械'];
        }
        return <String>[];
      }),
      exerciseCatalogItemsProvider.overrideWith((ref) async => const []),
      selectedExerciseMuscleGroupProvider.overrideWith(
        (ref) => initialSelectedGroup,
      ),
      selectedExerciseEquipmentProvider.overrideWith(
        (ref) => initialSelectedEquipment,
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: ExerciseLibraryPage(args: args),
    ),
  );
}

Finder _selectedSidebarLabel(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.data == text &&
      widget.style?.color == Colors.white,
);

class _FakeExerciseCatalogService extends ExerciseCatalogService {
  _FakeExerciseCatalogService()
    : super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<bool> refreshCatalogIfStale() async => false;
}
