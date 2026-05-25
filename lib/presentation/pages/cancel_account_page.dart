import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../application/state/auth_status.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';

class CancelAccountPage extends ConsumerStatefulWidget {
  const CancelAccountPage({super.key});

  static const confirmationPhrase = '我已知晓注销后不可恢复';

  @override
  ConsumerState<CancelAccountPage> createState() => _CancelAccountPageState();
}

class _CancelAccountPageState extends ConsumerState<CancelAccountPage> {
  final TextEditingController _phraseController = TextEditingController();
  bool _isSubmitting = false;

  bool get _isPhraseMatched =>
      _phraseController.text.trim() == CancelAccountPage.confirmationPhrase;

  void _showFeedback(String message) {
    showLatestSnackBar(context, message);
  }

  Future<void> _submitCancelAccount() async {
    final authStatus =
        ref.read(authStatusProvider).valueOrNull ?? AuthStatus.signedOut;
    if (!authStatus.isSignedIn) {
      _showFeedback('请先登录后再操作');
      return;
    }
    if (!_isPhraseMatched) {
      _showFeedback('请输入完整确认语后再继续');
      return;
    }

    final selectedDietDate = ref.read(selectedDietDateProvider);

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authServiceProvider).deleteCurrentAccount();
      ref.invalidate(guestSoftSignedOutProvider);
      ref.invalidate(authSessionProvider);
      ref.invalidate(authStatusProvider);
      invalidateAuthScopedProvidersOnSignOut(ref, dietDate: selectedDietDate);
      if (!mounted) return;
      _showFeedback('账号已注销');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      final appError = AppError.from(error, fallbackMessage: '注销账号失败，请稍后重试。');
      _showFeedback(appError.message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('注销账号')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '温馨说明',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '根据相关规范要求，账号体系内的 App 需要提供账号注销能力。即训已为你提供账号注销功能。',
                    style: textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '注销后将永久删除当前账号及其训练记录、饮食记录、头像资料等关联数据，且无法恢复。',
                    style: textTheme.bodyLarge?.copyWith(
                      height: 1.7,
                      color: const Color(0xFFDC2626),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '如果你确认需要继续，请在下方输入框完整输入确认语：',
                    style: textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SelectableText(
                    CancelAccountPage.confirmationPhrase,
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _phraseController,
                    enabled: !_isSubmitting,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: '点击输入确认语句...',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          _isSubmitting || !_isPhraseMatched
                              ? null
                              : _submitCancelAccount,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: colors.panelAlt,
                        disabledForegroundColor: colors.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('点击注销账号'),
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
