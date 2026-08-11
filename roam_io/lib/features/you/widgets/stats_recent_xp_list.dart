import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../profile/domain/xp_event.dart';
import '../services/stats_aggregation_service.dart';
import 'stats_section_card.dart';

/// Recent XP awards list for the XP stats category.
class StatsRecentXpList extends StatelessWidget {
  const StatsRecentXpList({
    super.key,
    required this.events,
    this.aggregationService = const StatsAggregationService(),
    this.limit = 10,
  });

  final List<XpEvent> events;
  final StatsAggregationService aggregationService;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final sorted = events.toList()
      ..sort((left, right) => right.earnedAt.compareTo(left.earnedAt));
    final recent = sorted.take(limit).toList();

    return StatsSectionCard(
      title: 'Recent awards',
      child: recent.isEmpty
          ? Text(
              'No XP awards yet. Visit places or unlock tiles to earn XP.',
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
                  _XpEventRow(
                    event: recent[index],
                    label: aggregationService.xpSourceLabel(recent[index].source),
                  ),
                ],
              ],
            ),
    );
  }
}

class _XpEventRow extends StatelessWidget {
  const _XpEventRow({required this.event, required this.label});

  final XpEvent event;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(_iconForSource(event.source), color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppSurfaces.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTimestamp(event.earnedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppSurfaces.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${event.amount} XP',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.sage,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForSource(XpEventSource source) {
    switch (source) {
      case XpEventSource.visit:
        return Icons.place_outlined;
      case XpEventSource.tileUnlock:
        return Icons.grid_view_rounded;
      case XpEventSource.journey:
        return Icons.route_rounded;
      case XpEventSource.unknown:
        return Icons.star_outline_rounded;
    }
  }
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '$hour:${two(local.minute)} $period';
}
