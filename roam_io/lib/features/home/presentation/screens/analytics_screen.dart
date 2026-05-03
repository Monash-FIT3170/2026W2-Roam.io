import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../theme/app_colours.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Added theme reference

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(
              title: 'Your Analytics',
              subtitle: 'Stats & progress',
            ),
            const SizedBox(height: 24),

            // Heatmap Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Activity Map',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildHeatmap(context),
            ),
            const SizedBox(height: 32),
            
            // Summary Stats Row
            Padding(
              padding: const EdgeInsets.only(right: 24.0, left: 24.0, bottom: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'XP Count',
                      value: '2,450',
                      icon: Icons.bolt,
                      color: AppColors.sage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Tiles Visited',
                      value: '48',
                      icon: Icons.map_outlined,
                      color: AppColors.clay,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Total Visits',
                      value: '156',
                      icon: Icons.repeat,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            
            // Milestones Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Recent Milestones',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // The Green Bubble Wrapper
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                decoration: BoxDecoration(
                  color: AppColors.sage, // The green from the navbar
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildMilestoneItem(context, 'Explored 10 new areas', '2 days ago'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Divider(
                        color: AppColors.cream.withOpacity(0.3), 
                        height: 1,
                      ),
                    ),
                    _buildMilestoneItem(context, '7 day streak achieved', '1 week ago'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {required String title, required String value, required IconData icon, required Color color}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding for 3 columns
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75), 
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Centered for smaller cards
        children: [
          Icon(icon, color: color, size: 24), // Slightly smaller icon
          const SizedBox(height: 8),
          Text(
            value, 
            style: theme.textTheme.titleLarge?.copyWith( // Scaled down from headlineSmall
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            )
          ),
          const SizedBox(height: 4),
          Text(
            title, 
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.ink.withOpacity(0.62),
            ),
            textAlign: TextAlign.center,
            maxLines: 1, // Prevents text from wrapping and breaking height
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmap(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(15, (colIndex) {
          return Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: Column(
              children: List.generate(7, (rowIndex) {
                final intensity = (colIndex * 7 + rowIndex) % 5;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4.0),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _getHeatmapColor(context, intensity),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Color _getHeatmapColor(BuildContext context, int intensity) {
    switch (intensity) {
      case 0:
        return AppColors.ink;
      case 1:
        return AppColors.ink.withOpacity(0.3);
      case 2:
        return AppColors.ink.withOpacity(0.5);
      case 3:
        return AppColors.ink.withOpacity(0.8);
      case 4:
        return AppColors.ink;
      default:
        return AppColors.ink;
    }
  }

  Widget _buildMilestoneItem(BuildContext context, String title, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.cream, // Cream circle
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_outlined, // Updated to a milestone-style icon
              color: AppColors.sage, // Sage icon inside the cream circle
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: const TextStyle(
                    fontWeight: FontWeight.w600, 
                    fontSize: 16, 
                    color: AppColors.cream, // White text for contrast
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date, 
                  style: TextStyle(
                    color: AppColors.cream.withOpacity(0.85), // Slightly faded cream for date
                    fontSize: 14,
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
