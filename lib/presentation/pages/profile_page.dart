import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../application/state/auth_status.dart';
import '../../application/state/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';
import 'admin_exercise_catalog_page.dart';
import 'admin_food_catalog_page.dart';
import 'analytics_page.dart';
import 'auth_page.dart';
import 'contact_author_page.dart';
import 'personal_info_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _showFeedback(BuildContext context, String message) {
    showLatestSnackBar(context, message);
  }

  Future<void> _showUnitPicker(
    BuildContext context,
    WidgetRef ref,
    bool useKilogram,
  ) async {
    final colors = AppColors.of(context);
    final selected = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '单位设置',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              _UnitOptionTile(
                contentPadding: EdgeInsets.zero,
                value: true,
                selectedValue: useKilogram,
                title: const Text('kg'),
                subtitle: const Text('训练重量以千克展示'),
                selectedColor: colors.accent,
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
              _UnitOptionTile(
                contentPadding: EdgeInsets.zero,
                value: false,
                selectedValue: useKilogram,
                title: const Text('lbs'),
                subtitle: const Text('训练重量以磅展示'),
                selectedColor: colors.accent,
                onTap: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || selected == useKilogram) {
      return;
    }

    await ref.read(settingsProvider.notifier).toggleUnit(selected);
    if (!context.mounted) return;
    _showFeedback(context, selected ? '单位已切换为 kg' : '单位已切换为 lbs');
  }

  Future<void> _showRestPicker(
    BuildContext context,
    WidgetRef ref,
    int defaultRestSeconds,
  ) async {
    var draftRestSeconds = defaultRestSeconds;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '默认组间休息',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$draftRestSeconds 秒',
                  style: Theme.of(sheetContext).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Slider(
                  min: 45,
                  max: 300,
                  divisions: 17,
                  value: draftRestSeconds.toDouble(),
                  onChanged: (value) {
                    setSheetState(() => draftRestSeconds = value.round());
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('保存设置'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true || draftRestSeconds == defaultRestSeconds) {
      return;
    }

    await ref
        .read(settingsProvider.notifier)
        .updateRestSeconds(draftRestSeconds);
    if (!context.mounted) return;
    _showFeedback(context, '默认休息已更新为 $draftRestSeconds 秒');
  }

  Future<void> _confirmAndSignOut(
    BuildContext context,
    WidgetRef ref,
    DateTime currentMonth,
    DateTime selectedDietDate,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认退出登录'),
        content: Text(
          (ref.read(authStatusProvider).valueOrNull ?? AuthStatus.signedOut)
                  .isGuest
              ? '游客退出后将返回登录页，但会保留当前游客身份和训练数据，后续再次点击游客登录可继续使用。'
              : '退出后将返回登录页，本地主题和偏好设置会保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认退出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ref.read(authServiceProvider).signOut();
      ref.invalidate(guestSoftSignedOutProvider);
      invalidateUserScopedMainPageProviders(
        ref,
        calendarMonth: currentMonth,
        dietDate: selectedDietDate,
      );
      if (!context.mounted) return;
      final currentStatus =
          ref.read(authStatusProvider).valueOrNull ?? AuthStatus.signedOut;
      _showFeedback(context, currentStatus.isGuest ? '已退出游客模式' : '已退出登录');
    } catch (error) {
      if (!context.mounted) return;
      final appError = AppError.from(error, fallbackMessage: '退出失败，请稍后重试。');
      _showFeedback(context, appError.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final authStatus =
        ref.watch(authStatusProvider).valueOrNull ?? AuthStatus.signedOut;
    final isAdminAsync = authStatus.isSignedIn
        ? ref.watch(currentUserIsAdminProvider)
        : const AsyncData(false);
    final colors = AppColors.of(context);
    final month = ref.watch(calendarMonthProvider);
    final selectedDietDate = ref.watch(selectedDietDateProvider);

    Future<void> refreshProfile() async {
      try {
        await ref.read(settingsProvider.notifier).loadPersonalInfo();
      } catch (_) {}
      ref.invalidate(currentUserIsAdminProvider);
      await ref
          .read(currentUserIsAdminProvider.future)
          .catchError((_) => false);
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshProfile,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _ProfileHeaderCard(
                colors: colors,
                settings: settings,
                authStatus: authStatus,
                userId: ref.watch(authServiceProvider).currentSession?.user.id,
                onOpenPersonalInfo: () {
                  Navigator.of(context).pushNamed(PersonalInfoPage.routeName);
                },
                onOpenAuth: () {
                  Navigator.of(context).pushNamed(AuthPage.routeName);
                },
                onUpgradeGuest: () {
                  Navigator.of(context).pushNamed(
                    AuthPage.routeName,
                    arguments: const AuthPageArgs(preferUpgrade: true),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _ProfileMenuSection(
                children: [
                  _ProfileMenuTile(
                    icon: Icons.insights_outlined,
                    iconColor: colors.accent,
                    title: '训练统计',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AnalyticsPage(),
                        ),
                      );
                    },
                  ),
                  _ProfileMenuTile(
                    icon: Icons.badge_outlined,
                    iconColor: colors.success,
                    title: '个人信息',
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushNamed(PersonalInfoPage.routeName);
                    },
                  ),
                  _ProfileMenuTile(
                    icon: Icons.straighten,
                    iconColor: colors.warning,
                    title: '单位设置',
                    trailingText: settings.useKilogram ? 'kg' : 'lbs',
                    onTap: () =>
                        _showUnitPicker(context, ref, settings.useKilogram),
                  ),
                  _ProfileMenuTile(
                    icon: Icons.timer_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                    title: '默认组间休息',
                    trailingText: '${settings.defaultRestSeconds} 秒',
                    onTap: () => _showRestPicker(
                      context,
                      ref,
                      settings.defaultRestSeconds,
                    ),
                  ),
                ],
              ),
              _ProfileMenuSection(
                children: [
                  _ProfileMenuTile(
                    icon: settings.isDarkMode
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    iconColor: const Color(0xFF0EA5E9),
                    title: '主题设置',
                    trailingText: settings.isDarkMode ? '深色' : '浅色',
                    onTap: () async {
                      final nextValue = !settings.isDarkMode;
                      await ref
                          .read(settingsProvider.notifier)
                          .toggleDarkMode(nextValue);
                      if (!context.mounted) return;
                      _showFeedback(
                        context,
                        nextValue ? '已切换为黑暗模式' : '已切换为白蓝主题',
                      );
                    },
                  ),
                  _ProfileMenuTile(
                    icon: Icons.chat_bubble_outline,
                    iconColor: colors.success,
                    title: '联系作者',
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushNamed(ContactAuthorPage.routeName);
                    },
                  ),
                  if (authStatus.isSignedIn)
                    _ProfileMenuTile(
                      icon: Icons.logout,
                      iconColor: const Color(0xFFEF4444),
                      title: '退出登录',
                      onTap: () => _confirmAndSignOut(
                        context,
                        ref,
                        month,
                        selectedDietDate,
                      ),
                    ),
                ],
              ),
              if (authStatus.isSignedIn)
                ...isAdminAsync.when(
                  data: (isAdmin) {
                    if (!isAdmin) {
                      return const <Widget>[];
                    }
                    return [
                      _ProfileMenuSection(
                        children: [
                          _ProfileMenuTile(
                            icon: Icons.admin_panel_settings_outlined,
                            iconColor: colors.accent,
                            title: '动作库管理',
                            onTap: () {
                              Navigator.of(
                                context,
                              ).pushNamed(AdminExerciseCatalogPage.routeName);
                            },
                          ),
                          _ProfileMenuTile(
                            icon: Icons.restaurant_menu_outlined,
                            iconColor: colors.warning,
                            title: '食物库管理',
                            onTap: () {
                              Navigator.of(
                                context,
                              ).pushNamed(AdminFoodCatalogPage.routeName);
                            },
                          ),
                        ],
                      ),
                    ];
                  },
                  loading: () => const <Widget>[],
                  error: (_, _) => const <Widget>[],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitOptionTile extends StatelessWidget {
  const _UnitOptionTile({
    required this.contentPadding,
    required this.value,
    required this.selectedValue,
    required this.title,
    required this.subtitle,
    required this.selectedColor,
    required this.onTap,
  });

  final EdgeInsetsGeometry contentPadding;
  final bool value;
  final bool selectedValue;
  final Widget title;
  final Widget subtitle;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value == selectedValue;
    return ListTile(
      contentPadding: contentPadding,
      title: title,
      subtitle: subtitle,
      trailing: selected ? Icon(Icons.check, color: selectedColor) : null,
      onTap: onTap,
    );
  }
}

class _ProfileMenuSection extends StatelessWidget {
  const _ProfileMenuSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  indent: 64,
                  color: colors.textMuted.withValues(alpha: 0.12),
                ),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right, color: colors.textMuted),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.colors,
    required this.settings,
    required this.authStatus,
    required this.userId,
    required this.onOpenPersonalInfo,
    required this.onOpenAuth,
    required this.onUpgradeGuest,
  });

  final AppPalette colors;
  final AppSettings settings;
  final AuthStatus authStatus;
  final String? userId;
  final VoidCallback onOpenPersonalInfo;
  final VoidCallback onOpenAuth;
  final VoidCallback onUpgradeGuest;

  String get _shortUserId {
    final normalized = userId?.replaceAll('-', '').trim() ?? '';
    if (normalized.isEmpty) {
      return '0000';
    }
    final start = normalized.length > 4 ? normalized.length - 4 : 0;
    return normalized.substring(start).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = authStatus.isGuest;
    final isSignedIn = authStatus.isSignedIn;
    final shortUserId = _shortUserId;
    final normalizedProfileName = settings.profileName.trim();
    final displayName = isGuest
        ? '匿名用户 $shortUserId'
        : normalizedProfileName.isEmpty
        ? '即训用户'
        : normalizedProfileName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            _ProfileAvatar(
              colors: colors,
              settings: settings,
              isGuest: isGuest,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSignedIn)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        if (!isGuest)
                          TextButton.icon(
                            onPressed: onOpenPersonalInfo,
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('修改信息'),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.accent,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              textStyle: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '未登录',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: onOpenAuth,
                          child: const Text('登录/注册'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 2),
                  Text(
                    !isSignedIn
                        ? '登录后可同步训练数据'
                        : isGuest
                        ? '即训 ID: $shortUserId · 当前为游客模式，可升级为邮箱账号'
                        : '即训 ID: $shortUserId · 训练目标 · ${settings.trainingGoal ?? '未设置'}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (isGuest)
                    OutlinedButton.icon(
                      onPressed: onUpgradeGuest,
                      icon: const Icon(Icons.upgrade),
                      label: const Text('升级为邮箱账号'),
                    )
                  else if (isSignedIn)
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _InfoBadge(
                          label: '训练年限',
                          value: settings.trainingYears ?? '未设置',
                        ),
                        _InfoBadge(
                          label: '体重',
                          value: settings.weightKg == null
                              ? '未设置'
                              : '${settings.weightKg!.toStringAsFixed(1)}kg',
                        ),
                      ],
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.colors,
    required this.settings,
    required this.isGuest,
  });

  final AppPalette colors;
  final AppSettings settings;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = settings.avatarUrl?.trim();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    const appIcon = AssetImage('assets/branding/app_icon_source.png');

    return CircleAvatar(
      radius: 28,
      backgroundColor: colors.accent.withValues(alpha: 0.2),
      backgroundImage: isGuest ? appIcon : hasAvatar ? NetworkImage(avatarUrl) : appIcon,
      child: null,
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.panelAlt,
        borderRadius: AppRadius.card,
      ),
      child: Text(
        '$label $value',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
