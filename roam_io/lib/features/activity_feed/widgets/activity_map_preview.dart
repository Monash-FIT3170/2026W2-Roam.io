/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Stub map preview for activity cards and detail screens. Establishes layout
 *   before real route/map snapshots are wired; does not show fake geography.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';

/// Placeholder map region replaceable later by a real map/route widget.
class ActivityMapPreview extends StatelessWidget {
  const ActivityMapPreview({super.key, this.expanded = false});

  /// When true, uses a taller aspect for the activity detail screen.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: expanded ? 4 / 3 : 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppSurfaces.softCard(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppSurfaces.border(context)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: expanded ? 40 : 32,
                color: colorScheme.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 8),
              Text(
                expanded ? 'Journey route map' : 'Map preview',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppSurfaces.textMuted(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
