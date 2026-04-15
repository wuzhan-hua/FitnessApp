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
          title: 'A. 今日状态',
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
          title: 'B. 主操作区',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: () => openEditor(
                  context,
                  date: DateTime.now(),
                  mode: SessionMode.newSession,
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始今日训练'),
              ),
              FilledButton.tonalIcon(
                onPressed: snapshot.inProgressSession == null
                    ? null
                    : () => openEditor(
                        context,
                        date: snapshot.date,
                        mode: SessionMode.continueSession,
                        sessionId: snapshot.inProgressSession?.id,
                      ),
                icon: const Icon(Icons.restart_alt),
                label: Text(
                  snapshot.inProgressSession == null
                      ? '无进行中训练'
                      : '继续上次训练(${snapshot.inProgressSession!.completedSets} 组)',
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'C. 快捷动作',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              QuickActionBadge(
                text: '快速补录(昨日)',
                onTap: () => openEditor(
                  context,
                  date: DateTime.now().subtract(const Duration(days: 1)),
                  mode: SessionMode.backfill,
                ),
              ),
              QuickActionBadge(
                text: '复制最近一次训练',
                onTap: () => openEditor(
                  context,
                  date: DateTime.now(),
                  mode: SessionMode.newSession,
                ),
              ),
              QuickActionBadge(
                text: '新增空白训练',
                onTap: () => openEditor(
                  context,
                  date: DateTime.now(),
                  mode: SessionMode.newSession,
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'D. 今日计划 / 推荐',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: snapshot.quickSuggestions
                .map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Icon(
                            Icons.bolt,
                            size: 14,
                            color: colors.accent,
                          ),
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
                )
                .toList(),
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

class QuickActionBadge extends StatelessWidget {
  const QuickActionBadge({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      borderRadius: AppRadius.chip,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: colors.panelAlt,
          borderRadius: AppRadius.chip,
          border: Border.all(color: colors.textMuted.withValues(alpha: 0.35)),
        ),
        child: Text(
          text,
          maxLines: 1,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
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
          title: 'E. 近7天概览',
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
          title: 'F. 最近2次训练',
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
          title: 'G. 恢复提醒',
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
