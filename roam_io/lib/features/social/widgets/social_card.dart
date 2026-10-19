/*
 * Author: kpha0032
 * Last Updated: 15 October 2026
 * Description:
 *   Shared card surface for Social list rows and panels so corner radii,
 *   borders, and shadows match across Social screens.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';

/// Card styling tokens shared by Social screens.
class SocialCard {
  const SocialCard._();

  static const double radius = 16;

  static BorderRadius get borderRadius => BorderRadius.circular(radius);

  /// Theme-aware card decoration matching the You / Stats cards.
  static BoxDecoration decoration(BuildContext context) {
    return BoxDecoration(
      color: AppSurfaces.card(context),
      borderRadius: borderRadius,
      border: Border.all(color: AppSurfaces.border(context)),
      boxShadow: AppSurfaces.cardShadow(context),
    );
  }
}
