/*
 * Description:
 *   Party Mode styling: the shared cartoon outlines (see AppCartoon) with the
 *   app's soft card shadows, plus team colours and the VS badge.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_cartoon.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';

/// Visual tokens shared by every Party Mode surface.
class PartyStyle {
  static const double outlineWidth = 1.25;
  static const double shadowOffset = AppCartoon.shadowOffset;
  static const double radius = 22;

  /// Colour for a team id ('A' or 'B').
  static Color team(String? team) =>
      team == 'B' ? AppColors.teamB : AppColors.teamA;

  /// Human-friendly name for a team colour.
  static String teamColourName(String team) => team == 'A' ? 'Blue' : 'Red';

  static Color outline(BuildContext context) => AppCartoon.outline(context);

  static BoxDecoration card(
    BuildContext context, {
    Color? color,
    double radius = PartyStyle.radius,
    double offset = shadowOffset,
    double width = outlineWidth,
  }) => AppCartoon.card(
    context,
    color: color ?? AppSurfaces.softCard(context),
    radius: radius,
    offset: offset,
    width: width,
    soft: true,
  );

  static ButtonStyle button(
    BuildContext context, {
    required Color background,
    required Color foreground,
    double height = 52,
  }) => AppCartoon.button(
    context,
    background: background,
    foreground: foreground,
    height: height,
    width: outlineWidth,
  );

  static ShapeBorder dialogShape(BuildContext context) =>
      AppCartoon.dialogShape(context, width: outlineWidth);
}

/// Small ink "VS" sticker placed between the two team scores.
class PartyVsBadge extends StatelessWidget {
  const PartyVsBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppSurfaces.softCard(context),
        shape: BoxShape.circle,
        border: Border.all(
          color: PartyStyle.outline(context),
          width: PartyStyle.outlineWidth,
        ),
      ),
      child: Text(
        'VS',
        style: TextStyle(
          color: AppSurfaces.textPrimary(context),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
