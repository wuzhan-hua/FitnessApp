import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/providers.dart';
import '../../domain/entities/workout_models.dart';
import '../../theme/app_theme.dart';
import '../widgets/async_tab_content.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_tile.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsSnapshotProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AsyncTabContent<AnalyticsSnapshot>(
          asyncValue: analyticsAsync,
          errorPrefix: '统计加载失败',
          builder: (context, snapshot) => ListView(
            children: [
              SectionCard(
                title: '训练频率',
                child: StatTile(
                  label: '近30天训练天数',
                  value: '${snapshot.trainingFrequency}',
                  hint: '与日历补录同步',
                ),
              ),
              SectionCard(
                title: '周训练量',
                child: SizedBox(
                  height: 180,
                  child: _VolumeBarChart(points: snapshot.weeklyVolume),
                ),
              ),
              SectionCard(
                title: '近4周训练量',
                child: SizedBox(
                  height: 180,
                  child: _VolumeBarChart(points: snapshot.monthlyVolume),
                ),
              ),
              SectionCard(
                title: 'PR 趋势',
                child: SizedBox(
                  height: 200,
                  child: _PrLineChart(points: snapshot.prTrend),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VolumeBarChart extends StatelessWidget {
  const _VolumeBarChart({required this.points});

  final List<TimeSeriesPoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    points[value.toInt()].label,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].value,
                  color: colors.accent,
                  width: 16,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PrLineChart extends StatelessWidget {
  const _PrLineChart({required this.points});

  final List<TimeSeriesPoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (points.isEmpty) {
      return const Center(child: Text('暂无 PR 数据'));
    }

    final maxY = points
        .map((point) => point.value)
        .reduce((a, b) => a > b ? a : b);
    final minY = points
        .map((point) => point.value)
        .reduce((a, b) => a < b ? a : b);

    return LineChart(
      LineChartData(
        minY: (minY * 0.95).floorToDouble(),
        maxY: (maxY * 1.08).ceilToDouble(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          horizontalInterval: ((maxY - minY) / 3).clamp(1, double.infinity),
          getDrawingHorizontalLine: (_) =>
              FlLine(color: colors.panelAlt, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) => Text(
                NumberFormat('#').format(value),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= points.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  points[value.toInt()].label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].value),
            ],
            isCurved: true,
            color: colors.success,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(radius: 3, color: colors.success),
            ),
          ),
        ],
      ),
    );
  }
}
