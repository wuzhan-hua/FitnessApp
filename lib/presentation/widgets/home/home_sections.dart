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
    });

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
                    _HeroBadge(
                      text: snapshot.inProgressSession == null
                          ? '进行中：0组'
                          : '进行中：${snapshot.inProgressSession!.completedSets}组',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _HeroActionButton(
                  icon: Icons.play_arrow_rounded,
                  label: '开始训练',
                  isPrimary: true,
                  onTap: () => openEditor(
                    context,
                    date: DateTime.now(),
                    mode: SessionMode.newSession,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _HeroActionButton(
                  icon: Icons.restart_alt_rounded,
                  label: snapshot.inProgressSession == null
                      ? '无进行中训练'
                      : '继续上次训练 (${snapshot.inProgressSession!.completedSets} 组)',
                  isPrimary: false,
                  onTap: snapshot.inProgressSession == null
                      ? null
                      : () => openEditor(
                          context,
                          date: snapshot.date,
                          mode: SessionMode.continueSession,
                          sessionId: snapshot.inProgressSession?.id,
                        ),
                ),
              ],
            ),
          ),
        ),
        SectionCard(
          title: '快捷动作',
          child: Row(
            children: [
              Expanded(
                child: _QuickPillAction(
                  icon: Icons.history_rounded,
                  text: '快补昨日',
                  onTap: () => openEditor(
                    context,
                    date: DateTime.now().subtract(const Duration(days: 1)),
                    mode: SessionMode.backfill,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _QuickPillAction(
                  icon: Icons.content_copy_rounded,
                  text: '复制上次',
                  onTap: () => openEditor(
                    context,
                    date: DateTime.now(),
                    mode: SessionMode.newSession,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _QuickPillAction(
                  icon: Icons.add_box_rounded,
                  text: '新建空白',
                  onTap: () => openEditor(
                    context,
                    date: DateTime.now(),
                    mode: SessionMode.newSession,
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: '今日计划 / 推荐',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...snapshot.quickSuggestions.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Icon(Icons.bolt, size: 14, color: colors.accent),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          tip,
                          style: TextStyle(color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
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
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
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
              icon: const Icon(Icons.restart_alt_rounded, size: 20),
              label: Text(label),
            ),
    );
  }
}

class _QuickPillAction extends StatelessWidget {
  const _QuickPillAction({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      borderRadius: AppRadius.chip,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: colors.panelAlt,
          borderRadius: AppRadius.chip,
          border: Border.all(color: colors.accent.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: colors.accent),
            const SizedBox(width: 6),
            Text(
              text,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
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

class HomeRightColumn extends StatelessWidget {
  const HomeRightColumn({super.key, required this.snapshot});

  final HomeSnapshot snapshot;

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
          child: Column(
            children: snapshot.recentSessions
                .map(
                  (session) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(session.title),
                    subtitle: Text(
                      '${DateFormat('MM/dd').format(session.date)} · ${session.completedSets} 组 · ${session.durationMinutes} 分钟',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                )
                .toList(),
          ),
        ),
        SectionCard(
          title: '恢复提醒',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0x1AF59E0B),
                  borderRadius: AppRadius.card,
                ),
                child: Icon(Icons.local_fire_department, color: colors.warning),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(snapshot.recoveryHint)),
            ],
          ),
        ),
      ],
    );
  }
}
