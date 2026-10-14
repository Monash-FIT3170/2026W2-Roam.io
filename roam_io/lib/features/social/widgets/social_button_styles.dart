/*
 * Author: kpha0032
 * Last Updated: 15 October 2026
 * Description:
 *   Shared stadium button styles for Social actions. Primary actions (Follow,
 *   Accept, Join) are sage filled; secondary actions (Following, Requested,
 *   Decline, Remove) are outlined on a light surface; destructive dialog
 *   confirmations are clay.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';

/// Button style tokens shared by Social screens.
class SocialButtonStyles {
  const SocialButtonStyles._();

  static const EdgeInsets compactPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );

  static const TextStyle _labelStyle = TextStyle(fontWeight: FontWeight.w700);

  /// Sage filled pill for the main action in a row or header.
  static ButtonStyle primary({bool compact = false}) {
    return FilledButton.styleFrom(
      shape: const StadiumBorder(),
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      padding: compact ? compactPadding : null,
      backgroundColor: AppColors.sage,
      foregroundColor: Colors.white,
      textStyle: _labelStyle,
    );
  }

  /// Outlined pill for secondary or "already done" states.
  static ButtonStyle secondary(
    BuildContext context, {
    bool compact = false,
    Color? backgroundColor,
  }) {
    return OutlinedButton.styleFrom(
      shape: const StadiumBorder(),
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      padding: compact ? compactPadding : null,
      foregroundColor: AppSurfaces.textPrimary(context),
      backgroundColor: backgroundColor ?? AppColors.sand,
      side: BorderSide(color: AppSurfaces.border(context)),
      textStyle: _labelStyle,
    );
  }

  /// Clay filled pill confirming a destructive dialog action.
  static ButtonStyle destructive() {
    return FilledButton.styleFrom(
      shape: const StadiumBorder(),
      backgroundColor: AppColors.clay,
      foregroundColor: Colors.white,
      textStyle: _labelStyle,
    );
  }
}
