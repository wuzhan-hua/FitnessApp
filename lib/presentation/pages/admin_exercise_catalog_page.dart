import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../application/providers/providers.dart';
import '../../domain/entities/workout_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';

List<AdminExerciseCatalogItem> _rebuildSortOrders(
  List<AdminExerciseCatalogItem> items,
) {
  return items.asMap().entries.map((entry) {
    return entry.value.copyWith(sortOrder: entry.key);
  }).toList();
}

class AdminExerciseCatalogPage extends ConsumerStatefulWidget {
  const AdminExerciseCatalogPage({super.key});

  static const routeName = '/admin-exercise-catalog';

  @override
  ConsumerState<AdminExerciseCatalogPage> createState() =>
      _AdminExerciseCatalogPageState();
}

class _AdminExerciseCatalogPageState
    extends ConsumerState<AdminExerciseCatalogPage> {
  String? _selectedGroup;
  List<AdminExerciseCatalogItem> _items = const [];
  bool _hasOrderChanges = false;
  bool _isSavingOrder = false;
  final Set<String> _savingNameIds = <String>{};

  void _applyReorderedItems(List<AdminExerciseCatalogItem> items) {
    setState(() {
      _items = _rebuildSortOrders(items);
      _hasOrderChanges = true;
    });
  }

  void _moveItemToPosition(
    AdminExerciseCatalogItem item,
    int targetPosition,
    List<AdminExerciseCatalogItem> currentItems,
  ) {
    final currentIndex = currentItems.indexWhere(
      (current) => current.exerciseId == item.exerciseId,
    );
    if (currentIndex == -1 || currentItems.isEmpty) {
      return;
    }

    final clampedIndex = (targetPosition - 1).clamp(0, currentItems.length - 1);
    if (clampedIndex == currentIndex) {
      return;
    }

    final reordered = [...currentItems];
    final moved = reordered.removeAt(currentIndex);
    reordered.insert(clampedIndex, moved);
    _applyReorderedItems(reordered);
  }

  Future<void> _saveOrder(String group) async {
    if (_isSavingOrder || !_hasOrderChanges) {
      return;
    }
    setState(() => _isSavingOrder = true);
    try {
      await ref
          .read(exerciseCatalogServiceProvider)
          .saveExerciseOrders(
            muscleGroup: group,
            orderedExerciseIds: _items.map((item) => item.exerciseId).toList(),
          );
      ref.invalidate(adminExerciseCatalogItemsProvider(group));
      ref.invalidate(exerciseCatalogItemsProvider);
      ref.invalidate(exerciseEquipmentsProvider);
      ref.invalidate(exerciseMuscleGroupsProvider);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = _rebuildSortOrders(_items);
        _hasOrderChanges = false;
      });
      showLatestSnackBar(context, '动作排序已保存');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showLatestSnackBar(
        context,
        AppError.from(error, fallbackMessage: '保存动作排序失败，请稍后重试。').message,
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingOrder = false);
      }
    }
  }

  Future<void> _editItemOrder(
    AdminExerciseCatalogItem item,
    List<AdminExerciseCatalogItem> currentItems,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _EditOrderDialog(currentPosition: item.sortOrder + 1),
    );

    if (!mounted || result == null) {
      return;
    }

    final parsed = int.tryParse(result);
    if (parsed == null) {
      showLatestSnackBar(context, '请输入有效排序名次');
      return;
    }

    final targetPosition = parsed.clamp(1, currentItems.length);
    if (targetPosition == item.sortOrder + 1) {
      return;
    }
    _moveItemToPosition(item, targetPosition, currentItems);
    showLatestSnackBar(context, '已移动到第 $targetPosition 位');
  }

  Future<void> _renameItem(AdminExerciseCatalogItem item) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _RenameExerciseDialog(
        initialName: item.customNameZh ?? '',
        hintName: item.originalNameZh?.trim().isNotEmpty == true
            ? item.originalNameZh!
            : item.nameEn,
      ),
    );
    if (result == null) {
      return;
    }
    setState(() {
      _savingNameIds.add(item.exerciseId);
    });
    try {
      await ref
          .read(exerciseCatalogServiceProvider)
          .updateExerciseCustomName(
            exerciseId: item.exerciseId,
            customNameZh: result,
          );
      final displayName = result.isEmpty
          ? ((item.originalNameZh?.trim().isNotEmpty == true)
                ? item.originalNameZh!
                : item.nameEn)
          : result;
      if (!mounted) {
        return;
      }
      setState(() {
        _items = _items.map((current) {
          if (current.exerciseId != item.exerciseId) {
            return current;
          }
          return current.copyWith(
            displayName: displayName,
            customNameZh: result.isEmpty ? null : result,
            clearCustomNameZh: result.isEmpty,
          );
        }).toList();
      });
      ref.invalidate(adminExerciseCatalogItemsProvider(item.muscleGroup));
      ref.invalidate(exerciseCatalogItemsProvider);
      ref.invalidate(exerciseEquipmentsProvider);
      ref.invalidate(exerciseMuscleGroupsProvider);
      showLatestSnackBar(context, '动作展示名已保存');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showLatestSnackBar(
        context,
        AppError.from(error, fallbackMessage: '更新动作展示名失败，请稍后重试。').message,
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingNameIds.remove(item.exerciseId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(currentUserIsAdminProvider);
    final groupsAsync = ref.watch(exerciseMuscleGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('动作库管理')),
      body: isAdminAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            AppError.from(error, fallbackMessage: '加载权限失败，请稍后重试。').message,
          ),
        ),
        data: (isAdmin) {
          if (!isAdmin) {
            return const Center(child: Text('当前账号没有管理员权限'));
          }
          return _AdminBody(
            groupsAsync: groupsAsync,
            selectedGroup: _selectedGroup,
            items: _items,
            hasOrderChanges: _hasOrderChanges,
            isSavingOrder: _isSavingOrder,
            savingNameIds: _savingNameIds,
            onSelectGroup: (group) {
              setState(() {
                _selectedGroup = group;
                _hasOrderChanges = false;
                _items = const [];
              });
            },
            onRename: _renameItem,
            onEditOrder: _editItemOrder,
            onSaveOrder: _saveOrder,
            onReorder: (currentItems, oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final reordered = [...currentItems];
                final moved = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, moved);
                _items = _rebuildSortOrders(reordered);
                _hasOrderChanges = true;
              });
            },
          );
        },
      ),
    );
  }
}

class _AdminBody extends ConsumerWidget {
  const _AdminBody({
    required this.groupsAsync,
    required this.selectedGroup,
    required this.items,
    required this.hasOrderChanges,
    required this.isSavingOrder,
    required this.savingNameIds,
    required this.onSelectGroup,
    required this.onRename,
    required this.onEditOrder,
    required this.onSaveOrder,
    required this.onReorder,
  });

  final AsyncValue<List<String>> groupsAsync;
  final String? selectedGroup;
  final List<AdminExerciseCatalogItem> items;
  final bool hasOrderChanges;
  final bool isSavingOrder;
  final Set<String> savingNameIds;
  final ValueChanged<String> onSelectGroup;
  final ValueChanged<AdminExerciseCatalogItem> onRename;
  final void Function(
    AdminExerciseCatalogItem item,
    List<AdminExerciseCatalogItem> currentItems,
  )
  onEditOrder;
  final ValueChanged<String> onSaveOrder;
  final void Function(
    List<AdminExerciseCatalogItem> currentItems,
    int oldIndex,
    int newIndex,
  )
  onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          AppError.from(error, fallbackMessage: '加载肌群失败，请稍后重试。').message,
        ),
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return const Center(child: Text('暂无可管理动作'));
        }
        final activeGroup = selectedGroup ?? groups.first;
        final itemsAsync = ref.watch(
          adminExerciseCatalogItemsProvider(activeGroup),
        );
        return Row(
          children: [
            _GroupSidebar(
              groups: groups,
              selectedGroup: activeGroup,
              onSelect: onSelectGroup,
            ),
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
                data: (data) {
                  final displayItems = hasOrderChanges
                      ? items
                      : _rebuildSortOrders(data);
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: colors.textMuted.withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$activeGroup 动作排序',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: hasOrderChanges && !isSavingOrder
                                  ? () => onSaveOrder(activeGroup)
                                  : null,
                              icon: isSavingOrder
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(isSavingOrder ? '保存中...' : '保存排序'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: displayItems.isEmpty
                            ? const Center(child: Text('当前肌群暂无动作'))
                            : ReorderableListView.builder(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                buildDefaultDragHandles: false,
                                itemCount: displayItems.length,
                                onReorder: (oldIndex, newIndex) =>
                                    onReorder(displayItems, oldIndex, newIndex),
                                itemBuilder: (context, index) {
                                  final item = displayItems[index];
                                  return _ExerciseAdminTile(
                                    key: ValueKey(item.exerciseId),
                                    item: item,
                                    isSavingName: savingNameIds.contains(
                                      item.exerciseId,
                                    ),
                                    onRename: () => onRename(item),
                                    onEditOrder: () =>
                                        onEditOrder(item, displayItems),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GroupSidebar extends StatelessWidget {
  const _GroupSidebar({
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

class _ExerciseAdminTile extends StatelessWidget {
  const _ExerciseAdminTile({
    super.key,
    required this.item,
    required this.isSavingName,
    required this.onRename,
    required this.onEditOrder,
  });

  final AdminExerciseCatalogItem item;
  final bool isSavingName;
  final VoidCallback onRename;
  final VoidCallback onEditOrder;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final originalName = item.originalNameZh?.trim().isNotEmpty == true
        ? item.originalNameZh!
        : item.nameEn;
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colors.accent.withValues(alpha: 0.12),
                  foregroundColor: colors.accent,
                  child: Text('${item.sortOrder + 1}'),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                '原始名：$originalName',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onEditOrder,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('排序'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSavingName ? null : onRename,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(isSavingName ? '保存中' : '改名'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: ReorderableDragStartListener(
                      index: item.sortOrder,
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('拖动'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditOrderDialog extends StatefulWidget {
  const _EditOrderDialog({required this.currentPosition});

  final int currentPosition;

  @override
  State<_EditOrderDialog> createState() => _EditOrderDialogState();
}

class _EditOrderDialogState extends State<_EditOrderDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.currentPosition}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('调整排序名次'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: '目标名次',
          hintText: '请输入排序位置',
          helperText: '当前第 ${widget.currentPosition} 位',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('确认'),
        ),
      ],
    );
  }
}

class _RenameExerciseDialog extends StatefulWidget {
  const _RenameExerciseDialog({
    required this.initialName,
    required this.hintName,
  });

  final String initialName;
  final String hintName;

  @override
  State<_RenameExerciseDialog> createState() => _RenameExerciseDialogState();
}

class _RenameExerciseDialogState extends State<_RenameExerciseDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改动作展示名'),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: '展示名',
          hintText: widget.hintName,
        ),
        maxLength: 30,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
