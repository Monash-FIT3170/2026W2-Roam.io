/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Displays profile XP and level progression for the You profile identity
 *   section and any standalone progress placements.
 */

import 'package:flutter/material.dart';

import '../../profile/domain/profile_model.dart';
import '../../../theme/app_surfaces.dart';

/// Green app-styled XP and level progress section for the You page.
class XpProgressSection extends StatelessWidget {
  const XpProgressSection({
    super.key,
    required this.profile,
    this.compact = false,
  });

  final ProfileModel profile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final level = profile.level;
    final xp = profile.xp;
    final totalXpForLevel = ProfileModel.totalXpToReachLevel(level);
    final currentLevelXp = xp - totalXpForLevel;
    final nextLevelXp = level >= ProfileModel.maxLevel
        ? currentLevelXp
        : ProfileModel.xpForLevel(level);
    final progress = level >= ProfileModel.maxLevel
        ? 1.0
        : (nextLevelXp > 0 ? currentLevelXp / nextLevelXp : 0.0);
    final xpRemaining = level >= ProfileModel.maxLevel
        ? 0
        : nextLevelXp - currentLevelXp;

    if (compact) {
      return SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Level $level',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppSurfaces.textPrimary(context),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              level >= ProfileModel.maxLevel
                  ? 'Maximum level reached'
                  : '$currentLevelXp / $nextLevelXp XP',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level $level',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppSurfaces.textPrimary(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      level >= ProfileModel.maxLevel
                          ? '$xp XP earned'
                          : '$xpRemaining XP to Level ${level + 1}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppSurfaces.textMuted(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 9,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            level >= ProfileModel.maxLevel
                ? 'Maximum level reached'
                : '$currentLevelXp / $nextLevelXp XP',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppSurfaces.textMuted(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
