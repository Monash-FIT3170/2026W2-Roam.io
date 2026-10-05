/*
 * Author: Amarprit Singh
 * Last Updated: 4 October 2026
 * Description:
 *   Big-number statistic with a small uppercase label above it, the building
 *   block of the Profile tab's weekly summary and journey cards.
 */

import 'package:flutter/material.dart';

import '../../../../theme/app_colours.dart';
import '../../../../theme/app_surfaces.dart';

/// Sage reads well on cream but sinks into the dark surfaces, so dark mode
/// takes the lighter sage token for accented numbers.
Color profileAccentColor(BuildContext context) {
  return AppSurfaces.isDark(context) ? AppColors.lightSage : AppColors.sage;
}

/// Figures that share one width, so stacked or adjacent numbers line up.
const List<FontFeature> kTabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

enum StatBlockSize { regular, large }

/// A label over a value, e.g. DISTANCE / 12.4 km.
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.accent = false,
    this.size = StatBlockSize.regular,
  });

  final String label;
  final String value;

  /// Drawn smaller after [value], e.g. "km".
  final String? unit;

  /// Tints the value with the brand accent, as XP is everywhere else.
  final bool accent;
  final StatBlockSize size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueSize = size == StatBlockSize.large ? 24.0 : 19.0;
    final valueStyle = theme.textTheme.titleLarge?.copyWith(
      color: accent
          ? profileAccentColor(context)
          : AppSurfaces.textPrimary(context),
      fontSize: valueSize,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: -0.3,
      fontFeatures: kTabularFigures,
    );
    final unitText = unit;

    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppSurfaces.textMuted(context),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          // Scales down rather than wrapping or clipping when a long value or a
          // large system text size meets a narrow column.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: value,
                children: [
                  if (unitText != null)
                    TextSpan(
                      text: ' $unitText',
                      style: valueStyle?.copyWith(
                        fontSize: valueSize * 0.62,
                        fontWeight: FontWeight.w600,
                        color: AppSurfaces.textMuted(context),
                        letterSpacing: 0,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              softWrap: false,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}
