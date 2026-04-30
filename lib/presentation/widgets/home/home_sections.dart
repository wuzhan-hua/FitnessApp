import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/workout_models.dart';
import '../../../theme/app_theme.dart';
import '../section_card.dart';
import '../stat_tile.dart';

typedef OpenEditorHandler =
    void Function(
      BuildContext context, {
      required DateTime date,
      required SessionMode mode,
      String? sessionId,
      bool preferActiveSession,
      bool readOnly,
      bool createOnSaveOnly,
    });

typedef OpenSessionAnalysisHandler =
    void Function(BuildContext context, {required String sessionId});

class HomeLeftColumn extends StatelessWidget {
  const HomeLeftColumn({
    super.key,
    required this.snapshot,
    required this.openEditor,
  });

  final HomeSnapshot snapshot;
  final OpenEditorHandler openEditor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final formatter = NumberFormat('#,##0');
    final todayText = _formatToday(snapshot.date);
    final hasInProgress = snapshot.inProgressSession != null;
    final hasCompletedToday =
        snapshot.todaySession?.status == SessionStatus.completed;
    final hasTodaySession = snapshot.todaySession != null;
    final inProgressSetCount = snapshot.inProgressSession?.totalSets ?? 0;

    return Column(
      children: [
        SectionCard(
          title: '今日状态',
          trailing: StatusBadge(
            text: snapshot.todaySummary.hasTraining ? '有训练' : '未训练',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(todayText, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.5,
                children: [
                  StatTile(
                    label: '组数',
                    value: '${snapshot.todaySummary.totalSets}',
                  ),
                  StatTile(
                    label: '训练量',
                    value: formatter.format(snapshot.todaySummary.totalVolume),
                  ),
                  StatTile(
                    label: '时长',
                    value: '${snapshot.todaySummary.durationMinutes} 分钟',
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: '主操作区',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.panelAlt,
                  Color.lerp(colors.panelAlt, colors.accent, 0.08)!,
                ],
              ),
              borderRadius: const BorderRadius.all(Radius.circular(22)),
              border: Border.all(
                color: colors.accent.withValues(alpha: 0.22),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今天要做什么',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '开练入口就在这里，保持强度，保持节奏。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _HeroBadge(
                      text: snapshot.todaySummary.hasTraining
                          ? '今日：已训练'
                          : '今日：待开始',
                    ),
                    if (hasInProgress)
                      _HeroBadge(
                        text: inProgressSetCount > 0
                            ? '进行中：$inProgressSetCount组'
                            : '进行中：待添加',
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (hasInProgress)
                  _HeroActionButton(
                    icon: Icons.restart_alt_rounded,
                    label: inProgressSetCount > 0
                        ? '继续训练 ($inProgressSetCount 组)'
                        : '继续训练（待添加）',
                    isPrimary: true,
                    onTap: () => openEditor(
                      context,
                      date: snapshot.inProgressSession!.date,
                      mode: SessionMode.continueSession,
                      sessionId: snapshot.inProgressSession!.id,
                      preferActiveSession: false,
                      readOnly: false,
                      createOnSaveOnly: false,
                    ),
                  )
                else if (hasCompletedToday && hasTodaySession)
                  Column(
                    children: [
                      _HeroActionButton(
                        icon: Icons.playlist_add_rounded,
                        label: '补充今日训练',
                        isPrimary: true,
                        onTap: () => _confirmAppendTodaySession(
                          context,
                          session: snapshot.todaySession!,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _HeroActionButton(
                        icon: Icons.visibility_outlined,
                        label: '查看今日训练',
                        isPrimary: false,
                        onTap: () => openEditor(
                          context,
                          date: snapshot.todaySession!.date,
                          mode: SessionMode.backfill,
                          sessionId: snapshot.todaySession!.id,
                          preferActiveSession: false,
                          readOnly: true,
                          createOnSaveOnly: false,
                        ),
                      ),
                    ],
                  )
                else
                  _HeroActionButton(
                    icon: Icons.play_arrow_rounded,
                    label: '开始训练',
                    isPrimary: true,
                    onTap: () => openEditor(
                      context,
                      date: DateTime.now(),
                      mode: SessionMode.newSession,
                      preferActiveSession: true,
                      readOnly: false,
                      createOnSaveOnly: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
        SectionCard(
          title: '今日计划 / 推荐',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...snapshot.recommendations.asMap().entries.map(
                (entry) => _RecommendationTipCard(
                  recommendation: entry.value,
                  isPrimary: entry.key == 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatToday(DateTime date) {
    try {
      return DateFormat('MM月dd日 EEEE', 'zh_CN').format(date);
    } catch (_) {
      return DateFormat('MM月dd日 EEEE').format(date);
    }
  }

  Future<void> _confirmAppendTodaySession(
    BuildContext context, {
    required WorkoutSession session,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('补充今日训练'),
        content: const Text('今天已有训练记录，是否继续在今日训练中补充动作或组数？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认补充'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    openEditor(
      context,
      date: session.date,
      mode: SessionMode.backfill,
      sessionId: session.id,
      preferActiveSession: false,
      readOnly: false,
      createOnSaveOnly: false,
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: colors.panelAlt,
        borderRadius: AppRadius.chip,
        border: Border.all(color: colors.textMuted.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.visible,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: colors.textPrimary,
        ),
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: isPrimary
          ? FilledButton.icon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
                textStyle: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              icon: Icon(icon, size: 20),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
                side: BorderSide(color: colors.accent.withValues(alpha: 0.35)),
                foregroundColor: colors.textPrimary,
                textStyle: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              icon: Icon(icon, size: 20),
              label: Text(label),
            ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.72),
        borderRadius: AppRadius.chip,
        border: Border.all(color: colors.accent.withValues(alpha: 0.24)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RecommendationVisualSpec {
  const _RecommendationVisualSpec({
    required this.label,
    required this.icon,
    required this.tintColor,
  });

  final String label;
  final IconData icon;
  final Color tintColor;
}

_RecommendationVisualSpec _recommendationSpec(
  BuildContext context,
  HomeRecommendationType type,
) {
  final colors = AppColors.of(context);
  return switch (type) {
    HomeRecommendationType.recovery => _RecommendationVisualSpec(
      label: '恢复建议',
      icon: Icons.waves_rounded,
      tintColor: Color.lerp(colors.accent, colors.success, 0.35)!,
    ),
    HomeRecommendationType.trainingFocus => _RecommendationVisualSpec(
      label: '训练安排',
      icon: Icons.track_changes_rounded,
      tintColor: colors.accent,
    ),
    HomeRecommendationType.continueSession => _RecommendationVisualSpec(
      label: '继续训练',
      icon: Icons.play_circle_outline_rounded,
      tintColor: Color.lerp(colors.accent, colors.textPrimary, 0.18)!,
    ),
    HomeRecommendationType.review => _RecommendationVisualSpec(
      label: '训练复盘',
      icon: Icons.rate_review_outlined,
      tintColor: Color.lerp(colors.accent, colors.warning, 0.28)!,
    ),
  };
}

class _RecommendationTipCard extends StatelessWidget {
  const _RecommendationTipCard({
    required this.recommendation,
    required this.isPrimary,
  });

  final HomeRecommendationItem recommendation;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final spec = _recommendationSpec(context, recommendation.type);

    return Container(
      margin: EdgeInsets.only(
        bottom: isPrimary ? AppSpacing.sm : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isPrimary ? colors.panel : colors.panel.withValues(alpha: 0.94),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(
          color: isPrimary
              ? colors.textMuted.withValues(alpha: 0.10)
              : colors.textMuted.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: colors.textPrimary.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: isPrimary ? 5 : 4,
              decoration: BoxDecoration(
                color: spec.tintColor.withValues(
                  alpha: isPrimary ? 0.82 : 0.68,
                ),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  isPrimary ? 14 : 12,
                  14,
                  isPrimary ? 14 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(spec.icon, size: 14, color: spec.tintColor),
                        const SizedBox(width: 6),
                        Text(
                          spec.label,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: spec.tintColor,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      recommendation.title,
                      style:
                          (isPrimary
                                  ? Theme.of(context).textTheme.titleMedium
                                  : Theme.of(context).textTheme.titleSmall)
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                                height: 1.18,
                              ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recommendation.message,
                      style:
                          (isPrimary
                                  ? Theme.of(context).textTheme.bodyMedium
                                  : Theme.of(context).textTheme.bodySmall)
                              ?.copyWith(
                                color: colors.textMuted,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                      maxLines: isPrimary ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeRightColumn extends StatelessWidget {
  const HomeRightColumn({
    super.key,
    required this.snapshot,
    required this.openSessionAnalysis,
  });

  final HomeSnapshot snapshot;
  final OpenSessionAnalysisHandler openSessionAnalysis;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final formatter = NumberFormat('#,##0');
    return Column(
      children: [
        SectionCard(
          title: '近7天概览',
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.9,
            children: [
              StatTile(label: '训练天数', value: '${snapshot.weekTrainingDays}'),
              StatTile(label: '总组数', value: '${snapshot.weekTotalSets}'),
              StatTile(
                label: '总训练量',
                value: formatter.format(snapshot.weekTotalVolume),
              ),
              StatTile(
                label: '平均时长',
                value: '${snapshot.weekAverageDuration} 分钟',
              ),
            ],
          ),
        ),
        SectionCard(
          title: '最近2次训练',
          child: snapshot.recentSessions.isEmpty
              ? const Text('最近还没有训练记录')
              : Column(
                  children: snapshot.recentSessions
                      .map(
                        (session) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => openSessionAnalysis(
                            context,
                            sessionId: session.id,
                          ),
                          title: Text(session.title),
                          subtitle: Text(
                            '${DateFormat('MM/dd').format(session.date)} · ${session.totalSets} 组 · ${session.durationMinutes} 分钟',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      )
                      .toList(),
                ),
        ),
        SectionCard(
          title: '恢复提醒',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0x1AF59E0B),
                      borderRadius: AppRadius.card,
                    ),
                    child: Icon(
                      Icons.local_fire_department,
                      color: colors.warning,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '恢复节奏提醒',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          snapshot.recoveryHint,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.textMuted, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
