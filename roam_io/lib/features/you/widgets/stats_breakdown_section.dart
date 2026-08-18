import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../models/stats_breakdown_item.dart';
import 'stats_section_card.dart';

/// Horizontal bar breakdown for XP sources, categories, or transport modes.
class StatsBreakdownSection extends StatelessWidget {
  const StatsBreakdownSection({
    super.key,
    required this.title,
    required this.items,
    this.emptyMessage = 'Nothing to show yet',
    this.valueSuffix = '',
  });

  final String title;
  final List<StatsBreakdownItem> items;
  final String emptyMessage;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.where((item) => item.value > 0).toList();
    final maxValue = visibleItems.isEmpty
        ? 0
        : visibleItems
              .map((item) => item.value)
              .reduce((a, b) => a > b ? a : b);

    return StatsSectionCard(
      title: title,
      child: visibleItems.isEmpty
          ? Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < visibleItems.length; index++) ...[
                  if (index > 0) const SizedBox(height: 12),
                  _BreakdownRow(
                    label: visibleItems[index].label,
                    value: visibleItems[index].value,
                    maxValue: maxValue,
                    valueSuffix: valueSuffix,
                  ),
                ],
              ],
            ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.valueSuffix,
  });

  final String label;
  final int value;
  final int maxValue;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxValue == 0 ? 0.0 : value / maxValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppSurfaces.textPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$value$valueSuffix',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.sage,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: fraction,
            backgroundColor: AppSurfaces.innerCard(context),
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
