/*
 * Author: Amarprit Singh
 * Last Updated: 4 October 2026
 * Description:
 *   Card surface shared by the Profile tab's summary, badges and journeys, so
 *   they sit on one consistent border, shadow and corner radius.
 */

import 'package:flutter/material.dart';

import '../../../../theme/app_surfaces.dart';

const double kProfileCardRadius = 16;

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.child,
    this.onTap,
    this.radius = kProfileCardRadius,
  });

  final Widget child;

  /// Gives the whole card a pressed state. Leave null when only parts of the
  /// card are tappable.
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppSurfaces.softCard(context),
        borderRadius: borderRadius,
        border: Border.all(color: AppSurfaces.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppSurfaces.shadow(context),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          color: Colors.transparent,
          child: onTap == null ? child : InkWell(onTap: onTap, child: child),
        ),
      ),
    );
  }
}
