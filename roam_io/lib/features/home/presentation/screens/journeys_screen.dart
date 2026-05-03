import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../theme/app_colours.dart';

class JourneysScreen extends StatelessWidget {
  const JourneysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(
              title: 'Journeys',
              subtitle: 'Your past urban explorations and discoveries',
            ),
            const SizedBox(height: 24), // Increased spacing slightly

            // Filter Chips
            _buildFilterChips(),
            const SizedBox(height: 24),
            
            // Journeys List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                    iconColor: AppColors.ink,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildFilterChips() {
    final filters = ['All', 'Recent', 'Completed', 'Favorites'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: List.generate(filters.length, (index) {
          final isSelected = index == 0; // Mocking 'All' as the active filter
          return Container(
            margin: const EdgeInsets.only(right: 12.0),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.sage : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.sage : AppColors.ink.withOpacity(0.1),
              ),
            ),
            child: Text(
              filters[index],
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.ink.withOpacity(0.6),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),// Pure white as requested previously
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(0.04), // Clean ink shadow
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.ink.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.directions_walk, size: 14, color: AppColors.ink.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Text(
                      stats,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.ink.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Chevron
          Icon(Icons.chevron_right, color: AppColors.ink.withOpacity(0.3)),
        ],
      ),
    );
  }
}