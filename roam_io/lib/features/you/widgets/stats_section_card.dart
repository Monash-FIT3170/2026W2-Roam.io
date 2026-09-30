import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';

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
        Divider(height: 1, color: AppSurfaces.border(context)),
        const SizedBox(height: 24),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppSurfaces.textPrimary(context),
            fontWeight: FontWeight.w700,
            letterSpacing: -0.25,
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
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
