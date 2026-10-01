import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../domain/exploration_overlay_style.dart';

/// Explains the visit-intensity colours used by the active heat-map overlay.
class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key, required this.style});

  final ExplorationOverlayStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final darkTextColor = AppSurfaces.isDark(context)
        ? AppSurfaces.textPrimary(context)
        : null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Heatmap legend',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: darkTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _LegendRow(
                color: style.heatmapColdColor,
                label: '1–2 entries',
                textColor: darkTextColor ?? Colors.black,
              ),
              const SizedBox(height: 6),
              _LegendRow(
                color: style.heatmapWarmColor,
                label: '3–4 entries',
                textColor: darkTextColor ?? Colors.black,
              ),
              const SizedBox(height: 6),
              _LegendRow(
                color: style.heatmapHotColor,
                label: '5+ entries',
                textColor: darkTextColor ?? Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.textColor,
  });

  final Color color;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.14),
              width: 0.8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: textColor),
          ),
        ),
      ],
    );
  }
}
