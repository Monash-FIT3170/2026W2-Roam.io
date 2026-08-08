/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Provides reusable journey history content for Home and transitional
 *   standalone journey views.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_page_header.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/journey_controller.dart';
import '../domain/journey.dart';
import '../widgets/past_journey_summary_sheet.dart';

/// Displays the user's journey history and filter controls.
class JourneysScreen extends StatelessWidget {
  const JourneysScreen({super.key, this.showHeader = true});

  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.currentUser?.uid;
    final journeyController = context.watch<JourneyController>();

    return Container(
      color: AppSurfaces.pageBackground(context),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader)
                const AppPageHeader(
                  title: 'Journeys',
                  subtitle: 'Your past urban explorations and discoveries',
                ),

              SizedBox(height: showHeader ? 24 : 12),

            _buildFilterChips(context),

            const SizedBox(height: 24),

            // Journey list
            Expanded(
              child: userId == null
                  ? _buildEmptyState(context, 'Please log in to view journeys')
                  : StreamBuilder<List<Journey>>(
                      stream: journeyController.getJourneysStream(userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return _buildEmptyState(
                            context,
                            'Error loading journeys',
                          );
                        }

                        final journeys = snapshot.data ?? [];

                        if (journeys.isEmpty) {
                          return _buildEmptyState(
                            context,
                            'No journeys yet!\nStart exploring to record your first journey.',
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ).copyWith(bottom: 110),
                          itemCount: journeys.length,
                          itemBuilder: (context, index) {
                            return _JourneyCard(journey: journeys[index]);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route_outlined,
              size: 64,
              color: AppSurfaces.textSubtle(context),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppSurfaces.textMuted(context),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final filters = ['All', 'Recent', 'Completed', 'Favorites'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(filters.length, (index) {
          final isSelected = index == 0;

          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : AppSurfaces.softCard(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : AppSurfaces.border(context),
              ),
            ),
            child: Text(
              filters[index],
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : AppSurfaces.textMuted(context),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.journey});

  final Journey journey;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      final hour = date.hour > 12
          ? date.hour - 12
          : (date.hour == 0 ? 12 : date.hour);
      final period = date.hour >= 12 ? 'PM' : 'AM';
      final minute = date.minute.toString().padLeft(2, '0');
      return 'Today, $hour:$minute $period';
    } else if (difference.inDays == 1) {
      final hour = date.hour > 12
          ? date.hour - 12
          : (date.hour == 0 ? 12 : date.hour);
      final period = date.hour >= 12 ? 'PM' : 'AM';
      final minute = date.minute.toString().padLeft(2, '0');
      return 'Yesterday, $hour:$minute $period';
    } else if (difference.inDays < 7) {
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final hour = date.hour > 12
          ? date.hour - 12
          : (date.hour == 0 ? 12 : date.hour);
      final period = date.hour >= 12 ? 'PM' : 'AM';
      final minute = date.minute.toString().padLeft(2, '0');
      return '${weekdays[date.weekday - 1]}, $hour:$minute $period';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = AppColors.sage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        key: ValueKey('journey_card_${journey.id}'),
        color: AppSurfaces.card(context),
        elevation: 2,
        shadowColor: AppSurfaces.shadow(context),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () =>
              PastJourneySummarySheet.show(context: context, journey: journey),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppSurfaces.border(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    journey.transportMode.icon,
                    color: iconColor,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        journey.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppSurfaces.textPrimary(context),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        _formatDate(journey.startTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppSurfaces.textMuted(context),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Icon(
                            journey.transportMode.icon,
                            size: 14,
                            color: AppSurfaces.textSubtle(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${journey.formattedDistance} • ${journey.formattedDuration}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppSurfaces.textMuted(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                      if (journey.xpEarned != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rate_rounded,
                              size: 14,
                              color: AppColors.sage,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${journey.xpEarned} XP earned',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppSurfaces.textMuted(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                Icon(
                  Icons.chevron_right,
                  color: AppSurfaces.textSubtle(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
