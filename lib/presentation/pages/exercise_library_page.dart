import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../constants/exercise_catalog_constants.dart';
import '../../data/services/exercise_catalog_service.dart';
import '../../domain/entities/workout_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';
import 'exercise_detail_page.dart';

class ExerciseSelectionResult {
  const ExerciseSelectionResult({
    required this.exerciseName,
    this.exerciseId,
    this.defaultsToZeroWeight = false,
  });

  final String? exerciseId;
  final String exerciseName;
  final bool defaultsToZeroWeight;
}

class ExerciseLibraryPageArgs {
  const ExerciseLibraryPageArgs({this.initialMuscleGroup});

  final String? initialMuscleGroup;
}

class ExerciseLibraryPage extends ConsumerStatefulWidget {
  const ExerciseLibraryPage({super.key, this.args});

  static const routeName = '/exercise-library';
  final ExerciseLibraryPageArgs? args;

  @override
  ConsumerState<ExerciseLibraryPage> createState() =>
      _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends ConsumerState<ExerciseLibraryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCatalogInBackground();
    });
  }

  Future<void> _refreshCatalogInBackground() async {
    final service = ref.read(exerciseCatalogServiceProvider);
    final refreshed = await service.refreshCatalogIfStale();
    if (!mounted || !refreshed) {
      return;
    }
    ref.invalidate(exerciseMuscleGroupsProvider);
    ref.invalidate(exerciseEquipmentsProvider);
    ref.invalidate(exerciseCatalogItemsProvider);
  }

  void _ensureDefaultGroup(List<String> groups, String? selectedGroup) {
    if (selectedGroup != null || groups.isEmpty) {
      return;
    }
    final preferred = ExerciseCatalogConstants.normalizeLibraryGroup(
      widget.args?.initialMuscleGroup,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(selectedExerciseMuscleGroupProvider.notifier)
          .state = preferred != null && groups.contains(preferred)
          ? preferred
          : groups.first;
      ref.read(selectedExerciseEquipmentProvider.notifier).state = null;
    });
  }

  void _resetInvalidEquipment(
    List<String> equipments,
    String? selectedEquipment,
  ) {
    if (selectedEquipment == null || equipments.contains(selectedEquipment)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(selectedExerciseEquipmentProvider.notifier).state = null;
    });
  }

  Future<void> _showCustomExerciseDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<ExerciseSelectionResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义动作'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '动作名',
            hintText: '例如：史密斯上斜卧推',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                showLatestSnackBar(context, '请输入动作名');
                return;
              }
              Navigator.of(
                context,
              ).pop(ExerciseSelectionResult(exerciseName: name));
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(exerciseMuscleGroupsProvider);
    final selectedGroup = ref.watch(selectedExerciseMuscleGroupProvider);
    final selectedEquipment = ref.watch(selectedExerciseEquipmentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('动作库'),
        actions: [
          TextButton.icon(
            onPressed: _showCustomExerciseDialog,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('自定义'),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            AppError.from(error, fallbackMessage: '加载动作目录失败，请稍后重试。').message,
          ),
        ),
        data: (groups) {
          _ensureDefaultGroup(groups, selectedGroup);
          if (groups.isEmpty) {
            return const Center(child: Text('暂无可用动作目录'));
          }
          final activeGroup = selectedGroup ?? groups.first;
          final equipmentsAsync = ref.watch(exerciseEquipmentsProvider);
          return Row(
            children: [
              _MuscleSidebar(
                groups: groups,
                selectedGroup: activeGroup,
                onSelect: (group) {
                  ref.read(selectedExerciseMuscleGroupProvider.notifier).state =
                      group;
                  ref.read(selectedExerciseEquipmentProvider.notifier).state =
                      null;
                },
              ),
              Expanded(
                child: equipmentsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text(
                      AppError.from(
                        error,
                        fallbackMessage: '加载器械筛选失败，请稍后重试。',
                      ).message,
                    ),
                  ),
                  data: (equipments) {
                    _resetInvalidEquipment(equipments, selectedEquipment);
                    return _ExerciseContent(
                      selectedGroup: activeGroup,
                      equipments: equipments,
                      selectedEquipment: selectedEquipment,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MuscleSidebar extends StatelessWidget {
  const _MuscleSidebar({
    required this.groups,
    required this.selectedGroup,
    required this.onSelect,
  });

  final List<String> groups;
  final String selectedGroup;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: 92,
      color: colors.panelAlt,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final group = groups[index];
          final selected = group == selectedGroup;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelect(group),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected ? colors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  group,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : colors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExerciseContent extends ConsumerWidget {
  const _ExerciseContent({
    required this.selectedGroup,
    required this.equipments,
    required this.selectedEquipment,
  });

  final String selectedGroup;
  final List<String> equipments;
  final String? selectedEquipment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final itemsAsync = ref.watch(exerciseCatalogItemsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Text(
            selectedGroup,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('全部'),
                selected: selectedEquipment == null,
                onSelected: (_) {
                  ref.read(selectedExerciseEquipmentProvider.notifier).state =
                      null;
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              ...equipments.map(
                (equipment) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: ChoiceChip(
                    label: Text(equipment),
                    selected: selectedEquipment == equipment,
                    onSelected: (_) {
                      ref
                              .read(selectedExerciseEquipmentProvider.notifier)
                              .state =
                          equipment;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                AppError.from(
                  error,
                  fallbackMessage: '加载动作列表失败，请稍后重试。',
                ).message,
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    '当前筛选下暂无动作',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.78,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _ExerciseCard(item: items[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.item});

  final ExerciseCatalogItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final name = item.displayName;
    final equipment = item.equipmentZh?.trim().isNotEmpty == true
        ? item.equipmentZh!
        : (item.equipmentEn?.trim().isNotEmpty == true
              ? item.equipmentEn!
              : ExerciseCatalogService.unlabeledEquipment);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: () {
          Navigator.of(context).pop(
            ExerciseSelectionResult(
              exerciseId: item.id,
              exerciseName: name,
              defaultsToZeroWeight: item.defaultsToZeroWeight,
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: colors.panelAlt,
            borderRadius: AppRadius.card,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      color: Colors.white,
                      child:
                          item.coverImageUrl == null ||
                              item.coverImageUrl!.isEmpty
                          ? Icon(
                              Icons.image_not_supported_outlined,
                              color: colors.textMuted,
                              size: 28,
                            )
                          : Image.network(
                              item.coverImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.image_not_supported_outlined,
                                color: colors.textMuted,
                                size: 28,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        equipment,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          ExerciseDetailPage.routeName,
                          arguments: ExerciseDetailPageArgs(item: item),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        minimumSize: const Size(44, 22),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        foregroundColor: colors.accent,
                        textStyle: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 10,
                            ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 13,
                            color: colors.accent,
                          ),
                          const SizedBox(width: 1),
                          const Text('介绍'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
