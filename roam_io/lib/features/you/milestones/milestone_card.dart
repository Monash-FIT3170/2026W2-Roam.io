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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppSurfaces.border(context)),
        boxShadow: AppSurfaces.cardShadow(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _scale,
            child: MilestoneBadgeImage(
              definition: definition,
              tier: progress.displayTier,
              size: 56,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: _MilestoneCardBody.height,
              child: hasClaim
                  ? _ClaimBody(
                      title: definition.title,
                      subtitle: definition.subtitle,
                      xpReward: definition.tierDefinition(nextClaim).xpReward,
                      claimInFlight: widget.claimInFlight,
                      onClaim: widget.onClaim,
                    )
                  : _ProgressBody(
                      title: definition.title,
                      subtitle: definition.subtitle,
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
          ),
        ],
      ),
    );
  }
}

abstract final class _MilestoneCardBody {
  /// Shared content column height so claim and progress cards match.
  /// title(~20) + 4 + subtitle(~16) + 8 + footer(32) = 80
  static const double height = 80;
  static const double titleToSubtitle = 4;
  static const double subtitleToFooter = 8;
  static const double footerHeight = 32;
}

class _ClaimBody extends StatelessWidget {
  const _ClaimBody({
    required this.title,
    required this.subtitle,
    required this.xpReward,
    required this.claimInFlight,
    required this.onClaim,
  });

  final String title;
  final String subtitle;
  final int xpReward;
  final bool claimInFlight;
  final Future<void> Function() onClaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: AppSurfaces.textPrimary(context),
            height: 1.15,
          ),
        ),
        const SizedBox(height: _MilestoneCardBody.titleToSubtitle),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppSurfaces.textMuted(context),
            height: 1.15,
          ),
        ),
        const SizedBox(height: _MilestoneCardBody.subtitleToFooter - 4),
        SizedBox(
          height: _MilestoneCardBody.footerHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '+$xpReward XP',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppSurfaces.textPrimary(context),
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
              FilledButton(
                onPressed: claimInFlight ? null : () => onClaim(),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Claim'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({
    required this.title,
    required this.subtitle,
    required this.barProgress,
    required this.barLabel,
  });

  final String title;
  final String subtitle;
  final double barProgress;
  final String barLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: AppSurfaces.textPrimary(context),
            height: 1.15,
          ),
        ),
        const SizedBox(height: _MilestoneCardBody.titleToSubtitle),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppSurfaces.textMuted(context),
            height: 1.15,
          ),
        ),
        const SizedBox(height: _MilestoneCardBody.subtitleToFooter - 4),
        SizedBox(
          height: _MilestoneCardBody.footerHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MilestoneProgressBar(progress: barProgress.clamp(0.0, 1.0)),
              const SizedBox(height: 4),
              Text(
                barLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppSurfaces.textPrimary(context),
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ],
          ),
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

    return Container(
      height: 11,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track),
            FractionallySizedBox(
              widthFactor: progress,
              alignment: Alignment.centerLeft,
              child: ColoredBox(color: fill),
            ),
          ],
        ),
      ),
    );
  }
}
