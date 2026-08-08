/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Reusable profile identity header for the current user and public social
 *   profile views. Following/Followers stats are independently tappable when
 *   callbacks are provided.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../domain/profile_model.dart';
import '../domain/profile_stats.dart';

/// Displays public identity and optional level/XP information.
class ProfileIdentityHeader extends StatelessWidget {
  const ProfileIdentityHeader({
    super.key,
    required this.displayName,
    required this.username,
    this.photoUrl,
    this.level,
    this.xp,
    this.tileCount,
    this.stats,
    this.action,
  });

  final String displayName;
  final String username;
  final String? photoUrl;
  final int? level;
  final int? xp;
  final int? tileCount;
  final List<ProfileStatItem>? stats;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasProgress = level != null && xp != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppSurfaces.softCard(context),
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.primary, width: 2),
              ),
              child: ClipOval(
                child: photoUrl != null && photoUrl!.isNotEmpty
                    ? Image.network(
                        photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.person_rounded,
                          color: colorScheme.primary,
                        ),
                      )
                    : Icon(Icons.person_rounded, color: colorScheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppSurfaces.textPrimary(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppSurfaces.textMuted(context),
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  if (hasProgress) ...[
                    const SizedBox(height: 4),
                    _CompactPublicXp(level: level!, xp: xp!),
                  ],
                ],
              ),
            ),
          ],
        ),
        if ((stats != null && stats!.isNotEmpty) || tileCount != null) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final stat
                  in stats ??
                      [
                        ProfileStatItem(
                          label: 'Tiles',
                          value: _formatNumber(tileCount!),
                        ),
                      ])
                _ProfileStat(
                  label: stat.label,
                  value: stat.value,
                  onTap: stat.onTap,
                ),
            ],
          ),
        ],
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    );
  }
}

class _CompactPublicXp extends StatelessWidget {
  const _CompactPublicXp({required this.level, required this.xp});

  final int level;
  final int xp;

  @override
  Widget build(BuildContext context) {
    final totalXpForLevel = ProfileModel.totalXpToReachLevel(level);
    final currentLevelXp = xp - totalXpForLevel;
    final nextLevelXp = level >= ProfileModel.maxLevel
        ? currentLevelXp
        : ProfileModel.xpForLevel(level);
    final progress = level >= ProfileModel.maxLevel
        ? 1.0
        : (nextLevelXp > 0 ? currentLevelXp / nextLevelXp : 0.0);
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Level $level',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppSurfaces.textPrimary(context),
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.14,
              ),
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            level >= ProfileModel.maxLevel
                ? 'Maximum level reached'
                : '$currentLevelXp / $nextLevelXp XP',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppSurfaces.textMuted(context),
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppSurfaces.textMuted(context),
              fontWeight: FontWeight.w600,
              fontSize: 9,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppSurfaces.textPrimary(context),
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
      ],
    );

    return Expanded(
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: content,
              ),
            ),
    );
  }
}

String _formatNumber(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  }
  return value.toString();
}
