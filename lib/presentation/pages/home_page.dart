import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../application/state/session_editor_controller.dart';
import '../../domain/entities/workout_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../widgets/async_tab_content.dart';
import '../widgets/home/home_sections.dart';
import 'session_analysis_page.dart';
import 'session_editor_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _openEditor(
    BuildContext context, {
    required DateTime date,
    required SessionMode mode,
    String? sessionId,
    bool preferActiveSession = false,
    bool readOnly = false,
    bool createOnSaveOnly = false,
  }) async {
    final result = await Navigator.of(context)
        .pushNamed<SessionEditorExitResult>(
          SessionEditorPage.routeName,
          arguments: SessionEditorArgs(
            date: date,
            mode: mode,
            sessionId: sessionId,
            preferActiveSession: preferActiveSession,
            readOnly: readOnly,
            createOnSaveOnly: createOnSaveOnly,
          ),
        );
    if (!context.mounted || result == null) {
      return;
    }
    final message = switch (result) {
      SessionEditorExitResult.savedProgress => '训练进度已保存',
      SessionEditorExitResult.completed => '训练记录已完成',
      SessionEditorExitResult.autosaved => '已自动保存当前内容',
      SessionEditorExitResult.autosaveFailed => '自动保存失败，本次修改未保存',
      SessionEditorExitResult.discarded => null,
    };
    if (message != null) {
      showLatestSnackBar(context, message);
    }
  }

  Future<void> _openSessionAnalysis(
    BuildContext context, {
    required String sessionId,
  }) async {
    await Navigator.of(context).pushNamed<void>(
      SessionAnalysisPage.routeName,
      arguments: SessionAnalysisPageArgs(sessionId: sessionId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(homeSnapshotProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AsyncTabContent<HomeSnapshot>(
          asyncValue: snapshotAsync,
          errorPrefix: '首页加载失败',
          builder: (context, snapshot) {
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 980) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: SingleChildScrollView(
                          child: HomeLeftColumn(
                            snapshot: snapshot,
                            openEditor: _openEditor,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
                          child: HomeRightColumn(
                            snapshot: snapshot,
                            openSessionAnalysis: _openSessionAnalysis,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      HomeLeftColumn(
                        snapshot: snapshot,
                        openEditor: _openEditor,
                      ),
                      HomeRightColumn(
                        snapshot: snapshot,
                        openSessionAnalysis: _openSessionAnalysis,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
