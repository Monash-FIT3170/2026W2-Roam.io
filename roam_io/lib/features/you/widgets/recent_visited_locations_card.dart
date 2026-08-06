/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   You screen card for up to five recent visits. Uses a shrink-wrapping
 *   Column (not ListView) so Scaffold(extendBody: true) MediaQuery bottom
 *   padding cannot inflate empty beige space inside the card; the parent
 *   Profile scroll view already handles nav clearance.
 */

import 'package:flutter/material.dart';

import '../../map/data/visit.dart';
import '../../profile/domain/xp_reward_config.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';

/// Maximum visit rows shown in the Recent Visited Locations card.
const int kRecentVisitedLocationsLimit = 5;

/// Card shell matching personal progress containers on the You screen.
class RecentVisitedLocationsCard extends StatelessWidget {
  const RecentVisitedLocationsCard({super.key, required this.visitsStream});

  final Stream<List<Visit>> visitsStream;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppSurfaces.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppSurfaces.shadow(context),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: StreamBuilder(
        stream: visitsStream,
        builder: (context, AsyncSnapshot<List<Visit>> snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Text(
                'Could not load recent visits. Try again later.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppSurfaces.textMuted(context),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final visits = (snapshot.data ?? const <Visit>[])
              .take(kRecentVisitedLocationsLimit)
              .toList();

          if (visits.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: Text(
                'No visits yet. Mark places on the map to see them here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppSurfaces.textMuted(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < visits.length; index++) ...[
                if (index > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(
                      color: AppSurfaces.border(context),
                      height: 1,
                    ),
                  ),
                _VisitRow(visit: visits[index]),
              ],
            ],
          );
        },
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
