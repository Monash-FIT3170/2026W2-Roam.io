import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../../journeys/domain/journey.dart';
import '../models/stats_breakdown_item.dart';
import 'stats_section_card.dart';

/// Compact recent journeys list for the Journeys stats category.
class StatsRecentJourneysList extends StatelessWidget {
  const StatsRecentJourneysList({
    super.key,
    required this.journeys,
    this.limit = 5,
  });

  final List<Journey> journeys;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final sorted = journeys.toList()
      ..sort((left, right) => right.startTime.compareTo(left.startTime));
    final recent = sorted.take(limit).toList();

    return StatsSectionCard(
      title: 'Recent journeys',
      child: recent.isEmpty
          ? Text(
              'No journeys yet. Start tracking from the map to see them here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < recent.length; index++) ...[
                  if (index > 0)
                    Divider(color: AppSurfaces.border(context), height: 1),
                  _JourneyRow(journey: recent[index]),
                ],
              ],
            ),
    );
  }
}

class _JourneyRow extends StatelessWidget {
  const _JourneyRow({required this.journey});

  final Journey journey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distanceKm = journey.distanceMeters / 1000;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(journey.transportMode.icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  journey.transportMode.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppSurfaces.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${distanceKm.toStringAsFixed(1)} km · '
                  '${journey.tilesUnlocked} tiles · '
                  '${_formatTimestamp(journey.startTime)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppSurfaces.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

/// Highlight cards for standout journey stats.
class StatsJourneyHighlights extends StatelessWidget {
  const StatsJourneyHighlights({super.key, required this.journeys});

  final List<Journey> journeys;

  @override
  Widget build(BuildContext context) {
    if (journeys.isEmpty) {
      return const SizedBox.shrink();
    }

    final longest = journeys.reduce(
      (left, right) =>
          left.distanceMeters >= right.distanceMeters ? left : right,
    );
    final mostTiles = journeys.reduce(
      (left, right) => left.tilesUnlocked >= right.tilesUnlocked ? left : right,
    );

    return Row(
      children: [
        Expanded(
          child: _HighlightTile(
            label: 'Longest',
            value: '${(longest.distanceMeters / 1000).toStringAsFixed(1)} km',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HighlightTile(
            label: 'Most tiles',
            value: '${mostTiles.tilesUnlocked}',
          ),
        ),
      ],
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppSurfaces.innerCard(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppSurfaces.textMuted(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppSurfaces.textPrimary(context),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mode split breakdown wrapper using [StatsBreakdownItem] rows.
class StatsModeSplitSection extends StatelessWidget {
  const StatsModeSplitSection({super.key, required this.items});

  final List<StatsBreakdownItem> items;

  @override
  Widget build(BuildContext context) {
    return StatsSectionCard(
      title: 'Transport modes',
      child: items.isEmpty
          ? Text(
              'No journeys to break down yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          items[index].label,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${items[index].value}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
