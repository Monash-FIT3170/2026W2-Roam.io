/*
 * Author: Alvin Liong
 * Last Modified: 16/08/2026
 * Description:
 *   Card for one milestone with compact claim layout or progress layout.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import 'milestone_badge_image.dart';
import 'milestone_format.dart';
import 'milestone_progress.dart';

/// Single milestone row on the Milestones tab.
class MilestoneCard extends StatefulWidget {
  const MilestoneCard({
    super.key,
    required this.progress,
    required this.onClaim,
    required this.claimInFlight,
    this.playClaimAnimation = false,
  });

  final MilestoneProgress progress;
  final Future<void> Function() onClaim;
  final bool claimInFlight;
  final bool playClaimAnimation;

  @override
  State<MilestoneCard> createState() => _MilestoneCardState();
}

class _MilestoneCardState extends State<MilestoneCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.14), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.14, end: 0.96), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant MilestoneCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playClaimAnimation && !oldWidget.playClaimAnimation) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final definition = progress.definition;
    final nextClaim = progress.nextClaimableTier;
    final hasClaim = nextClaim != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 340;
          final badgeSize = compact ? 76.0 : 88.0;

          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScaleTransition(
                    scale: _scale,
                    child: MilestoneBadgeImage(
                      definition: definition,
                      tier: progress.displayTier,
                      size: badgeSize,
                    ),
                  ),
                  SizedBox(width: compact ? 12 : 16),
                  Expanded(
                    child: hasClaim
                        ? _ClaimBody(
                            title: definition.title,
                            subtitle: definition.subtitle,
                            tier: nextClaim,
                            xpReward: definition
                                .tierDefinition(nextClaim)
                                .xpReward,
                            claimInFlight: widget.claimInFlight,
                            onClaim: widget.onClaim,
                          )
                        : _ProgressBody(
                            title: definition.title,
                            subtitle: definition.subtitle,
                            tier: progress.displayTier,
                            isMaxed: progress.isMaxed,
                            barProgress: progress.isMaxed
                                ? 1.0
                                : progress.progressToNext,
                            barLabel: () {
                              final unit = definition.unit;
                              final nextTier = progress.nextTier;
                              if (nextTier == null) {
                                return formatMilestoneValue(
                                  progress.currentValue,
                                  unit,
                                );
                              }
                              return '${formatMilestoneValue(progress.currentValue, unit)} / '
                                  '${formatMilestoneThreshold(nextTier.threshold, unit)}';
                            }(),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: AppSurfaces.border(context)),
            ],
          );
        },
      ),
    );
  }
}

class _ClaimBody extends StatelessWidget {
  const _ClaimBody({
    required this.title,
    required this.subtitle,
    required this.tier,
    required this.xpReward,
    required this.claimInFlight,
    required this.onClaim,
  });

  final String title;
  final String subtitle;
  final int tier;
  final int xpReward;
  final bool claimInFlight;
  final Future<void> Function() onClaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ready to claim · Tier $tier',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppSurfaces.textPrimary(context),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppSurfaces.textMuted(context),
            height: 1.25,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                '+$xpReward XP',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: claimInFlight ? null : () => onClaim(),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Claim'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({
    required this.title,
    required this.subtitle,
    required this.tier,
    required this.isMaxed,
    required this.barProgress,
    required this.barLabel,
  });

  final String title;
  final String subtitle;
  final int tier;
  final bool isMaxed;
  final double barProgress;
  final String barLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isMaxed ? 'Complete' : 'Tier $tier',
          style: theme.textTheme.labelSmall?.copyWith(
            color: isMaxed
                ? theme.colorScheme.primary
                : AppSurfaces.textMuted(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppSurfaces.textPrimary(context),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppSurfaces.textMuted(context),
            height: 1.25,
          ),
        ),
        const SizedBox(height: 14),
        _MilestoneProgressBar(progress: barProgress.clamp(0.0, 1.0)),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: Text(
                barLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppSurfaces.textMuted(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '${(barProgress * 100).round()}%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Same look as Stats hero XP bar, at half height (11px), without inner label.
class _MilestoneProgressBar extends StatelessWidget {
  const _MilestoneProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final fill = const Color.fromARGB(255, 73, 134, 87);
    final track = AppSurfaces.isDark(context)
        ? const Color(0xFF2A2F38)
        : const Color(0xFFD8D8D8);

    return SizedBox(
      height: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => FractionallySizedBox(
                widthFactor: value,
                alignment: Alignment.centerLeft,
                child: ColoredBox(color: fill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
