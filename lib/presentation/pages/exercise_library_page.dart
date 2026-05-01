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

enum ExerciseLibraryMode { selection, browse }

class ExerciseLibraryPageArgs {
  const ExerciseLibraryPageArgs({
    this.initialMuscleGroup,
    this.mode = ExerciseLibraryMode.selection,
  });

  final String? initialMuscleGroup;
  final ExerciseLibraryMode mode;
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
  late final TextEditingController _searchController;
  bool _didApplyInitialMuscleGroup = false;

  bool get _isSelectionMode =>
      (widget.args?.mode ?? ExerciseLibraryMode.selection) ==
      ExerciseLibraryMode.selection;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    if (_isSelectionMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _searchController.clear();
        ref
                .read(
                  selectedExerciseSearchKeywordProvider(
                    selectionExerciseLibrarySearchScope,
                  ).notifier,
                )
                .state =
            '';
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCatalogInBackground();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    if (groups.isEmpty) {
      return;
    }
    final preferred = ExerciseCatalogConstants.normalizeLibraryGroup(
      widget.args?.initialMuscleGroup,
    );
    final nextGroup =
        _isSelectionMode &&
            !_didApplyInitialMuscleGroup &&
            preferred != null &&
            groups.contains(preferred)
        ? preferred
        : (selectedGroup != null && groups.contains(selectedGroup)
              ? selectedGroup
              : groups.first);
    if (selectedGroup == nextGroup) {
      if (_isSelectionMode && !_didApplyInitialMuscleGroup) {
        _didApplyInitialMuscleGroup = true;
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_isSelectionMode && !_didApplyInitialMuscleGroup) {
        _didApplyInitialMuscleGroup = true;
      }
      ref.read(selectedExerciseMuscleGroupProvider.notifier).state = nextGroup;
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
    if (!_isSelectionMode) {
      return;
    }
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
    final currentMode = widget.args?.mode ?? ExerciseLibraryMode.selection;
    final searchScope = _isSelectionMode
        ? selectionExerciseLibrarySearchScope
        : browseExerciseLibrarySearchScope;
    final searchKeyword = ref.watch(
      selectedExerciseSearchKeywordProvider(searchScope),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('动作库'),
        actions: _isSelectionMode
            ? [
                TextButton.icon(
                  onPressed: _showCustomExerciseDialog,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('自定义'),
                ),
              ]
            : null,
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
                      searchKeyword: searchKeyword,
                      searchScope: searchScope,
                      searchController: _searchController,
                      mode: currentMode,
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
    required this.searchKeyword,
    required this.searchScope,
    required this.searchController,
    required this.mode,
  });

  final String selectedGroup;
  final List<String> equipments;
  final String? selectedEquipment;
  final String searchKeyword;
  final String searchScope;
  final TextEditingController searchController;
  final ExerciseLibraryMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final isSearching = searchKeyword.trim().isNotEmpty;
    final itemsAsync = ref.watch(exerciseCatalogItemsProvider(searchScope));
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 18,
      height: 1.05,
      color: colors.textPrimary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            4,
          ),
          child: Text(isSearching ? '搜索结果' : selectedGroup, style: titleStyle),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            6,
          ),
          child: TextField(
            controller: searchController,
            onChanged: (value) {
              ref
                      .read(
                        selectedExerciseSearchKeywordProvider(
                          searchScope,
                        ).notifier,
                      )
                      .state =
                  value;
            },
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '搜索动作名',
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.textMuted,
              ),
              isDense: true,
              filled: true,
              fillColor: colors.panel.withValues(alpha: 0.78),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 10, right: 8),
                child: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: colors.textMuted,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 38,
                minHeight: 38,
              ),
              suffixIcon: searchKeyword.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        ref
                                .read(
                                  selectedExerciseSearchKeywordProvider(
                                    searchScope,
                                  ).notifier,
                                )
                                .state =
                            '';
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: colors.textMuted,
                      ),
                      splashRadius: 18,
                      visualDensity: VisualDensity.compact,
                    ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 34,
                minHeight: 34,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: colors.textMuted.withValues(alpha: 0.16),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: colors.accent.withValues(alpha: 0.42),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: colors.textMuted.withValues(alpha: 0.16),
                ),
              ),
            ),
          ),
        ),
        if (!isSearching)
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('全部'),
                  selected: selectedEquipment == null,
                  labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                  visualDensity: const VisualDensity(
                    horizontal: -2,
                    vertical: -2,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  side: BorderSide(
                    color: colors.textMuted.withValues(alpha: 0.22),
                  ),
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
                      labelStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -2,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                      side: BorderSide(
                        color: colors.textMuted.withValues(alpha: 0.22),
                      ),
                      onSelected: (_) {
                        ref
                                .read(
                                  selectedExerciseEquipmentProvider.notifier,
                                )
                                .state =
                            equipment;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
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
                    isSearching ? '未找到相关动作' : '当前筛选下暂无动作',
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
                  return _ExerciseCard(item: items[index], mode: mode);
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
  const _ExerciseCard({required this.item, required this.mode});

  final ExerciseCatalogItem item;
  final ExerciseLibraryMode mode;

  void _openDetail(BuildContext context) {
    Navigator.of(context).pushNamed(
      ExerciseDetailPage.routeName,
      arguments: ExerciseDetailPageArgs(item: item),
    );
  }

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
          if (mode == ExerciseLibraryMode.selection) {
            Navigator.of(context).pop(
              ExerciseSelectionResult(
                exerciseId: item.id,
                exerciseName: name,
                defaultsToZeroWeight: item.defaultsToZeroWeight,
              ),
            );
            return;
          }
          _openDetail(context);
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
                      onPressed: () => _openDetail(context),
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
