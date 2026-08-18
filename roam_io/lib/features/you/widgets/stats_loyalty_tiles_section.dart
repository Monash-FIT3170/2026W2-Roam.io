import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../models/stats_breakdown_item.dart';
import 'stats_section_card.dart';

/// Top tiles by re-entry count on the Tiles stats page.
class StatsLoyaltyTilesSection extends StatelessWidget {
  const StatsLoyaltyTilesSection({super.key, required this.tiles});

  final List<TopTileEntry> tiles;

  @override
  Widget build(BuildContext context) {
    return StatsSectionCard(
      title: 'Tile loyalty',
      subtitle: 'Tiles you keep coming back to',
      child: tiles.isEmpty
          ? Text(
              'Re-enter unlocked tiles to build loyalty stats.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < tiles.length; index++) ...[
                  if (index > 0)
                    Divider(color: AppSurfaces.border(context), height: 1),
                  _TileRow(
                    rank: index + 1,
                    displayName: tiles[index].displayName,
                    entryCount: tiles[index].entryCount,
                  ),
                ],
              ],
            ),
    );
  }
}

class _TileRow extends StatelessWidget {
  const _TileRow({
    required this.rank,
    required this.displayName,
    required this.entryCount,
  });

  final int rank;
  final String displayName;
  final int entryCount;

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
              displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppSurfaces.textPrimary(context),
              ),
            ),
          ),
          Text(
            '$entryCount entries',
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
