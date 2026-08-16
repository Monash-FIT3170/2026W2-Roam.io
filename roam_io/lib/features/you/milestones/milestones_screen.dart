/*
 * Author: Alvin Liong
 * Last Modified: 16/08/2026
 * Description:
 *   Milestones tab listing all exploration milestone tracks and earned badges.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import 'milestone_badge_image.dart';
import 'milestone_card.dart';
import 'milestone_catalog.dart';
import 'milestone_progress.dart';
import 'milestones_provider.dart';

/// You-tab surface for milestone progress and tier claims.
class MilestonesScreen extends StatelessWidget {
  const MilestonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomClearance =
        AppBottomNavBar.clearanceFromScreenBottom(context) + 12;
    final milestones = context.watch<MilestonesProvider>();
    final auth = context.read<AuthProvider>();
    final pending = milestones.totalPendingClaims;
    final earnedBadges = _earnedBadges(milestones.progressList);

    return ListView(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomClearance),
      children: [
        Text(
          pending == 0
              ? 'Earn tiers as you explore, then claim XP rewards.'
              : '$pending tier${pending == 1 ? '' : 's'} ready to claim',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppSurfaces.textMuted(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (milestones.claimError != null) ...[
          const SizedBox(height: 8),
          Text(
            milestones.claimError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (!milestones.claimsReady)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          for (final progress in milestones.progressList) ...[
            MilestoneCard(
              progress: progress,
              claimInFlight: milestones.claimInFlight,
              playClaimAnimation:
                  milestones.lastClaimedMilestoneId ==
                      progress.definition.id &&
                  milestones.lastClaimedTier != null,
              onClaim: () async {
                final claimedTier = progress.nextClaimableTier;
                final ok = await milestones.claimNextTier(
                  milestoneId: progress.definition.id,
                  auth: auth,
                );
                if (!context.mounted || !ok || claimedTier == null) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Claimed ${progress.definition.title} Tier $claimedTier!',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
                Future<void>.delayed(const Duration(milliseconds: 700), () {
                  milestones.clearClaimFlash();
                });
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 18),
          Text(
            'Badges',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppSurfaces.textPrimary(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (earnedBadges.isEmpty)
            Text(
              'Claim milestone tiers to collect badges here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                for (final badge in earnedBadges)
                  SizedBox(
                    width: 72,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MilestoneBadgeImage(
                          definition: badge.definition,
                          tier: badge.tier,
                          size: 64,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          badge.definition.title,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppSurfaces.textPrimary(context),
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          'Tier ${badge.tier}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppSurfaces.textMuted(context),
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

class _EarnedBadge {
  const _EarnedBadge({required this.definition, required this.tier});

  final MilestoneDefinition definition;
  final int tier;
}

List<_EarnedBadge> _earnedBadges(List<MilestoneProgress> progressList) {
  final badges = <_EarnedBadge>[];
  for (final progress in progressList) {
    final claimed = progress.claimedTiers.toList()..sort();
    for (final tier in claimed) {
      badges.add(_EarnedBadge(definition: progress.definition, tier: tier));
    }
  }
  return badges;
}
