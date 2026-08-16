/*
 * Author: Alvin Liong
 * Last Modified: 16/08/2026
 * Description:
 *   Milestones tab listing all exploration milestone tracks.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import 'milestone_card.dart';
import 'milestones_provider.dart';

/// You-tab surface for milestone progress and tier claims.
class MilestonesScreen extends StatelessWidget {
  const MilestonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomClearance =
        AppBottomNavBar.clearanceFromScreenBottom(context) + 12;
    final milestones = context.watch<MilestonesProvider>();
    final auth = context.read<AuthProvider>();
    final pending = milestones.totalPendingClaims;

    return ListView(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomClearance),
      children: [
        Text(
          pending == 0
              ? 'Earn tiers as you explore, then claim XP rewards.'
              : '$pending tier${pending == 1 ? '' : 's'} ready to claim',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppSurfaces.textMuted(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (milestones.claimError != null) ...[
          const SizedBox(height: 8),
          Text(
            milestones.claimError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
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
        else
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
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
