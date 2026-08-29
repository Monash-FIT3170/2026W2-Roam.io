/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 29 August 2026 — Sanjevan Rajasegar
 * Description:
 *   Shared horizontally scrolling profile-style metric pill selector.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';

/// Shared horizontally scrolling pill selector used by profile statistics UI.
class ProfileMetricPillSelector extends StatelessWidget {
  const ProfileMetricPillSelector({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.keyPrefix = 'profile-metric',
    this.itemKeys,
  }) : assert(itemKeys == null || itemKeys.length == labels.length);

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String keyPrefix;
  final List<String>? itemKeys;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppSurfaces.border(context),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < labels.length; index += 1)
                    Padding(
                      padding: EdgeInsets.only(
                        right: index == labels.length - 1 ? 0 : 8,
                      ),
                      child: _MetricPill(
                        key: ValueKey<String>(
                          itemKeys?[index] ?? '$keyPrefix-$index',
                        ),
                        label: labels[index],
                        selected: selectedIndex == index,
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;

    return Material(
      color: selected
          ? selectedColor
          : AppSurfaces.softCard(context),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? selectedColor
                  : AppSurfaces.border(context),
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : AppSurfaces.textMuted(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}