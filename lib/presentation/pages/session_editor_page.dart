import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/providers.dart';
import '../../application/state/session_editor_controller.dart';
import '../../constants/exercise_catalog_constants.dart';
import '../../domain/entities/workout_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import 'exercise_library_page.dart';
import '../widgets/section_card.dart';
import '../widgets/session_editor/session_editor_widgets.dart';

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

  Timer? _timer;
  int _restSeconds = 120;
  bool _timerRunning = false;
  final TextEditingController _restNoteController = TextEditingController();
  String _selectedTrainingType = _trainingTypes.first;
  bool _trainingTypeInitialized = false;

  bool get _isRestDay => _selectedTrainingType == '休息日';
  bool get _isCardio => _selectedTrainingType == '有氧';

  @override
  void dispose() {
    _timer?.cancel();
    _restNoteController.dispose();
    super.dispose();
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

  Future<void> _showWeightInputDialog({
    required SessionEditorController controller,
    required String exerciseId,
    required int setIndex,
    required double current,
  }) async {
    final textController = TextEditingController(
      text: current.toStringAsFixed(1),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入重量'),
        content: TextField(
          controller: textController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: '例如 62.5',
            suffixText: 'kg',
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
              final normalized = (value * 10).round() / 10;
              Navigator.of(context).pop(normalized);
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

  void _initTrainingTypeIfNeeded(WorkoutSession? session) {
    if (_trainingTypeInitialized || session == null) {
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

  bool _isCardioExercise(SessionExercise exercise) {
    return exercise.sets.any((set) => set.setType == ExerciseSetType.cardio);
  }

  T? _firstOrNull<T>(Iterable<T> items) {
    return items.isEmpty ? null : items.first;
  }

  Future<void> _openExerciseLibrary(
    SessionEditorController controller,
  ) async {
    if (_isRestDay) {
      showLatestSnackBar(context, '休息日不支持新增训练动作，请记录恢复备注');
      return;
    }
    final setType = _isCardio
        ? ExerciseSetType.cardio
        : ExerciseSetType.strength;
    final result = await Navigator.of(context).pushNamed<ExerciseSelectionResult>(
      ExerciseLibraryPage.routeName,
      arguments: ExerciseLibraryPageArgs(
        initialMuscleGroup: ExerciseCatalogConstants.normalizeLibraryGroup(
          _selectedTrainingType,
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    final added = controller.addExercise(
      name: result.exerciseName,
      exerciseId: result.exerciseId,
      setType: setType,
      canAdd: !_isRestDay,
      defaultsToZeroWeight: result.defaultsToZeroWeight,
    );
    if (added) {
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

    return Scaffold(
      appBar: AppBar(title: Text('训练记录 · $dateText')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: 96,
          ),
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.error != null
              ? Center(child: Text(state.error!))
              : ListView(
                  children: [
                    SectionCard(
                      title: '会话信息',
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              state.session?.title ?? '未命名训练',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          ModePill(text: sessionModeText(widget.args.mode)),
                        ],
                      ),
                    ),
                    SectionCard(
                      title: '动作管理',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
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
                                      controller.updateSessionTitle(
                                        _titleForTrainingType(item),
                                      );
                                      if (item == '休息日') {
                                        controller.clearExercises();
                                      }
                                      setState(() {
                                        _selectedTrainingType = item;
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: colors.textMuted.withValues(
                                    alpha: 0.16,
                                  ),
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FilledButton.icon(
                                  onPressed: _isRestDay
                                      ? null
                                      : () => _openExerciseLibrary(controller),
                                  icon: const Icon(Icons.add, size: 18),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(122, 42),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                  ),
                                  label: Text(
                                    _isRestDay ? '休息日无需新增动作' : '新增动作',
                                  ),
                                ),
                                if (_isRestDay) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    '恢复建议：轻度拉伸、泡沫轴放松、轻松散步、呼吸训练。',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: colors.textMuted),
                                  ),
                                ],
                              ],
                            ),
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
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.all(12),
                            hintText: '例如：今天低强度活动，重点做下背放松和髋部拉伸。',
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.card,
                            ),
                          ),
                          onChanged: controller.updateNotes,
                        ),
                      ),
                    ...?state.session?.exercises.map((exercise) {
                      final isCardioExercise = _isCardioExercise(exercise);
                      final cardioSet =
                          _firstOrNull(
                            exercise.sets.where(
                              (set) => set.setType == ExerciseSetType.cardio,
                            ),
                          ) ??
                          _firstOrNull(exercise.sets);
                      return SectionCard(
                        title: exercise.exerciseName,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCardioExercise)
                              Text(
                                '单条记录',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.textMuted),
                              ),
                            IconButton(
                              onPressed: () {
                                controller.removeExercise(
                                  exerciseId: exercise.id,
                                );
                                showLatestSnackBar(context, '已删除动作');
                              },
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: colors.textMuted,
                              ),
                              tooltip: '删除动作',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (isCardioExercise) ...[
                              Text(
                                '本动作不分组',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.textMuted),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              if (cardioSet != null)
                                CardioSetRow(
                                  setLabel: '有氧记录',
                                  durationMinutes:
                                      cardioSet.durationMinutes ?? 20,
                                  distanceKm: cardioSet.distanceKm,
                                  onDurationChanged: (value) =>
                                      controller.updateSet(
                                        exerciseId: exercise.id,
                                        setIndex: cardioSet.index,
                                        durationMinutes: value,
                                      ),
                                  onDurationValueTap: () =>
                                      _showDurationInputDialog(
                                        controller: controller,
                                        exerciseId: exercise.id,
                                        setIndex: cardioSet.index,
                                        current:
                                            cardioSet.durationMinutes ?? 20,
                                      ),
                                  onDistanceChanged: (value) =>
                                      controller.updateSet(
                                        exerciseId: exercise.id,
                                        setIndex: cardioSet.index,
                                        distanceKm: value,
                                        clearDistanceKm: value == null,
                                      ),
                                  onDistanceValueTap: () =>
                                      _showDistanceInputDialog(
                                        controller: controller,
                                        exerciseId: exercise.id,
                                        setIndex: cardioSet.index,
                                        current: cardioSet.distanceKm,
                                      ),
                                  onDelete: () {
                                    controller.removeExercise(
                                      exerciseId: exercise.id,
                                    );
                                    showLatestSnackBar(context, '已删除动作');
                                  },
                                ),
                            ] else ...[
                              ...exercise.sets.map(
                                (set) => SetRow(
                                  setLabel: '第${set.index}组',
                                  weight: set.weight,
                                  reps: set.reps,
                                  onWeightChanged: (value) =>
                                      controller.updateSet(
                                        exerciseId: exercise.id,
                                        setIndex: set.index,
                                        weight: value,
                                      ),
                                  onWeightValueTap: () =>
                                      _showWeightInputDialog(
                                        controller: controller,
                                        exerciseId: exercise.id,
                                        setIndex: set.index,
                                        current: set.weight,
                                      ),
                                  onRepsChanged: (value) =>
                                      controller.updateSet(
                                        exerciseId: exercise.id,
                                        setIndex: set.index,
                                        reps: value,
                                      ),
                                  onDelete: () {
                                    final removed = controller.removeSet(
                                      exerciseId: exercise.id,
                                      setIndex: set.index,
                                    );
                                    final text = removed
                                        ? '已删除本组'
                                        : '每个动作至少保留1组';
                                    showLatestSnackBar(context, text);
                                  },
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Align(
                                alignment: Alignment.center,
                                child: FilledButton.tonal(
                                  onPressed: () {
                                    controller.addSet(exerciseId: exercise.id);
                                    showLatestSnackBar(context, '已新增1组');
                                  },
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(88, 36),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 8,
                                    ),
                                    textStyle: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  child: const Text('+组'),
                                ),
                              ),
                            ],
                          ],
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
                              onChanged: (value) {
                                controller.updateDuration(value.round());
                              },
                            ),
                          ),
                          Text('${state.session?.durationMinutes ?? 0} 分钟'),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: state.isSaving
                          ? null
                          : () async {
                              final success = await controller.save();
                              if (!context.mounted) {
                                return;
                              }
                              if (success) {
                                ref.invalidate(homeSnapshotProvider);
                                ref.invalidate(analyticsSnapshotProvider);
                                ref.invalidate(
                                  sessionsByMonthProvider(
                                    DateTime(
                                      widget.args.date.year,
                                      widget.args.date.month,
                                    ),
                                  ),
                                );
                                showLatestSnackBar(context, '训练记录已保存');
                                Navigator.of(context).pop();
                              }
                            },
                      icon: state.isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('保存训练记录'),
                    ),
                  ],
                ),
        ),
      ),
      bottomSheet: _isRestDay
          ? null
          : RestTimerBar(
              seconds: _restSeconds,
              running: _timerRunning,
              onToggle: _toggleTimer,
              onReset: _resetTimer,
              onAdd30: () => setState(() => _restSeconds += 30),
              onSub30: () => setState(
                () => _restSeconds = (_restSeconds - 30).clamp(0, 99999),
              ),
            ),
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
