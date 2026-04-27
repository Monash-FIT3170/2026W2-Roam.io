import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_page_header.dart';

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
            
            // TODO: Add Summary Stats
            
            // TODO: Add Heatmap
            
            // Milestones Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Recent Milestones',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            _buildMilestoneItem(context, 'Explored 10 new areas', '2 days ago'),
            _buildMilestoneItem(context, '7 day streak achieved', '1 week ago'),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {required String title, required String value, required IconData icon, required Color color}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
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
    final primary = Theme.of(context).primaryColor;
    switch (intensity) {
      case 0:
        return Colors.grey.shade200;
      case 1:
        return primary.withOpacity(0.3);
      case 2:
        return primary.withOpacity(0.5);
      case 3:
        return primary.withOpacity(0.8);
      case 4:
        return primary;
      default:
        return Colors.grey.shade200;
    }
  }

  Widget _buildMilestoneItem(BuildContext context, String title, String date) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.star, color: theme.primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 4),
                Text(date, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
