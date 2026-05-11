import 'package:flutter/material.dart';

import '../../domain/entities/diet_models.dart';
import '../../theme/app_theme.dart';

typedef DietCalculationBuilder = DietEntryCalculation Function(double grams);

const _deleteColor = Color(0xFFEF4444);

Future<double?> showDietFoodEntryDialog({
  required BuildContext context,
  required String title,
  required String subtitle,
  required String confirmLabel,
  required DietCalculationBuilder calculationBuilder,
  double initialGrams = 100,
  Future<void> Function()? onDelete,
  String deleteLabel = '删除',
}) async {
  return showDialog<double>(
    context: context,
    builder: (dialogContext) => _DietFoodEntryDialog(
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
      initialGrams: initialGrams,
      calculationBuilder: calculationBuilder,
      onDelete: onDelete,
      deleteLabel: deleteLabel,
    ),
  );
}

class _DietFoodEntryDialog extends StatefulWidget {
  const _DietFoodEntryDialog({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.initialGrams,
    required this.calculationBuilder,
    required this.onDelete,
    required this.deleteLabel,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;
  final double initialGrams;
  final DietCalculationBuilder calculationBuilder;
  final Future<void> Function()? onDelete;
  final String deleteLabel;

  @override
  State<_DietFoodEntryDialog> createState() => _DietFoodEntryDialogState();
}

class _DietFoodEntryDialogState extends State<_DietFoodEntryDialog> {
  late final TextEditingController _gramsController;
  late double _grams;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _grams = widget.initialGrams;
    _gramsController = TextEditingController(
      text: widget.initialGrams == widget.initialGrams.roundToDouble()
          ? widget.initialGrams.toStringAsFixed(0)
          : widget.initialGrams.toString(),
    );
  }

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final calculation = widget.calculationBuilder(_grams);

    return AlertDialog(
      backgroundColor: colors.panel,
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
      title: Row(
        children: [
          Expanded(child: Text(widget.title)),
          if (widget.onDelete != null)
            IconButton(
              tooltip: widget.deleteLabel,
              onPressed: _isDeleting ? null : _deleteFood,
              icon: _isDeleting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _deleteColor,
                      ),
                    )
                  : const Icon(
                      Icons.delete_outline_rounded,
                      color: _deleteColor,
                    ),
            ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _gramsController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '克数',
                suffixText: 'g',
              ),
              onChanged: (value) {
                setState(() {
                  _grams = double.tryParse(value.trim()) ?? 0;
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
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _grams <= 0
              ? null
              : () => Navigator.of(context).pop(_grams),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }

  Future<void> _deleteFood() async {
    final onDelete = widget.onDelete;
    if (onDelete == null) {
      return;
    }
    setState(() {
      _isDeleting = true;
    });
    try {
      await onDelete();
      if (mounted) {
        Navigator.of(context).pop(null);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试。')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }
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
