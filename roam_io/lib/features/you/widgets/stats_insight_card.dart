import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import 'stats_section_card.dart';

/// Highlight card for a single derived insight on Stats category pages.
class StatsInsightCard extends StatelessWidget {
  const StatsInsightCard({
    super.key,
    required this.message,
    this.icon = Icons.auto_awesome_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StatsSectionCard(
      title: 'Insight',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppSurfaces.innerCard(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppSurfaces.border(context)),
            ),
            child: Icon(icon, color: AppColors.sage, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppSurfaces.textPrimary(context),
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
