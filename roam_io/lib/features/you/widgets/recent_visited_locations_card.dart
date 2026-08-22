/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 16 August 2026
 * Description:
 *   Stats card for up to five recent visits, titled inside the card like
 *   Recent awards on the XP tab.
 */

import 'package:flutter/material.dart';

import '../../map/data/visit.dart';
import '../../profile/domain/xp_reward_config.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import 'stats_section_card.dart';

/// Maximum visit rows shown in the Recent Visited Locations card.
const int kRecentVisitedLocationsLimit = 5;

/// Card shell for recent visits on the Locations stats category.
class RecentVisitedLocationsCard extends StatelessWidget {
  const RecentVisitedLocationsCard({
    super.key,
    required this.visits,
    this.isLoading = false,
    this.error,
  });

  final List<Visit> visits;
  final bool isLoading;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return StatsSectionCard(title: 'Recent visits', child: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    if (error != null) {
      return Text(
        'Could not load recent visits. Try again later.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppSurfaces.textMuted(context),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final limited = visits.take(kRecentVisitedLocationsLimit).toList();

    if (limited.isEmpty) {
      return Text(
        'No visits yet. Mark places on the map to see them here.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppSurfaces.textMuted(context),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < limited.length; index++) ...[
          if (index > 0) Divider(color: AppSurfaces.border(context), height: 1),
          _VisitRow(visit: limited[index]),
        ],
      ],
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppSurfaces.innerCard(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppSurfaces.border(context)),
            ),
            child: Icon(
              Icons.place_outlined,
              color: colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.placeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppSurfaces.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatVisitTimestamp(visit.visitedAt),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppSurfaces.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${XpRewardConfig.visitXpReward} XP',
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

String _formatVisitTimestamp(DateTime d) {
  final local = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;

  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '$hour:${two(local.minute)} $period';
}
