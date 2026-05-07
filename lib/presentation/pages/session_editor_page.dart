import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/providers.dart';
import '../../application/state/session_editor_controller.dart';
import '../../application/state/session_editor_state.dart';
import '../../constants/exercise_catalog_constants.dart';
import '../../domain/entities/workout_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import 'exercise_library_page.dart';
import '../widgets/section_card.dart';
import '../widgets/session_editor/session_editor_widgets.dart';

enum SessionEditorExitResult {
  savedProgress,
  completed,
  autosaved,
  autosaveFailed,
  discarded,
}

enum _LeavePageAction { save, discard, cancel }

class SessionEditorPage extends ConsumerStatefulWidget {
  const SessionEditorPage({super.key, required this.args});

  static const routeName = '/session-editor';

  final SessionEditorArgs args;

  @override
  ConsumerState<SessionEditorPage> createState() => _SessionEditorPageState();
}

class _SessionEditorPageState extends ConsumerState<SessionEditorPage> {
  static const List<String> _trainingTypes =
      ExerciseCatalogConstants.sessionEditorGroups;
  static const String _defaultNewSessionTitle = '新训练日';
  static const double _kgToLbsFactor = 2.20462;
  static const double _kgWeightStep = 2.5;
  static const double _lbsWeightStep = 5.0;

  Timer? _timer;
  int _restSeconds = 120;
  bool _timerRunning = false;
  final TextEditingController _restNoteController = TextEditingController();
  String? _selectedTrainingType;
  String? _activeExerciseId;
  String? _newlyAddedExerciseId;
  bool _trainingTypeInitialized = false;
  bool _isClosing = false;

  bool get _isRestDay => _selectedTrainingType == '休息日';
  bool get _hasTrainingTypeSelected => _selectedTrainingType != null;
  bool get _isReadOnly => widget.args.readOnly;
  bool get _isPastBackfill =>
      widget.args.mode == SessionMode.backfill &&
      _day(widget.args.date).isBefore(_day(DateTime.now()));
  bool get _useKilogram => ref.read(settingsProvider).useKilogram;
  String get _weightUnitLabel => _useKilogram ? 'kg' : 'lbs';
  double get _weightStep => _useKilogram ? _kgWeightStep : _lbsWeightStep;

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  @override
  void initState() {
    super.initState();
    _restSeconds = ref.read(settingsProvider).defaultRestSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restNoteController.dispose();
    super.dispose();
  }

  double _roundToSingleDecimal(double value) => (value * 10).round() / 10;

  double _displayWeightFromKg(double weightKg) {
    if (_useKilogram) {
      return _roundToSingleDecimal(weightKg);
    }
    return _roundToSingleDecimal(weightKg * _kgToLbsFactor);
  }

  double _weightKgFromDisplay(double displayWeight) {
    if (_useKilogram) {
      return _roundToSingleDecimal(displayWeight);
    }
    return _roundToSingleDecimal(displayWeight / _kgToLbsFactor);
  }

  void _toggleTimer() {
    if (_timerRunning) {
      _timer?.cancel();
      setState(() => _timerRunning = false);
      return;
    }

    _timerRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSeconds <= 0) {
        timer.cancel();
        setState(() => _timerRunning = false);
        return;
      }
      setState(() => _restSeconds -= 1);
    });
    setState(() {});
  }

  void _resetTimer() {
    final defaults = ref.read(settingsProvider).defaultRestSeconds;
    _timer?.cancel();
    setState(() {
      _timerRunning = false;
      _restSeconds = defaults;
    });
  }

  Future<void> _openEditableBackfill(WorkoutSession? session) async {
    final sessionId = widget.args.sessionId ?? session?.id;
    if (sessionId == null || sessionId.isEmpty) {
      showLatestSnackBar(context, '未找到训练记录，暂时无法补录');
      return;
    }
    await Navigator.of(
      context,
    ).pushReplacementNamed<SessionEditorExitResult, SessionEditorExitResult>(
      SessionEditorPage.routeName,
      arguments: SessionEditorArgs(
        date: widget.args.date,
        mode: SessionMode.backfill,
        sessionId: sessionId,
        readOnly: false,
      ),
    );
  }

  Future<void> _showWeightInputDialog({
    required SessionEditorController controller,
    required String exerciseId,
    required int setIndex,
    required double current,
  }) async {
    final displayWeight = _displayWeightFromKg(current);
    final textController = TextEditingController(
      text: displayWeight.toStringAsFixed(1),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入重量'),
        content: TextField(
          controller: textController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '例如 62.5',
            suffixText: _weightUnitLabel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(textController.text.trim());
              if (value == null || value < 0) {
                showLatestSnackBar(context, '请输入有效重量（非负数字）');
                return;
              }
              Navigator.of(context).pop(_weightKgFromDisplay(value));
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (result != null) {
      controller.updateSet(
        exerciseId: exerciseId,
        setIndex: setIndex,
        weight: result,
      );
    }
  }

  void _syncRestNoteIfNeeded(WorkoutSession? session) {
    final nextText = session?.notes ?? '';
    if (_restNoteController.text == nextText) {
      return;
    }
    _restNoteController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  Future<void> _showDurationInputDialog({
    required SessionEditorController controller,
    required String exerciseId,
    required int setIndex,
    required int current,
  }) async {
    final textController = TextEditingController(text: current.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入时长'),
        content: TextField(
          controller: textController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '例如 30',
            suffixText: '分钟',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(textController.text.trim());
              if (value == null || value < 0) {
                showLatestSnackBar(context, '请输入有效时长（非负整数）');
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (result != null) {
      controller.updateSet(
        exerciseId: exerciseId,
        setIndex: setIndex,
        durationMinutes: result,
      );
    }
  }

  Future<void> _showDistanceInputDialog({
    required SessionEditorController controller,
    required String exerciseId,
    required int setIndex,
    required double? current,
  }) async {
    const clearFlag = '__clear_distance__';
    final textController = TextEditingController(
      text: current?.toStringAsFixed(1) ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入距离'),
        content: TextField(
          controller: textController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: '例如 5.0',
            suffixText: '公里',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(clearFlag),
            child: const Text('留空'),
          ),
          FilledButton(
            onPressed: () {
              final raw = textController.text.trim();
              final value = double.tryParse(raw);
              if (value == null || value < 0) {
                showLatestSnackBar(context, '请输入有效距离（非负数字）');
                return;
              }
              final normalized = ((value * 10).round() / 10).toString();
              Navigator.of(context).pop(normalized);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (result == null) {
      return;
    }
    if (result == clearFlag) {
      controller.updateSet(
        exerciseId: exerciseId,
        setIndex: setIndex,
        clearDistanceKm: true,
      );
      return;
    }
    final parsed = double.tryParse(result);
    if (parsed != null) {
      controller.updateSet(
        exerciseId: exerciseId,
        setIndex: setIndex,
        distanceKm: parsed,
      );
    }
  }

  String _titleForTrainingType(String trainingType) {
    return ExerciseCatalogConstants.titleForGroup(trainingType);
  }

  String _inferTrainingTypeFromTitle(String? title) {
    return ExerciseCatalogConstants.inferSessionGroupFromTitle(title);
  }

  void _refreshSessionQueries() {
    final currentMonth = DateTime(
      widget.args.date.year,
      widget.args.date.month,
    );
    ref.invalidate(homeSnapshotProvider);
    ref.invalidate(analyticsSnapshotProvider);
    ref.invalidate(sessionsByMonthProvider(currentMonth));
    ref.invalidate(sessionsByCalendarGridProvider(currentMonth));
    ref.invalidate(
      sessionsByCalendarGridProvider(
        DateTime(currentMonth.year, currentMonth.month - 1),
      ),
    );
    ref.invalidate(
      sessionsByCalendarGridProvider(
        DateTime(currentMonth.year, currentMonth.month + 1),
      ),
    );
  }

  Future<void> _closeWithResult([SessionEditorExitResult? result]) async {
    if (_isClosing || !mounted) {
      return;
    }
    _isClosing = true;
    Navigator.of(context).pop(result);
  }

  Future<void> _handleSave({
    required Future<bool> Function() action,
    required SessionEditorExitResult successResult,
  }) async {
    final success = await action();
    if (!mounted) {
      return;
    }
    if (success) {
      _refreshSessionQueries();
      await _closeWithResult(successResult);
    }
  }

  Future<void> _handlePopAttempt() async {
    if (_isClosing) {
      return;
    }
    if (_isReadOnly) {
      await _closeWithResult();
      return;
    }
    final state = ref.read(sessionEditorProvider(widget.args));
    if (state.isSaving) {
      return;
    }
    if (!state.hasUnsavedChanges) {
      await _closeWithResult();
      return;
    }
    final decision = await _showLeaveConfirmationDialog();
    if (!mounted || decision == null || decision == _LeavePageAction.cancel) {
      return;
    }
    if (decision == _LeavePageAction.discard) {
      await _closeWithResult(SessionEditorExitResult.discarded);
      return;
    }
    final controller = ref.read(sessionEditorProvider(widget.args).notifier);
    final success = await controller.autoSaveBeforeExit();
    if (mounted && success) {
      _refreshSessionQueries();
    }
    await _closeWithResult(
      success
          ? SessionEditorExitResult.autosaved
          : SessionEditorExitResult.autosaveFailed,
    );
  }

  Future<_LeavePageAction?> _showLeaveConfirmationDialog() {
    return showDialog<_LeavePageAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('保存当前修改？'),
        content: const Text('你有未保存的修改，离开前是否先保存当前内容？'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_LeavePageAction.cancel),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_LeavePageAction.discard),
            child: const Text('不保存'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_LeavePageAction.save),
            child: const Text('保存并离开'),
          ),
        ],
      ),
    );
  }

  void _initTrainingTypeIfNeeded(WorkoutSession? session) {
    if (_trainingTypeInitialized || session == null) {
      return;
    }
    if (_shouldKeepTrainingTypeUnselected(session)) {
      _trainingTypeInitialized = true;
      return;
    }
    final inferred = _inferTrainingTypeFromTitle(session.title);
    _trainingTypeInitialized = true;
    if (_selectedTrainingType == inferred) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedTrainingType = inferred;
      });
    });
  }

  bool _shouldKeepTrainingTypeUnselected(WorkoutSession session) {
    return widget.args.createOnSaveOnly &&
        session.status == SessionStatus.draft &&
        session.exercises.isEmpty &&
        session.title == _defaultNewSessionTitle;
  }

  Future<void> _showTrainingTypeDialog(
    SessionEditorController controller,
    WorkoutSession? session,
  ) async {
    if (_isReadOnly) {
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择训练肌群'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _trainingTypes
                  .map(
                    (item) => ChoiceChip(
                      label: Text(item),
                      selected: _selectedTrainingType == item,
                      onSelected: (selected) {
                        if (!selected) {
                          return;
                        }
                        Navigator.of(dialogContext).pop(item);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    _handleTrainingTypeSelected(result, controller, session);
  }

  void _handleTrainingTypeSelected(
    String item,
    SessionEditorController controller,
    WorkoutSession? session,
  ) {
    if (_isReadOnly) {
      return;
    }
    if (session != null && session.title != _titleForTrainingType(item)) {
      controller.updateSessionTitle(_titleForTrainingType(item));
    }
    if (item == '休息日') {
      controller.clearExercises();
    }
    setState(() {
      _selectedTrainingType = item;
    });
  }

  bool _isCardioExercise(SessionExercise exercise) {
    return exercise.sets.any((set) => set.setType == ExerciseSetType.cardio);
  }

  T? _firstOrNull<T>(Iterable<T> items) {
    return items.isEmpty ? null : items.first;
  }

  SessionExercise? _findExerciseById(
    WorkoutSession? session,
    String? exerciseId,
  ) {
    if (session == null || exerciseId == null) {
      return null;
    }
    return session.exercises
        .where((exercise) => exercise.id == exerciseId)
        .firstOrNull;
  }

  String _formatSummaryWeight(double value) {
    if (value <= 0) {
      return '0';
    }
    final normalized = _displayWeightFromKg(value);
    final text = normalized.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  double _averageStrengthWeight(SessionExercise exercise) {
    final strengthSets = exercise.sets
        .where((set) => set.setType == ExerciseSetType.strength)
        .toList();
    if (strengthSets.isEmpty) {
      return 0;
    }
    final total = strengthSets.fold<double>(0, (sum, set) => sum + set.weight);
    return total / strengthSets.length;
  }

  String _cardioSummary(SessionExercise exercise) {
    final cardioSets = exercise.sets
        .where((set) => set.setType == ExerciseSetType.cardio)
        .toList();
    if (cardioSets.isEmpty) {
      return '共 ${exercise.sets.length} 组';
    }
    final totalDuration = cardioSets.fold<int>(
      0,
      (sum, set) => sum + (set.durationMinutes ?? 0),
    );
    final totalDistance = cardioSets.fold<double>(
      0,
      (sum, set) => sum + (set.distanceKm ?? 0),
    );
    final details = <String>['共 ${cardioSets.length} 条'];
    if (totalDuration > 0) {
      details.add('$totalDuration 分钟');
    }
    if (totalDistance > 0) {
      final distanceText = totalDistance.toStringAsFixed(1);
      details.add(
        '${distanceText.endsWith('.0') ? distanceText.substring(0, distanceText.length - 2) : distanceText} 公里',
      );
    }
    return details.join(' · ');
  }

  Future<void> _openExerciseDetailSheet(
    SessionEditorController controller,
    SessionExercise exercise,
  ) async {
    if (_isClosing) {
      return;
    }
    setState(() {
      _activeExerciseId = exercise.id;
      if (_newlyAddedExerciseId == exercise.id) {
        _newlyAddedExerciseId = null;
      }
    });
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(sessionEditorProvider(widget.args));
            final settings = ref.watch(settingsProvider);
            final liveExercise = _findExerciseById(
              state.session,
              _activeExerciseId,
            );
            if (liveExercise == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.of(sheetContext).canPop()) {
                  Navigator.of(sheetContext).pop();
                }
              });
              return const SizedBox.shrink();
            }
            final isCardioExercise = _isCardioExercise(liveExercise);
            final cardioSet =
                _firstOrNull(
                  liveExercise.sets.where(
                    (set) => set.setType == ExerciseSetType.cardio,
                  ),
                ) ??
                _firstOrNull(liveExercise.sets);
            final theme = Theme.of(context);
            final colors = AppColors.of(context);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.panel,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.textMuted.withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    liveExercise.exerciseName,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isCardioExercise
                                        ? _cardioSummary(liveExercise)
                                        : '共 ${liveExercise.sets.length} 组 · 平均重量 ${_formatSummaryWeight(_averageStrengthWeight(liveExercise))} $_weightUnitLabel',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close),
                              tooltip: '关闭',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                if (isCardioExercise) ...[
                                  if (cardioSet != null)
                                    CardioSetRow(
                                      setLabel: '有氧记录',
                                      durationMinutes:
                                          cardioSet.durationMinutes ?? 20,
                                      distanceKm: cardioSet.distanceKm,
                                      onDurationChanged: _isReadOnly
                                          ? null
                                          : (value) => controller.updateSet(
                                              exerciseId: liveExercise.id,
                                              setIndex: cardioSet.index,
                                              durationMinutes: value,
                                            ),
                                      onDurationValueTap: _isReadOnly
                                          ? null
                                          : () => _showDurationInputDialog(
                                              controller: controller,
                                              exerciseId: liveExercise.id,
                                              setIndex: cardioSet.index,
                                              current:
                                                  cardioSet.durationMinutes ??
                                                  20,
                                            ),
                                      onDistanceChanged: _isReadOnly
                                          ? null
                                          : (value) => controller.updateSet(
                                              exerciseId: liveExercise.id,
                                              setIndex: cardioSet.index,
                                              distanceKm: value,
                                              clearDistanceKm: value == null,
                                            ),
                                      onDistanceValueTap: _isReadOnly
                                          ? null
                                          : () => _showDistanceInputDialog(
                                              controller: controller,
                                              exerciseId: liveExercise.id,
                                              setIndex: cardioSet.index,
                                              current: cardioSet.distanceKm,
                                            ),
                                      onDelete: _isReadOnly
                                          ? null
                                          : () {
                                              controller.removeExercise(
                                                exerciseId: liveExercise.id,
                                              );
                                              Navigator.of(sheetContext).pop();
                                              showLatestSnackBar(
                                                context,
                                                '已删除动作',
                                              );
                                            },
                                    ),
                                ] else ...[
                                  ...liveExercise.sets.map(
                                    (set) => SetRow(
                                      setLabel: '第${set.index}组',
                                      weight: _displayWeightFromKg(set.weight),
                                      weightStep: _weightStep,
                                      reps: set.reps,
                                      weightLabel: settings.useKilogram
                                          ? '重量(kg)'
                                          : '重量(lbs)',
                                      onWeightChanged: _isReadOnly
                                          ? null
                                          : (value) => controller.updateSet(
                                              exerciseId: liveExercise.id,
                                              setIndex: set.index,
                                              weight: _weightKgFromDisplay(
                                                value,
                                              ),
                                            ),
                                      onWeightValueTap: _isReadOnly
                                          ? null
                                          : () => _showWeightInputDialog(
                                              controller: controller,
                                              exerciseId: liveExercise.id,
                                              setIndex: set.index,
                                              current: set.weight,
                                            ),
                                      onRepsChanged: _isReadOnly
                                          ? null
                                          : (value) => controller.updateSet(
                                              exerciseId: liveExercise.id,
                                              setIndex: set.index,
                                              reps: value,
                                            ),
                                      onDelete: _isReadOnly
                                          ? null
                                          : () {
                                              final removed = controller
                                                  .removeSet(
                                                    exerciseId: liveExercise.id,
                                                    setIndex: set.index,
                                                  );
                                              showLatestSnackBar(
                                                context,
                                                removed
                                                    ? '已删除本组'
                                                    : '每个动作至少保留1组',
                                              );
                                            },
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Align(
                                    alignment: Alignment.center,
                                    child: FilledButton.tonal(
                                      onPressed: _isReadOnly
                                          ? null
                                          : () {
                                              controller.addSet(
                                                exerciseId: liveExercise.id,
                                              );
                                              showLatestSnackBar(
                                                context,
                                                '已新增1组',
                                              );
                                            },
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(88, 36),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 8,
                                        ),
                                        textStyle: theme.textTheme.bodyMedium,
                                      ),
                                      child: const Text('+组'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _activeExerciseId = null;
    });
  }

  Future<void> _openExerciseLibrary(SessionEditorController controller) async {
    if (_isReadOnly) {
      return;
    }
    if (!_hasTrainingTypeSelected) {
      showLatestSnackBar(context, '请先选择训练肌群');
      return;
    }
    if (_isRestDay) {
      showLatestSnackBar(context, '休息日不支持新增训练动作，请记录恢复备注');
      return;
    }
    final result = await Navigator.of(context)
        .pushNamed<ExerciseSelectionResult>(
          ExerciseLibraryPage.routeName,
          arguments: ExerciseLibraryPageArgs(
            initialMuscleGroup: ExerciseCatalogConstants.normalizeLibraryGroup(
              _selectedTrainingType,
            ),
            mode: ExerciseLibraryMode.selection,
          ),
        );
    if (!mounted || result == null) {
      return;
    }
    final addedExercise = controller.addExercise(
      name: result.exerciseName,
      exerciseId: result.exerciseId,
      setType: result.isCardio
          ? ExerciseSetType.cardio
          : ExerciseSetType.strength,
      canAdd: !_isRestDay,
      defaultsToZeroWeight: result.defaultsToZeroWeight,
    );
    if (addedExercise != null) {
      setState(() {
        _newlyAddedExerciseId = addedExercise.id;
      });
      showLatestSnackBar(context, '已新增动作：${result.exerciseName}');
    } else {
      showLatestSnackBar(context, '休息日不支持新增训练动作');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final state = ref.watch(sessionEditorProvider(widget.args));
    final controller = ref.read(sessionEditorProvider(widget.args).notifier);
    final dateText = DateFormat('yyyy/MM/dd').format(widget.args.date);
    _initTrainingTypeIfNeeded(state.session);
    _syncRestNoteIfNeeded(state.session);

    final savingAction = state.savingAction;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _handlePopAttempt();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isReadOnly ? '查看训练 · $dateText' : '训练记录 · $dateText'),
          actions: _isReadOnly
              ? [
                  TextButton(
                    onPressed: state.isLoading
                        ? null
                        : () => _openEditableBackfill(state.session),
                    child: const Text('补录'),
                  ),
                ]
              : null,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.md,
              bottom: AppSpacing.md,
            ),
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                ? Center(child: Text(state.error!))
                : ListView(
                    children: [
                      SectionCard(
                        title: '会话信息',
                        trailing: ModePill(
                          text: sessionModeText(widget.args.mode),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.session?.title ?? '未命名训练',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '训练肌群：${_selectedTrainingType ?? '未选择'}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (!_isReadOnly) ...[
                              const SizedBox(height: AppSpacing.sm),
                              OutlinedButton.icon(
                                onPressed: state.session == null
                                    ? null
                                    : () => _showTrainingTypeDialog(
                                        controller,
                                        state.session,
                                      ),
                                icon: const Icon(Icons.tune_rounded, size: 18),
                                label: Text(
                                  _hasTrainingTypeSelected
                                      ? '更换训练肌群'
                                      : '选择训练肌群',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!_isReadOnly)
                        SectionCard(
                          title: '新增动作',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      _openExerciseLibrary(controller),
                                  icon: const Icon(Icons.add),
                                  label: const Text('新增动作'),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _isRestDay
                                    ? '休息日不支持新增训练动作'
                                    : (_hasTrainingTypeSelected
                                          ? '可切换肌群后添加力量或有氧动作'
                                          : '请先选择训练肌群后再新增动作'),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      if (_isRestDay)
                        SectionCard(
                          title: '恢复备注',
                          child: TextField(
                            controller: _restNoteController,
                            minLines: 3,
                            maxLines: 5,
                            readOnly: _isReadOnly,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.all(12),
                              hintText: '例如：今天低强度活动，重点做下背放松和髋部拉伸。',
                              border: OutlineInputBorder(
                                borderRadius: AppRadius.card,
                              ),
                            ),
                            onChanged: _isReadOnly
                                ? null
                                : controller.updateNotes,
                          ),
                        ),
                      ...?state.session?.exercises.map((exercise) {
                        final isCardioExercise = _isCardioExercise(exercise);
                        final averageWeight = _averageStrengthWeight(exercise);
                        final isNewlyAdded =
                            exercise.id == _newlyAddedExerciseId;
                        final summaryText = isCardioExercise
                            ? _cardioSummary(exercise)
                            : '共 ${exercise.sets.length} 组 · 平均重量 ${_formatSummaryWeight(averageWeight)} $_weightUnitLabel';
                        return Card(
                          color: isNewlyAdded
                              ? colors.panelAlt.withValues(alpha: 0.72)
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.card,
                            side: BorderSide(
                              color: isNewlyAdded
                                  ? colors.accent
                                  : Colors.transparent,
                              width: isNewlyAdded ? 1.2 : 0,
                            ),
                          ),
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: InkWell(
                            borderRadius: AppRadius.card,
                            onTap: () =>
                                _openExerciseDetailSheet(controller, exercise),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exercise.exerciseName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          summaryText,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: colors.textMuted,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  IconButton(
                                    onPressed: () => _openExerciseDetailSheet(
                                      controller,
                                      exercise,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: '编辑动作',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    onPressed: _isReadOnly
                                        ? null
                                        : () {
                                            controller.removeExercise(
                                              exerciseId: exercise.id,
                                            );
                                            showLatestSnackBar(
                                              context,
                                              '已删除动作',
                                            );
                                          },
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: colors.textMuted,
                                    ),
                                    tooltip: '删除动作',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      SectionCard(
                        title: '训练时长',
                        child: Row(
                          children: [
                            Expanded(
                              child: Slider(
                                min: 20,
                                max: 150,
                                divisions: 26,
                                value: (state.session?.durationMinutes ?? 0)
                                    .toDouble()
                                    .clamp(20, 150),
                                onChanged: _isReadOnly
                                    ? null
                                    : (value) {
                                        controller.updateDuration(
                                          value.round(),
                                        );
                                      },
                              ),
                            ),
                            Text('${state.session?.durationMinutes ?? 0} 分钟'),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        bottomNavigationBar: _isReadOnly
            ? null
            : _EditorBottomArea(
                isPastBackfill: _isPastBackfill,
                isRestDay: _isRestDay,
                isSaving: state.isSaving,
                savingAction: savingAction,
                restSeconds: _restSeconds,
                timerRunning: _timerRunning,
                onSaveProgress: () => _handleSave(
                  action: controller.saveProgress,
                  successResult: SessionEditorExitResult.savedProgress,
                ),
                onComplete: () => _handleSave(
                  action: controller.completeSession,
                  successResult: SessionEditorExitResult.completed,
                ),
                onToggleTimer: _toggleTimer,
                onResetTimer: _resetTimer,
                onAdd30: () => setState(() => _restSeconds += 30),
                onSub30: () => setState(
                  () => _restSeconds = (_restSeconds - 30).clamp(0, 99999),
                ),
              ),
      ),
    );
  }
}

class _EditorBottomArea extends StatelessWidget {
  const _EditorBottomArea({
    required this.isPastBackfill,
    required this.isRestDay,
    required this.isSaving,
    required this.savingAction,
    required this.restSeconds,
    required this.timerRunning,
    required this.onSaveProgress,
    required this.onComplete,
    required this.onToggleTimer,
    required this.onResetTimer,
    required this.onAdd30,
    required this.onSub30,
  });

  final bool isPastBackfill;
  final bool isRestDay;
  final bool isSaving;
  final SessionEditorSavingAction savingAction;
  final int restSeconds;
  final bool timerRunning;
  final VoidCallback onSaveProgress;
  final VoidCallback onComplete;
  final VoidCallback onToggleTimer;
  final VoidCallback onResetTimer;
  final VoidCallback onAdd30;
  final VoidCallback onSub30;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final saveProgressLoading =
        savingAction == SessionEditorSavingAction.saveProgress;
    final completeLoading =
        savingAction == SessionEditorSavingAction.completeSession;
    final autoSaving = savingAction == SessionEditorSavingAction.autoSave;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colors.panel,
            border: Border(top: BorderSide(color: colors.panelAlt)),
            boxShadow: [
              BoxShadow(
                color: colors.textPrimary.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (autoSaving)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '正在自动保存...',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              if (isPastBackfill)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isSaving ? null : onComplete,
                    icon: completeLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('完成补录'),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: isSaving ? null : onSaveProgress,
                        icon: saveProgressLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.bookmark_outline),
                        label: const Text('保存进度'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isSaving ? null : onComplete,
                        icon: completeLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: const Text('完成训练'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (!isRestDay && !isPastBackfill)
          RestTimerBar(
            seconds: restSeconds,
            running: timerRunning,
            onToggle: onToggleTimer,
            onReset: onResetTimer,
            onAdd30: onAdd30,
            onSub30: onSub30,
          ),
      ],
    );
  }
}

String sessionModeText(SessionMode mode) {
  switch (mode) {
    case SessionMode.newSession:
      return '新建';
    case SessionMode.continueSession:
      return '继续';
    case SessionMode.backfill:
      return '补录';
  }
}
