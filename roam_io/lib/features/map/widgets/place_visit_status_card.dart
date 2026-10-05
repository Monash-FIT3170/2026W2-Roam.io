import 'package:flutter/material.dart';

import '../domain/place_visit_feedback.dart';

/// Pairs persistent visit history with live range feedback without relying on
/// colour alone. Only the state heading is announced on proximity changes.
class PlaceVisitStatusCard extends StatelessWidget {
  const PlaceVisitStatusCard({
    super.key,
    required this.feedback,
    required this.isCheckingLocation,
    required this.onRefresh,
  });

  final PlaceVisitFeedback feedback;
  final bool isCheckingLocation;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final checking = isCheckingLocation && !feedback.hasLocation;
    final title = checking ? 'Checking location…' : feedback.rangeLabel;
    final colour = feedback.isInRange
        ? scheme.onPrimaryContainer
        : scheme.onSurface;
    final message = !feedback.hasLocation
        ? checking
              ? 'Finding your distance to this place.'
              : 'Turn on location access, then try again.'
        : feedback.isVisited
        ? '${feedback.distanceLabel}. Your visit is saved.'
        : feedback.isInRange
        ? '${feedback.distanceLabel}. You can mark your visit now.'
        : '${feedback.distanceLabel}. Get within ${PlaceVisitFeedback.visitRadiusMetres.round()}m to mark your visit.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              feedback.isVisited
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: scheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                feedback.isVisited ? 'Visited' : 'Not visited',
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: feedback.isInRange
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    Icon(
                      checking
                          ? Icons.location_searching
                          : feedback.isInRange
                          ? Icons.my_location
                          : feedback.hasLocation
                          ? Icons.directions_walk
                          : Icons.location_off_outlined,
                      size: 24,
                      color: colour,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colour,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: colour),
              ),
              if (feedback.isVisited) ...[
                const SizedBox(height: 6),
                Text(
                  'You can edit this visit from anywhere.',
                  style: theme.textTheme.bodySmall?.copyWith(color: colour),
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: isCheckingLocation ? null : onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  isCheckingLocation
                      ? 'Checking location…'
                      : feedback.hasLocation
                      ? 'Refresh location'
                      : 'Try location again',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
