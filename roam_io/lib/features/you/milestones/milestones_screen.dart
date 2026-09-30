/*
 * Author: Alvin Liong
 * Last Modified: 16/08/2026
 * Description:
 *   Milestones tab listing all exploration milestone tracks and earned badges.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import 'milestone_badge_image.dart';
import 'milestone_card.dart';
import 'milestone_catalog.dart';
import 'milestone_format.dart';
import 'milestone_progress.dart';
import 'milestones_provider.dart';

/// You-tab surface for milestone progress and tier claims.
class MilestonesScreen extends StatelessWidget {
  const MilestonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomClearance =
        AppBottomNavBar.clearanceFromScreenBottom(context) + 24;
    final milestones = context.watch<MilestonesProvider>();
    final auth = context.read<AuthProvider>();
    final milestoneProgress = milestones.progressList;
    final earnedBadges = _earnedBadges(milestoneProgress);
    final groupedProgress = _groupProgress(milestoneProgress);
    final totalBadges =
        MilestoneCatalog.all.length * MilestoneCatalog.tierCount;
    final sectionStyle = theme.textTheme.headlineSmall?.copyWith(
      color: AppSurfaces.textPrimary(context),
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomClearance),
      children: [
        Text('Milestones', style: sectionStyle),
        const SizedBox(height: 6),
        Text(
          'Explore more to unlock each collectible tier.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppSurfaces.textMuted(context),
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
        const SizedBox(height: 24),
        if (!milestones.claimsReady)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _CollectionProgress(
            collected: earnedBadges.length,
            total: totalBadges,
          ),
          const SizedBox(height: 28),
          for (final group in groupedProgress) ...[
            Text(
              group.label,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppSurfaces.textPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final progress in group.items)
              MilestoneCard(
                key: ValueKey<MilestoneId>(progress.definition.id),
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
                  await HapticFeedback.mediumImpact();
                  Future<void>.delayed(const Duration(milliseconds: 700), () {
                    milestones.clearClaimFlash();
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          Text('Badges', style: sectionStyle),
          const SizedBox(height: 6),
          Text(
            'Your claimed milestone collection',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppSurfaces.textMuted(context),
            ),
          ),
          const SizedBox(height: 20),
          if (earnedBadges.isEmpty) ...[
            Text(
              'Claim milestone tiers to collect badges here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 340 ? 2 : 3;
                const spacing = 12.0;
                final itemWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                final badgeSize = itemWidth < 82 ? itemWidth : 82.0;

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
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _showBadgePreview(context, badge),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MilestoneBadgeImage(
                                    definition: badge.definition,
                                    tier: badge.tier,
                                    size: badgeSize,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${badge.definition.title} · Tier ${badge.tier}',
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppSurfaces.textPrimary(context),
                                      fontWeight: FontWeight.w600,
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
          ],
        ],
      ],
    );
  }
}

class _CollectionProgress extends StatelessWidget {
  const _CollectionProgress({required this.collected, required this.total});

  final int collected;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = total == 0 ? 0.0 : collected / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$collected',
              style: theme.textTheme.displaySmall?.copyWith(
                color: AppSurfaces.textPrimary(context),
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                height: 1,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'of $total badges collected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppSurfaces.textMuted(context),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              color: theme.colorScheme.primary,
              backgroundColor: AppSurfaces.innerCard(context),
            ),
          ),
        ),
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

class _MilestoneGroup {
  const _MilestoneGroup(this.label, this.items);

  final String label;
  final List<MilestoneProgress> items;
}

List<_MilestoneGroup> _groupProgress(List<MilestoneProgress> progressList) {
  final ready = progressList
      .where((progress) => progress.nextClaimableTier != null)
      .toList();
  final pending = progressList
      .where(
        (progress) => progress.nextClaimableTier == null && !progress.isMaxed,
      )
      .toList();
  final completed = progressList.where((progress) => progress.isMaxed).toList();

  int compareProgress(MilestoneProgress left, MilestoneProgress right) {
    final progressOrder = right.progressToNext.compareTo(left.progressToNext);
    if (progressOrder != 0) return progressOrder;
    return left.definition.title.compareTo(right.definition.title);
  }

  ready.sort(compareProgress);
  pending.sort(compareProgress);
  completed.sort(compareProgress);
  final almost = pending
      .where((progress) => progress.progressToNext >= 0.7)
      .take(3)
      .toList(growable: false);
  final almostIds = almost.map((progress) => progress.definition.id).toSet();
  final exploring = <MilestoneProgress>[
    ...pending.where((progress) => !almostIds.contains(progress.definition.id)),
    ...completed,
  ];

  return [
    if (ready.isNotEmpty) _MilestoneGroup('Ready to claim', ready),
    if (almost.isNotEmpty) _MilestoneGroup('Almost there', almost),
    if (exploring.isNotEmpty) _MilestoneGroup('Keep exploring', exploring),
  ];
}

void _showBadgePreview(BuildContext context, _EarnedBadge badge) {
  final theme = Theme.of(context);
  final label = '${badge.definition.title} · Tier ${badge.tier}';
  final tier = badge.definition.tierDefinition(badge.tier);

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
                    const SizedBox(height: 12),
                    Text(
                      'Tier ${badge.tier} · ${formatMilestoneThreshold(tier.threshold, badge.definition.unit)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '+${tier.xpReward} XP earned',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
