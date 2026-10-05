/*
 * Author: Amarprit Singh
 * Last Updated: 5 October 2026
 * Description:
 *   "This week" on the Profile tab: distance, time and new tiles set straight
 *   on the page rather than in a card, plus the journey streak. Tapping it
 *   opens Statistics, which owns the detailed graphs.
 */

import 'package:flutter/material.dart';

import '../../../../theme/app_surfaces.dart';
import '../../services/profile_feed_builder.dart';
import 'stat_block.dart';

class WeeklySummary extends StatelessWidget {
  const WeeklySummary({
    super.key,
    required this.week,
    required this.streakWeeks,
    this.onTap,
  });

  final WeeklyActivityTotals week;
  final int streakWeeks;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = formatProfileDistance(week.distanceMeters);

    return Semantics(
      button: onTap != null,
      hint: onTap == null ? null : 'Opens Statistics',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'This week',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppSurfaces.textPrimary(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (streakWeeks >= 2) ...[
                    const SizedBox(width: 10),
                    Flexible(child: _StreakChip(weeks: streakWeeks)),
                  ],
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppSurfaces.textMuted(context),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StatBlock(
                      label: 'Distance',
                      value: distance.value,
                      unit: distance.unit,
                      size: StatBlockSize.large,
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      label: 'Time',
                      value: formatProfileDuration(
                        week.durationSeconds,
                        includeSeconds: false,
                      ),
                      size: StatBlockSize.large,
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      label: 'New tiles',
                      value: '${week.newTiles}',
                      size: StatBlockSize.large,
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

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.weeks});

  final int weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 9, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 14, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '$weeks-week streak',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
