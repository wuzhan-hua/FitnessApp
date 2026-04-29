import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../domain/entities/workout_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';

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
  String? _loadedGroup;
  List<AdminExerciseCatalogItem> _items = const [];
  bool _hasOrderChanges = false;
  bool _isSavingOrder = false;
  final Set<String> _savingNameIds = <String>{};

  void _ensureSelectedGroup(List<String> groups) {
    if (_selectedGroup != null || groups.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedGroup = groups.first;
      });
    });
  }

  void _syncItems(String group, List<AdminExerciseCatalogItem> items) {
    if (_loadedGroup == group && _hasOrderChanges) {
      return;
    }
    final normalized = items.asMap().entries.map((entry) {
      return entry.value.copyWith(sortOrder: entry.key);
    }).toList();
    if (_loadedGroup == group && _sameItemState(_items, normalized)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadedGroup = group;
        _items = normalized;
        _hasOrderChanges = false;
      });
    });
  }

  bool _sameItemState(
    List<AdminExerciseCatalogItem> a,
    List<AdminExerciseCatalogItem> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i].exerciseId != b[i].exerciseId ||
          a[i].displayName != b[i].displayName ||
          a[i].sortOrder != b[i].sortOrder) {
        return false;
      }
    }
    return true;
  }

  Future<void> _saveOrder() async {
    final group = _selectedGroup;
    if (group == null || _isSavingOrder || !_hasOrderChanges) {
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
        _items = _items.asMap().entries.map((entry) {
          return entry.value.copyWith(sortOrder: entry.key);
        }).toList();
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

  Future<void> _renameItem(AdminExerciseCatalogItem item) async {
    final controller = TextEditingController(text: item.customNameZh ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改动作展示名'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: '展示名',
            hintText: item.originalNameZh?.trim().isNotEmpty == true
                ? item.originalNameZh
                : item.nameEn,
          ),
          maxLength: 30,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
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
      final group = _selectedGroup;
      if (group != null) {
        ref.invalidate(adminExerciseCatalogItemsProvider(group));
      }
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
            selectedGroup: _selectedGroup,
            items: _items,
            hasOrderChanges: _hasOrderChanges,
            isSavingOrder: _isSavingOrder,
            savingNameIds: _savingNameIds,
            onEnsureSelectedGroup: _ensureSelectedGroup,
            onSyncItems: _syncItems,
            onSelectGroup: (group) {
              setState(() {
                _selectedGroup = group;
                _loadedGroup = null;
                _hasOrderChanges = false;
                _items = const [];
              });
            },
            onRename: _renameItem,
            onSaveOrder: _saveOrder,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final reordered = [..._items];
                final moved = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, moved);
                _items = reordered.asMap().entries.map((entry) {
                  return entry.value.copyWith(sortOrder: entry.key);
                }).toList();
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
    required this.selectedGroup,
    required this.items,
    required this.hasOrderChanges,
    required this.isSavingOrder,
    required this.savingNameIds,
    required this.onEnsureSelectedGroup,
    required this.onSyncItems,
    required this.onSelectGroup,
    required this.onRename,
    required this.onSaveOrder,
    required this.onReorder,
  });

  final String? selectedGroup;
  final List<AdminExerciseCatalogItem> items;
  final bool hasOrderChanges;
  final bool isSavingOrder;
  final Set<String> savingNameIds;
  final ValueChanged<List<String>> onEnsureSelectedGroup;
  final void Function(String group, List<AdminExerciseCatalogItem> items)
  onSyncItems;
  final ValueChanged<String> onSelectGroup;
  final ValueChanged<AdminExerciseCatalogItem> onRename;
  final VoidCallback onSaveOrder;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(exerciseMuscleGroupsProvider);
    final colors = AppColors.of(context);
    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          AppError.from(error, fallbackMessage: '加载肌群失败，请稍后重试。').message,
        ),
      ),
      data: (groups) {
        onEnsureSelectedGroup(groups);
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
                  onSyncItems(activeGroup, data);
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
                                  ? onSaveOrder
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
                        child: items.isEmpty
                            ? const Center(child: Text('当前肌群暂无动作'))
                            : ReorderableListView.builder(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                itemCount: items.length,
                                onReorder: onReorder,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return _ExerciseAdminTile(
                                    key: ValueKey(item.exerciseId),
                                    item: item,
                                    isSavingName: savingNameIds.contains(
                                      item.exerciseId,
                                    ),
                                    onRename: () => onRename(item),
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
  });

  final AdminExerciseCatalogItem item;
  final bool isSavingName;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final originalName = item.originalNameZh?.trim().isNotEmpty == true
        ? item.originalNameZh!
        : item.nameEn;
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        title: Text(
          item.displayName,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '原始名：$originalName',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: colors.accent.withValues(alpha: 0.12),
          foregroundColor: colors.accent,
          child: Text('${item.sortOrder + 1}'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: isSavingName ? null : onRename,
              tooltip: '修改展示名',
              icon: isSavingName
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_outlined),
            ),
            ReorderableDragStartListener(
              index: item.sortOrder,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
