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
      disabledBackgroundColor: AppColors.sage.withValues(alpha: 0.45),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
      textStyle: _labelStyle,
    );
  }

  /// Outlined pill for secondary or "already done" states.
  ///
  /// [backgroundColor] overrides the light-mode fill only.
  static ButtonStyle secondary(
    BuildContext context, {
    bool compact = false,
    Color? backgroundColor,
  }) {
    // Light fills (sand / cream) would put light dark-mode text on a light
    // pill, so dark mode always uses the elevated dark surface.
    final fill = AppSurfaces.isDark(context)
        ? AppColors.darkElevated
        : backgroundColor ?? AppColors.sand;

    return OutlinedButton.styleFrom(
      shape: const StadiumBorder(),
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      padding: compact ? compactPadding : null,
      foregroundColor: AppSurfaces.textPrimary(context),
      backgroundColor: fill,
      disabledBackgroundColor: fill.withValues(alpha: 0.6),
      disabledForegroundColor: AppSurfaces.textSubtle(context),
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
