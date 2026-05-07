import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/providers.dart';
import '../../domain/entities/diet_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_time.dart';
import '../widgets/async_tab_content.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_tile.dart';
import 'food_library_page.dart';

class DietPage extends ConsumerWidget {
  const DietPage({super.key});

  Future<DateTime?> _pickDate(BuildContext context, DateTime initialDate) {
    return showDatePicker(
      context: context,
      locale: const Locale('zh', 'CN'),
      initialDate: initialDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDietDateProvider);
    final summaryAsync = ref.watch(dailyDietSummaryProvider(selectedDate));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            SectionCard(
              title: '饮食记录',
              trailing: FilledButton.tonalIcon(
                onPressed: () async {
                  final selected = await _pickDate(context, selectedDate);
                  if (selected == null) {
                    return;
                  }
                  ref.read(selectedDietDateProvider.notifier).state = DateTime(
                    selected.year,
                    selected.month,
                    selected.day,
                  );
                },
                icon: const Icon(Icons.calendar_month),
                label: Text(DateFormat('M月d日').format(selectedDate)),
              ),
              child: FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(context).pushNamed<void>(
                    FoodLibraryPage.routeName,
                    arguments: FoodLibraryPageArgs(date: selectedDate),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('添加饮食记录'),
              ),
            ),
            Expanded(
              child: AsyncTabContent<DailyDietSummary>(
                asyncValue: summaryAsync,
                errorPrefix: '饮食数据加载失败',
                builder: (context, summary) {
                  return ListView(
                    children: [
                      SectionCard(
                        title: '当日汇总',
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.sm,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.8,
                          children: [
                            StatTile(
                              label: '总热量',
                              value:
                                  '${summary.totalEnergyKCal.toStringAsFixed(0)} kcal',
                            ),
                            StatTile(
                              label: '蛋白质',
                              value:
                                  '${summary.totalProtein.toStringAsFixed(1)} g',
                            ),
                            StatTile(
                              label: '脂肪',
                              value: '${summary.totalFat.toStringAsFixed(1)} g',
                            ),
                            StatTile(
                              label: '碳水',
                              value:
                                  '${summary.totalCarb.toStringAsFixed(1)} g',
                            ),
                          ],
                        ),
                      ),
                      if (summary.recordCount == 0)
                        const SectionCard(
                          title: '当日记录',
                          child: Text('这一天还没有饮食记录，点击上方按钮开始添加。'),
                        )
                      else
                        for (final mealType in MealType.values)
                          SectionCard(
                            title: mealType.label,
                            child: _MealRecordList(
                              records: summary.mealGroups[mealType] ?? const [],
                            ),
                          ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealRecordList extends StatelessWidget {
  const _MealRecordList({required this.records});

  final List<DietRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Text(
        '暂无记录',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.of(context).textMuted),
      );
    }
    return Column(
      children: [
        for (final record in records)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.of(context).panelAlt,
                borderRadius: AppRadius.card,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.foodName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${record.grams.toStringAsFixed(0)}g · ${record.foodCategory}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.of(context).textMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${record.energyKCal.toStringAsFixed(0)} kcal',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppTime.formatUtcDateTimeToBeijing(record.consumedAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.of(context).textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
