/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Provides grouped, row-based Settings components for account and
 *   preference navigation.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_cartoon.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';

/// Minimal Settings look: light surfaces on the Home page background,
/// hairline borders, and the app's soft card shadow.
class SettingsStyle {
  static const double outlineWidth = 1;
  static const double radius = 16;

  /// Light-mode colour for the whole Settings page: background, cards,
  /// sheets, and fields.
  static const Color lightColour = Color(0xFFF2EBDD);

  /// Page and sheet background.
  static Color background(BuildContext context) => AppSurfaces.isDark(context)
      ? AppSurfaces.pageBackground(context)
      : lightColour;

  /// Card surface; matches the page in light mode so only hairlines separate
  /// groups.
  static Color surface(BuildContext context) =>
      AppSurfaces.isDark(context) ? AppColors.darkSurface : lightColour;

  /// Hairline border for cards, fields, and buttons on Settings pages.
  static Color outline(BuildContext context) =>
      AppColors.sage.withValues(alpha: AppSurfaces.isDark(context) ? 0.3 : 0.2);

  static BoxDecoration card(BuildContext context, {Color? color}) {
    return AppCartoon.card(
      context,
      color: color ?? surface(context),
      radius: radius,
      width: outlineWidth,
      soft: true,
      outlineColor: outline(context),
    );
  }

  static ButtonStyle button(
    BuildContext context, {
    required Color background,
    required Color foreground,
    double height = 50,
  }) {
    return AppCartoon.button(
      context,
      background: background,
      foreground: foreground,
      height: height,
      width: outlineWidth,
      outlineColor: Colors.transparent,
    ).copyWith(
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  static InputDecoration input(BuildContext context, {String? labelText}) {
    return AppCartoon.input(
      context,
      labelText: labelText,
      width: outlineWidth,
      outlineColor: outline(context),
      fillColor: surface(context),
    );
  }
}

/// Displays a Settings section title and grouped rows.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppSurfaces.isDark(context)
                  ? AppColors.lightSage
                  : AppColors.sage,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: SettingsStyle.card(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              SettingsStyle.radius - SettingsStyle.outlineWidth,
            ),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

/// Full-width Settings row with a tinted icon badge and optional trailing
/// control and chevron.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
    this.destructive = false,
    this.showChevron = true,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;
  final bool showChevron;

  /// Badge colour; defaults to sage (or the error colour when destructive).
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = AppSurfaces.isDark(context);
    final titleColor = destructive
        ? theme.colorScheme.error
        : AppSurfaces.textPrimary(context);
    final badgeColor = destructive
        ? theme.colorScheme.error
        : iconColor ?? AppColors.sage;
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: isDark ? 0.28 : 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: isDark
                        ? Color.lerp(badgeColor, Colors.white, 0.35)
                        : badgeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ] else if (showChevron && enabled) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: AppSurfaces.textSubtle(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
