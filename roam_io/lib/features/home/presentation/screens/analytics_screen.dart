/*
 * Author: [Insert Name Here]
 * Last Modified: 6/05/2026
 * Description:
 *   Provides the analytics screen UI for exploration progress, statistics,
 *   heatmap activity, and milestones.
 */

import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_page_header.dart';
import '../../../../theme/app_colours.dart';
import '../../../../theme/app_surfaces.dart';

/// Displays exploration analytics, progress summaries, and milestones.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: AppSurfaces.pageBackground(context),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(
              title: 'Your Analytics',
              subtitle: 'Stats & progress',
            ),

            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Activity Map',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppSurfaces.textPrimary(context),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildHeatmap(context),
            ),

            const SizedBox(height: 22),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      color: AppColors.sage,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Recent Milestones',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppSurfaces.textPrimary(context),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
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
                child: Column(
                  children: [
                    _buildMilestoneItem(
                      context,
                      'Explored 10 new areas',
                      '2 days ago',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Divider(
                        color: AppSurfaces.border(context),
                        height: 1,
                      ),
                    ),
                    _buildMilestoneItem(
                      context,
                      '7 day streak achieved',
                      '1 week ago',
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmap(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: List.generate(91, (index) {
        final intensity = index % 7;

        final Color color = intensity == 0
            ? AppSurfaces.softCard(context)
            : Theme.of(context).colorScheme.primary.withValues(
                alpha: isDark
                    ? 0.16 + (intensity * 0.08)
                    : 0.12 + (intensity * 0.09),
              );

        return Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppSurfaces.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppSurfaces.shadow(context),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppSurfaces.textPrimary(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppSurfaces.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneItem(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
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
              Icons.emoji_events_outlined,
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
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppSurfaces.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppSurfaces.textMuted(context),
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
