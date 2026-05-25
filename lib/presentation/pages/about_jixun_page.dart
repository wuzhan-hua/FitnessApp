import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/providers/providers.dart';
import '../../application/state/auth_status.dart';
import '../../constants/legal_constants.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';
import 'admin_exercise_catalog_page.dart';
import 'admin_food_catalog_page.dart';
import 'cancel_account_page.dart';
import 'legal_document_page.dart';

class AboutJixunPage extends ConsumerWidget {
  const AboutJixunPage({super.key});

  static const routeName = '/about-jixun';

  void _showFeedback(BuildContext context, String message) {
    showLatestSnackBar(context, message);
  }

  Future<void> _openLegalDocument(
    BuildContext context, {
    required String url,
    required String documentName,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      _showFeedback(context, '请先配置$documentName地址后再使用。');
      return;
    }

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) {
      _showFeedback(context, '$documentName地址格式无效，请检查配置。');
      return;
    }

    if (!kIsWeb) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LegalDocumentPage(title: documentName, url: url),
        ),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      _showFeedback(context, '打开$documentName失败，请稍后重试。');
    }
  }

  Future<void> _confirmAndSignOut(
    BuildContext context,
    WidgetRef ref,
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
      ref.invalidate(authSessionProvider);
      ref.invalidate(authStatusProvider);
      invalidateAuthScopedProvidersOnSignOut(ref, dietDate: selectedDietDate);
      if (!context.mounted) return;
      final currentStatus =
          ref.read(authStatusProvider).valueOrNull ?? AuthStatus.signedOut;
      _showFeedback(context, currentStatus.isGuest ? '已退出游客模式' : '已退出登录');
      Navigator.of(context).pop();
    } catch (error) {
      if (!context.mounted) return;
      final appError = AppError.from(error, fallbackMessage: '退出失败，请稍后重试。');
      _showFeedback(context, appError.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final authSession = ref.watch(authSessionProvider).valueOrNull;
    final authStatus =
        authSession?.status ??
        ref.watch(authStatusProvider).valueOrNull ??
        AuthStatus.signedOut;
    final isAdminAsync = authStatus.isSignedIn
        ? ref.watch(currentUserIsAdminProvider)
        : const AsyncData(false);
    final selectedDietDate = ref.watch(selectedDietDateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('关于即训')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _AboutMenuSection(
            children: [
              _AboutMenuTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: const Color(0xFF0EA5E9),
                title: '隐私政策',
                onTap: () => _openLegalDocument(
                  context,
                  url: LegalConstants.privacyPolicyUrl,
                  documentName: '隐私政策',
                ),
              ),
              _AboutMenuTile(
                icon: Icons.description_outlined,
                iconColor: colors.accent,
                title: '用户协议',
                onTap: () => _openLegalDocument(
                  context,
                  url: LegalConstants.termsOfServiceUrl,
                  documentName: '用户协议',
                ),
              ),
            ],
          ),
          if (authStatus.isSignedIn)
            _AboutMenuSection(
              children: [
                _AboutMenuTile(
                  icon: Icons.delete_forever_outlined,
                  iconColor: const Color(0xFFDC2626),
                  title: '注销账号',
                  subtitle: '永久删除当前账号及关联数据，不可恢复',
                  onTap: () =>
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CancelAccountPage(),
                        ),
                      ),
                ),
              ],
            ),
          if (authStatus.isSignedIn)
            _AboutMenuSection(
              children: [
                _AboutMenuTile(
                  icon: Icons.logout,
                  iconColor: const Color(0xFFEF4444),
                  title: '退出登录',
                  subtitle: '退出当前账号，稍后可重新登录',
                  onTap: () =>
                      _confirmAndSignOut(context, ref, selectedDietDate),
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
                  _AboutMenuSection(
                    children: [
                      _AboutMenuTile(
                        icon: Icons.admin_panel_settings_outlined,
                        iconColor: colors.accent,
                        title: '动作库管理',
                        onTap: () {
                          Navigator.of(
                            context,
                          ).pushNamed(AdminExerciseCatalogPage.routeName);
                        },
                      ),
                      _AboutMenuTile(
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
              error: (_, _) => [
                _AboutMenuSection(
                  children: [
                    _AboutMenuTile(
                      icon: Icons.admin_panel_settings_outlined,
                      iconColor: colors.warning,
                      title: '管理员权限加载失败，点击重试',
                      onTap: () => ref.invalidate(currentUserIsAdminProvider),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AboutMenuSection extends StatelessWidget {
  const _AboutMenuSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: colors.textMuted.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 72),
                  child: Divider(
                    height: 1,
                    thickness: 0.8,
                    color: colors.textMuted.withValues(alpha: 0.10),
                  ),
                ),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}

class _AboutMenuTile extends StatelessWidget {
  const _AboutMenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textMuted.withValues(alpha: 0.80),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textMuted.withValues(alpha: 0.72),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
