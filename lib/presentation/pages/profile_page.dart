import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../application/state/auth_status.dart';
import '../../application/state/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';
import 'admin_exercise_catalog_page.dart';
import 'analytics_page.dart';
import 'auth_page.dart';
import 'personal_info_page.dart';
import '../widgets/section_card.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _showFeedback(BuildContext context, String message) {
    showLatestSnackBar(context, message);
  }

  Future<void> _confirmAndSignOut(
    BuildContext context,
    WidgetRef ref,
    DateTime currentMonth,
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
      ref.invalidate(homeSnapshotProvider);
      ref.invalidate(analyticsSnapshotProvider);
      ref.invalidate(sessionsByMonthProvider(currentMonth));
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ListView(
          children: [
            _ProfileHeaderCard(
              colors: colors,
              settings: settings,
              authStatus: authStatus,
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
            SectionCard(
              title: '数据与回顾',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.insights_outlined),
                title: const Text('训练统计'),
                subtitle: const Text('查看近 30 天训练频率、训练量与 PR 趋势'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AnalyticsPage(),
                    ),
                  );
                },
              ),
            ),
            SectionCard(
              title: '主题设置',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('黑暗模式'),
                subtitle: const Text('开启后切换为深色主题'),
                value: settings.isDarkMode,
                onChanged: (value) async {
                  await ref
                      .read(settingsProvider.notifier)
                      .toggleDarkMode(value);
                  if (!context.mounted) return;
                  _showFeedback(context, value ? '已切换为黑暗模式' : '已切换为白蓝主题');
                },
              ),
            ),
            SectionCard(
              title: '单位设置',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '影响重量相关内容的展示与输入单位',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      textStyle: WidgetStatePropertyAll(
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    segments: const [
                      ButtonSegment<bool>(value: true, label: Text('kg')),
                      ButtonSegment<bool>(value: false, label: Text('lbs')),
                    ],
                    selected: {settings.useKilogram},
                    onSelectionChanged: (value) async {
                      await ref
                          .read(settingsProvider.notifier)
                          .toggleUnit(value.first);
                      if (!context.mounted) return;
                      _showFeedback(
                        context,
                        value.first ? '单位已切换为 kg' : '单位已切换为 lbs',
                      );
                    },
                  ),
                ],
              ),
            ),
            SectionCard(
              title: '默认组间休息',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '同步到训练编辑页，作为计时器重置时的默认休息时长',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('${settings.defaultRestSeconds} 秒'),
                  Slider(
                    min: 45,
                    max: 300,
                    divisions: 17,
                    value: settings.defaultRestSeconds.toDouble(),
                    onChanged: (value) => ref
                        .read(settingsProvider.notifier)
                        .updateRestSeconds(value.round()),
                  ),
                ],
              ),
            ),
            if (authStatus.isSignedIn)
              ...isAdminAsync.when(
                data: (isAdmin) {
                  if (!isAdmin) {
                    return const <Widget>[];
                  }
                  return [
                    SectionCard(
                      title: '管理员入口',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).pushNamed(AdminExerciseCatalogPage.routeName);
                            },
                            icon: const Icon(
                              Icons.admin_panel_settings_outlined,
                            ),
                            label: const Text('动作库管理'),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '可修改动作展示名并维护各肌群下的动作排序。',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
                loading: () => const <Widget>[],
                error: (_, _) => const <Widget>[],
              ),
            if (authStatus.isSignedIn)
              SectionCard(
                title: '账户',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _confirmAndSignOut(context, ref, month),
                      icon: const Icon(Icons.logout),
                      label: const Text('退出登录'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(
                          color: colors.textMuted.withValues(alpha: 0.35),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
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

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.colors,
    required this.settings,
    required this.authStatus,
    required this.onOpenPersonalInfo,
    required this.onOpenAuth,
    required this.onUpgradeGuest,
  });

  final AppPalette colors;
  final AppSettings settings;
  final AuthStatus authStatus;
  final VoidCallback onOpenPersonalInfo;
  final VoidCallback onOpenAuth;
  final VoidCallback onUpgradeGuest;

  @override
  Widget build(BuildContext context) {
    final isGuest = authStatus.isGuest;
    final isSignedIn = authStatus.isSignedIn;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            _ProfileAvatar(colors: colors, settings: settings),
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
                            settings.profileName,
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
                        ? '当前为游客模式，可升级为邮箱账号'
                        : '训练目标 · ${settings.trainingGoal ?? '未设置'}',
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
  const _ProfileAvatar({required this.colors, required this.settings});

  final AppPalette colors;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = settings.avatarUrl?.trim();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return CircleAvatar(
      radius: 28,
      backgroundColor: colors.accent.withValues(alpha: 0.2),
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
      child: hasAvatar
          ? null
          : Text(
              settings.profileName.trim().isEmpty
                  ? '我'
                  : settings.profileName.trim().substring(0, 1),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: colors.accent),
            ),
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
