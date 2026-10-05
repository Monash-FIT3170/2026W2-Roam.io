/*
 * Author: Amarprit Singh
 * Last Updated: 4 October 2026
 * Description:
 *   Loading, empty and error states for the Profile tab's journey feed.
 */

import 'package:flutter/material.dart';

import '../../../../theme/app_surfaces.dart';
import 'journey_map_preview.dart';
import 'profile_card.dart';

/// Placeholder in the shape of a journey card while the feed loads.
///
/// Static on purpose: a looping shimmer would keep widget tests from ever
/// settling while a feed is still waiting on its first snapshot.
class JourneyCardSkeleton extends StatelessWidget {
  const JourneyCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final fill = AppSurfaces.textPrimary(context).withValues(alpha: 0.07);
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(4),
      ),
    );

    return ExcludeSemantics(
      child: ProfileCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: fill,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bar(96, 11),
                          const SizedBox(height: 6),
                          bar(150, 9),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  bar(210, 16),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (var index = 0; index < 4; index++)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              bar(44, 8),
                              const SizedBox(height: 6),
                              bar(52, 16),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: kJourneyCardVisualAspectRatio,
              child: ColoredBox(color: fill),
            ),
            const SizedBox(height: 44),
          ],
        ),
      ),
    );
  }
}

/// Shown when the traveller has not posted a journey yet, or when the feed
/// could not load.
class JourneyFeedMessage extends StatelessWidget {
  const JourneyFeedMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  const JourneyFeedMessage.empty({super.key})
    : icon = Icons.route_rounded,
      title = 'No journeys yet',
      message =
          'Start a journey from the Map to clear the fog, unlock tiles and '
          'earn XP. Your journeys will show up here.';

  const JourneyFeedMessage.error({super.key})
    : icon = Icons.cloud_off_rounded,
      title = 'Could not load journeys',
      message = 'Pull down to try again.';

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppSurfaces.textPrimary(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppSurfaces.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}
