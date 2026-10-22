import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';

/// Vertical space between sections on Statistics category pages.
const double kStatsSectionGap = 32;

/// Lightweight section shell for Statistics page lists and insights.
class StatsSectionCard extends StatelessWidget {
  const StatsSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          height: 1.5,
          thickness: 1.5,
          color: AppSurfaces.sectionDivider(context),
        ),
        const SizedBox(height: 20),
        Text(
          title.toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppSurfaces.isDark(context)
                ? AppColors.lightSage
                : AppColors.sage,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppSurfaces.textMuted(context),
            ),
          ),
        ],
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}
