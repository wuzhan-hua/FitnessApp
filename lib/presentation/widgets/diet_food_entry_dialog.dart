import 'package:flutter/material.dart';

import '../../domain/entities/diet_models.dart';
import '../../theme/app_theme.dart';

typedef DietCalculationBuilder = DietEntryCalculation Function(double grams);

Future<double?> showDietFoodEntryDialog({
  required BuildContext context,
  required String title,
  required String subtitle,
  required String confirmLabel,
  required DietCalculationBuilder calculationBuilder,
  double initialGrams = 100,
}) async {
  final colors = AppColors.of(context);
  final gramsController = TextEditingController(
    text: initialGrams == initialGrams.roundToDouble()
        ? initialGrams.toStringAsFixed(0)
        : initialGrams.toString(),
  );
  double grams = initialGrams;
  double? confirmedGrams;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final calculation = calculationBuilder(grams);
          return AlertDialog(
            backgroundColor: colors.panel,
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: gramsController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '克数',
                      suffixText: 'g',
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        grams = double.tryParse(value.trim()) ?? 0;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _NutrientPreviewRow(
                    label: '热量',
                    value: '${calculation.energyKCal.toStringAsFixed(0)} kcal',
                  ),
                  _NutrientPreviewRow(
                    label: '碳水',
                    value: '${calculation.carb.toStringAsFixed(1)} g',
                    dotColor: colors.success,
                  ),
                  _NutrientPreviewRow(
                    label: '蛋白质',
                    value: '${calculation.protein.toStringAsFixed(1)} g',
                    dotColor: const Color(0xFFEF4444),
                  ),
                  _NutrientPreviewRow(
                    label: '脂肪',
                    value: '${calculation.fat.toStringAsFixed(1)} g',
                    dotColor: colors.warning,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: grams <= 0
                    ? null
                    : () {
                        confirmedGrams = grams;
                        Navigator.of(dialogContext).pop();
                      },
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );

  gramsController.dispose();
  return confirmedGrams;
}

class _NutrientPreviewRow extends StatelessWidget {
  const _NutrientPreviewRow({
    required this.label,
    required this.value,
    this.dotColor,
  });

  final String label;
  final String value;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
