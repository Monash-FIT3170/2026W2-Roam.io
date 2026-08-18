/*
 * Author: Alvin Liong
 * Last Modified: 16/08/2026
 * Description:
 *   Badge image for a milestone tier with placeholder fallback and drop shadow.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import 'milestone_catalog.dart';

/// Renders a milestone badge asset, falling back when art is not yet shipped.
class MilestoneBadgeImage extends StatelessWidget {
  const MilestoneBadgeImage({
    super.key,
    required this.definition,
    required this.tier,
    this.size = 72,
    this.showTierNumber = false,
  });

  final MilestoneDefinition definition;
  final int tier;
  final double size;
  final bool showTierNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetPath = definition.badgeAssetPath(tier);
    final shadowSize = size * 0.72;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: shadowSize,
            height: shadowSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
          ),
          Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Milestone badge missing: $assetPath → $error');
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppSurfaces.innerCard(context),
                  border: Border.all(color: AppSurfaces.border(context)),
                ),
                child: Icon(
                  Icons.emoji_events_outlined,
                  size: size * 0.42,
                  color: theme.colorScheme.primary,
                ),
              );
            },
          ),
          if (showTierNumber)
            Text(
              '$tier',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                height: 1.0,
                fontSize: size * 0.28,
              ),
            ),
        ],
      ),
    );
  }
}
