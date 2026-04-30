import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/providers.dart';
import '../../application/state/session_editor_controller.dart';
import '../../domain/entities/workout_models.dart';
import '../../theme/app_theme.dart';
import '../widgets/async_tab_content.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_tile.dart';
import 'session_editor_page.dart';

class SessionAnalysisPageArgs {
  const SessionAnalysisPageArgs({required this.sessionId});

  final String sessionId;
}

class SessionAnalysisPage extends ConsumerWidget {
  const SessionAnalysisPage({super.key, required this.args});

  static const routeName = '/session-analysis';

  final SessionAnalysisPageArgs args;

  Future<void> _openReadOnlySession(
    BuildContext context,
    WorkoutSession session,
  ) async {
    await Navigator.of(context).pushNamed<void>(
      SessionEditorPage.routeName,
      arguments: SessionEditorArgs(
        date: session.date,
        mode: SessionMode.backfill,
        sessionId: session.id,
        preferActiveSession: false,
        readOnly: true,
        createOnSaveOnly: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(workoutSessionByIdProvider(args.sessionId));

    return Scaffold(
      appBar: AppBar(title: const Text('训练分析')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AsyncTabContent<WorkoutSession?>(
            asyncValue: sessionAsync,
            errorPrefix: '训练分析加载失败',
            builder: (context, session) {
              if (session == null) {
                return const Center(child: Text('未找到这条训练记录'));
              }

              final formatter = NumberFormat('#,##0');
              final dateLabel = DateFormat('yyyy年MM月dd日').format(session.date);

              return ListView(
                children: [
                  SectionCard(
                    title: '本次训练',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '$dateLabel · ${_statusLabel(session.status)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.of(context).textMuted,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 1.8,
                          children: [
                            StatTile(
                              label: '总组数',
                              value: '${session.totalSets}',
                            ),
                            StatTile(
                              label: '总训练量',
                              value: formatter.format(session.totalVolume),
                            ),
                            StatTile(
                              label: '时长',
                              value: '${session.durationMinutes} 分钟',
                            ),
                            StatTile(
                              label: '动作数',
                              value: '${session.exercises.length}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SectionCard(
                    title: '动作拆分',
                    trailing: Text(
                      '${session.exercises.length} 个动作',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.of(context).textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: session.exercises.isEmpty
                        ? const Text('本次训练还没有动作数据')
                        : Column(
                            children: session.exercises
                                .map(
                                  (exercise) => _ExerciseSummaryTile(
                                    exercise: exercise,
                                    formatter: formatter,
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  SectionCard(
                    title: '查看记录',
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openReadOnlySession(context, session),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('查看训练详情'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _statusLabel(SessionStatus status) {
    switch (status) {
      case SessionStatus.draft:
        return '草稿';
      case SessionStatus.inProgress:
        return '进行中';
      case SessionStatus.completed:
        return '已完成';
    }
  }
}

class _ExerciseSummaryTile extends StatelessWidget {
  const _ExerciseSummaryTile({required this.exercise, required this.formatter});

  final SessionExercise exercise;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.panelAlt,
        borderRadius: AppRadius.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.exerciseName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${exercise.sets.length} 组 · 训练量 ${formatter.format(exercise.totalVolume)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            '${exercise.targetSets} 目标组',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
