import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class SetRow extends StatelessWidget {
  const SetRow({
    super.key,
    required this.setLabel,
    required this.weight,
    required this.reps,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onWeightValueTap,
    this.onDelete,
  });

  final String setLabel;
  final double weight;
  final int reps;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;
  final VoidCallback onWeightValueTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 430;
        final columnGap = isCompact ? 6.0 : AppSpacing.sm;
        final valueMinWidth = isCompact ? 34.0 : 46.0;

        Widget buildMetricRow(List<Widget> items) {
          return Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: items[i]),
                if (i != items.length - 1) SizedBox(width: columnGap),
              ],
            ],
          );
        }

        final weightStepper = NumericStepper(
          label: '重量',
          value: weight,
          step: 2.5,
          fractionDigits: 1,
          valueMinWidth: valueMinWidth,
          onValueTap: onWeightValueTap,
          onChanged: onWeightChanged,
        );
        final repsStepper = NumericStepper(
          label: '次数',
          value: reps.toDouble(),
          step: 1,
          fractionDigits: 0,
          valueMinWidth: valueMinWidth,
          onChanged: (value) => onRepsChanged(value.round()),
        );
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.panelAlt,
            borderRadius: AppRadius.card,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text(setLabel)),
                  if (onDelete != null)
                    TextButton(
                      onPressed: onDelete,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('删除本组'),
                    ),
                ],
              ),
              buildMetricRow([weightStepper, repsStepper]),
            ],
          ),
        );
      },
    );
  }
}

class CardioSetRow extends StatelessWidget {
  const CardioSetRow({
    super.key,
    required this.setLabel,
    required this.durationMinutes,
    required this.distanceKm,
    required this.onDurationChanged,
    required this.onDistanceChanged,
    this.onDurationValueTap,
    this.onDistanceValueTap,
    this.onDelete,
  });

  final String setLabel;
  final int durationMinutes;
  final double? distanceKm;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<double?> onDistanceChanged;
  final VoidCallback? onDurationValueTap;
  final VoidCallback? onDistanceValueTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final distanceValue = distanceKm ?? 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 430;
        final columnGap = isCompact ? 6.0 : AppSpacing.sm;
        final valueMinWidth = isCompact ? 34.0 : 46.0;
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.panelAlt,
            borderRadius: AppRadius.card,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text(setLabel)),
                  if (onDelete != null)
                    TextButton(
                      onPressed: onDelete,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('删除本组'),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: NumericStepper(
                      label: '时长(分钟)',
                      value: durationMinutes.toDouble(),
                      step: 1,
                      fractionDigits: 0,
                      valueMinWidth: valueMinWidth,
                      onValueTap: onDurationValueTap,
                      onChanged: (value) => onDurationChanged(value.round()),
                    ),
                  ),
                  SizedBox(width: columnGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NumericStepper(
                          label: '距离(公里)',
                          value: distanceValue,
                          step: 0.5,
                          fractionDigits: 1,
                          valueMinWidth: valueMinWidth,
                          onValueTap: onDistanceValueTap,
                          onChanged: (value) => onDistanceChanged(value),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class NumericStepper extends StatelessWidget {
  const NumericStepper({
    super.key,
    required this.label,
    required this.value,
    required this.step,
    required this.onChanged,
    required this.fractionDigits,
    required this.valueMinWidth,
    this.onValueTap,
  });

  final String label;
  final double value;
  final double step;
  final int fractionDigits;
  final double valueMinWidth;
  final ValueChanged<double> onChanged;
  final VoidCallback? onValueTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                onPressed: () =>
                    onChanged((value - step).clamp(0, 9999).toDouble()),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: valueMinWidth),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onValueTap,
                child: Text(
                  value.toStringAsFixed(fractionDigits),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                onPressed: () =>
                    onChanged((value + step).clamp(0, 9999).toDouble()),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ModePill extends StatelessWidget {
  const ModePill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 30, minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.panelAlt.withValues(alpha: 0.48),
        borderRadius: AppRadius.chip,
        border: Border.all(color: colors.textMuted.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
          height: 1.2,
          color: colors.textPrimary.withValues(alpha: 0.64),
        ),
      ),
    );
  }
}

class RestTimerBar extends StatelessWidget {
  const RestTimerBar({
    super.key,
    required this.seconds,
    required this.running,
    required this.onToggle,
    required this.onReset,
    required this.onAdd30,
    required this.onSub30,
  });

  final int seconds;
  final bool running;
  final VoidCallback onToggle;
  final VoidCallback onReset;
  final VoidCallback onAdd30;
  final VoidCallback onSub30;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(top: BorderSide(color: colors.panelAlt)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            Text(
              '休息 $min:$sec',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: onSub30,
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: '-30 秒',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            ),
            IconButton(
              onPressed: onAdd30,
              icon: const Icon(Icons.add_circle_outline),
              tooltip: '+30 秒',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            ),
            IconButton(
              onPressed: onReset,
              icon: const Icon(Icons.refresh),
              tooltip: '重置',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            ),
            FilledButton.tonalIcon(
              onPressed: onToggle,
              icon: Icon(running ? Icons.pause : Icons.play_arrow),
              label: Text(running ? '暂停' : '开始计时'),
            ),
          ],
        ),
      ),
    );
  }
}
