import 'package:flutter/material.dart';

import '../../../shared/widgets/liquid_glass.dart';
import '../../../theme/app_accessibility.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../domain/hazard_category.dart';
import 'hazard_category_icon.dart';

class HazardCategorySheet extends StatelessWidget {
  const HazardCategorySheet({super.key});

  static Future<HazardCategory?> show(BuildContext context) {
    return showModalBottomSheet<HazardCategory>(
      context: context,
      sheetAnimationStyle: context.reduceMotion
          ? AnimationStyle.noAnimation
          : null,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => const HazardCategorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LiquidGlassSheet(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppSurfaces.textSubtle(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Report a hazard',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: [
                  for (final category in HazardCategory.values)
                    LiquidGlass(
                      tint: null,
                      borderRadius: BorderRadius.circular(16),
                      opacity: AppSurfaces.isDark(context) ? 0.12 : 0.45,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: ValueKey('hazard_category_${category.id}'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(context, category),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                HazardCategoryIcon(
                                  category: category,
                                  color: AppColors.sage,
                                  size: 29,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    category.displayLabel,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
