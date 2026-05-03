import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_page_header.dart';
import '../../../../theme/app_colours.dart';
import '../../../../theme/app_surfaces.dart';

class JourneysScreen extends StatelessWidget {
  const JourneysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppSurfaces.pageBackground(context),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(
                title: 'Journeys',
                subtitle: 'Your past urban explorations and discoveries',
              ),

              const SizedBox(height: 24),

              _buildFilterChips(context),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildJourneyCard(
                      context,
                      title: 'Clayton Campus Loop',
                      date: 'Yesterday, 4:30 PM',
                      stats: '3.2 km • 45 mins',
                      icon: Icons.school_outlined,
                      iconColor: AppColors.clay,
                    ),
                    _buildJourneyCard(
                      context,
                      title: 'Mulgrave Reserve Run',
                      date: 'Oct 12, 2026',
                      stats: '5.0 km • 32 mins',
                      icon: Icons.park_outlined,
                      iconColor: AppColors.sage,
                    ),
                    _buildJourneyCard(
                      context,
                      title: 'CBD Discovery Walk',
                      date: 'Oct 05, 2026',
                      stats: '8.4 km • 2 hrs 15 mins',
                      icon: Icons.location_city_outlined,
                      iconColor: AppColors.clay,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
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

  Widget _buildJourneyCard(
    BuildContext context, {
    required String title,
    required String date,
    required String stats,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppSurfaces.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppSurfaces.shadow(context),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
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
              icon,
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
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppSurfaces.textPrimary(context),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  date,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppSurfaces.textMuted(context),
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Icon(
                      Icons.directions_walk,
                      size: 14,
                      color: AppSurfaces.textSubtle(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      stats,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppSurfaces.textMuted(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Icon(
            Icons.chevron_right,
            color: AppSurfaces.textSubtle(context),
          ),
        ],
      ),
    );
  }
}