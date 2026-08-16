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
        AppBottomNavBar.clearanceFromScreenBottom(context) + 48;
    final milestones = context.watch<MilestonesProvider>();
    final auth = context.read<AuthProvider>();
    final earnedBadges = _earnedBadges(milestones.progressList);
    final totalBadges =
        MilestoneCatalog.all.length * MilestoneCatalog.tierCount;
    final sectionStyle = theme.textTheme.headlineSmall?.copyWith(
      color: AppSurfaces.textPrimary(context),
      fontWeight: FontWeight.w900,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomClearance),
      children: [
        Text('Milestones', style: sectionStyle),
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
        const SizedBox(height: 12),
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
                final award = await milestones.claimNextTier(
                  milestoneId: progress.definition.id,
                  auth: auth,
                );
                if (!context.mounted || award == null) return;
                Future<void>.delayed(const Duration(milliseconds: 700), () {
                  milestones.clearClaimFlash();
                });
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 18),
          Text('Badges', style: sectionStyle),
          const SizedBox(height: 12),
          if (earnedBadges.isEmpty) ...[
            Text(
              'Claim milestone tiers to collect badges here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '0/$totalBadges badges collected',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                const columns = 3;
                const spacing = 12.0;
                final itemWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  children: [
                    for (final badge in earnedBadges)
                      SizedBox(
                        width: itemWidth,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showBadgePreview(context, badge),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
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
                                    '${badge.definition.title} ${badge.tier}',
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppSurfaces.textPrimary(context),
                                      fontWeight: FontWeight.w700,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              '${earnedBadges.length}/$totalBadges badges collected',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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

void _showBadgePreview(BuildContext context, _EarnedBadge badge) {
  final theme = Theme.of(context);
  final label = '${badge.definition.title} ${badge.tier}';

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close badge preview',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MilestoneBadgeImage(
                      definition: badge.definition,
                      tier: badge.tier,
                      size: 200,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (badge.definition.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        badge.definition.subtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
