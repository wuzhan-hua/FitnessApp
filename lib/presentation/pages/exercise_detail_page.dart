import 'package:flutter/material.dart';

import '../../data/services/exercise_catalog_service.dart';
import '../../domain/entities/workout_models.dart';
import '../../theme/app_theme.dart';

class ExerciseDetailPageArgs {
  const ExerciseDetailPageArgs({required this.item});

  final ExerciseCatalogItem item;
}

class ExerciseDetailPage extends StatefulWidget {
  const ExerciseDetailPage({super.key, required this.args});

  static const routeName = '/exercise-detail';

  final ExerciseDetailPageArgs args;

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final item = widget.args.item;
    final name = item.nameZh?.trim().isNotEmpty == true ? item.nameZh! : item.nameEn;
    final equipment = item.equipmentZh?.trim().isNotEmpty == true
        ? item.equipmentZh!
        : (item.equipmentEn?.trim().isNotEmpty == true
              ? item.equipmentEn!
              : ExerciseCatalogService.unlabeledEquipment);
    final muscles = item.primaryMusclesZh.isNotEmpty
        ? item.primaryMusclesZh
        : item.primaryMusclesEn;
    final instructions = item.instructionsZh.isNotEmpty
        ? item.instructionsZh
        : item.instructionsEn;
    final imageUrls = item.imageUrls.isNotEmpty
        ? item.imageUrls
        : (item.coverImageUrl?.isNotEmpty == true
              ? <String>[item.coverImageUrl!]
              : const <String>[]);

    return Scaffold(
      appBar: AppBar(title: const Text('动作介绍')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _ImageGallery(
            imageUrls: imageUrls,
            currentPage: _currentPage,
            controller: _pageController,
            onPageChanged: (value) {
              if (!mounted) {
                return;
              }
              setState(() {
                _currentPage = value;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _MetaChip(label: equipment),
              if (muscles.isNotEmpty) _MetaChip(label: muscles.join(' / ')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.panelAlt,
              borderRadius: AppRadius.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '动作步骤',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (instructions.isEmpty)
                  Text(
                    '暂无动作介绍',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  )
                else
                  ...List.generate(
                    instructions.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${index + 1}.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              instructions[index],
                              style: Theme.of(context).textTheme.bodyMedium,
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
      ),
    );
  }
}

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({
    required this.imageUrls,
    required this.currentPage,
    required this.controller,
    required this.onPageChanged,
  });

  final List<String> imageUrls;
  final int currentPage;
  final PageController controller;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.panelAlt,
        borderRadius: AppRadius.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imageUrls.isEmpty
                  ? Container(
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 36,
                        color: colors.textMuted,
                      ),
                    )
                  : PageView.builder(
                      controller: controller,
                      itemCount: imageUrls.length,
                      onPageChanged: onPageChanged,
                      itemBuilder: (context, index) {
                        return Container(
                          color: Colors.white,
                          child: Image.network(
                            imageUrls[index],
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.image_not_supported_outlined,
                              size: 36,
                              color: colors.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          if (imageUrls.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                imageUrls.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: currentPage == index
                        ? colors.accent
                        : colors.textMuted.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.panelAlt,
        borderRadius: AppRadius.chip,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
