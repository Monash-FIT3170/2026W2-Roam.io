/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Analytics card for recent visits using a non-scrollable ListView
 *   (shrinkWrap) inside a parent scroll view, plus flat visit XP hint and states.
 */

import 'package:flutter/material.dart';

import '../../map/data/visit.dart';
import '../../profile/domain/xp_reward_config.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';

/// Card shell matching analytics milestone-style containers.
class RecentVisitedLocationsCard extends StatelessWidget {
  const RecentVisitedLocationsCard({super.key, required this.visitsStream});

  final Stream<List<Visit>> visitsStream;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
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

          final visits = snapshot.data ?? const <Visit>[];

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

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visits.length,
            separatorBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Divider(color: AppSurfaces.border(context), height: 1),
            ),
            itemBuilder: (context, index) => _VisitRow(visit: visits[index]),
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
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
