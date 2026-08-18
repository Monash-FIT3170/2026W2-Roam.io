import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../models/stats_breakdown_item.dart';
import 'stats_section_card.dart';

/// Top places ranked by visit count on the Locations stats page.
class StatsTopPlacesSection extends StatelessWidget {
  const StatsTopPlacesSection({super.key, required this.places});

  final List<TopPlaceEntry> places;

  @override
  Widget build(BuildContext context) {
    return StatsSectionCard(
      title: 'Most visited',
      child: places.isEmpty
          ? Text(
              'Visit the same place twice to see your favourites here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < places.length; index++) ...[
                  if (index > 0)
                    Divider(color: AppSurfaces.border(context), height: 1),
                  _PlaceRow(
                    rank: index + 1,
                    placeName: places[index].placeName,
                    visitCount: places[index].visitCount,
                  ),
                ],
              ],
            ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.rank,
    required this.placeName,
    required this.visitCount,
  });

  final int rank;
  final String placeName;
  final int visitCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppSurfaces.innerCard(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppSurfaces.border(context)),
            ),
            child: Text(
              '$rank',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              placeName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppSurfaces.textPrimary(context),
              ),
            ),
          ),
          Text(
            '$visitCount visits',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.sage,
            ),
          ),
        ],
      ),
    );
  }
}
