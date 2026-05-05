/*
 * Author: [Insert Name Here]
 * Last Modified: 6/05/2026
 * Description:
 *   Provides shared surface, border, text, and shadow colours that adapt to
 *   the active theme brightness.
 */

import 'package:flutter/material.dart';
import 'app_colours.dart';

/// Supplies theme-aware surface and text colors for custom UI components.
class AppSurfaces {
  /// Returns whether the current theme is using dark brightness.
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color pageBackground(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  /// Surface for primary cards, such as profile and analytics cards.
  static Color card(BuildContext context) {
    return isDark(context) ? const Color(0xFF171A20) : AppColors.sand;
  }

  /// Surface for nested cards and fields inside a main card.
  static Color innerCard(BuildContext context) {
    return isDark(context) ? const Color(0xFF242832) : const Color(0xFFF6EBD8);
  }

  /// Surface for subtle standalone controls, chips, and secondary cards.
  static Color softCard(BuildContext context) {
    return isDark(context) ? const Color(0xFF20242C) : AppColors.cream;
  }

  /// Border color tuned for the current theme brightness.
  static Color border(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return colorScheme.primary.withValues(alpha: isDark(context) ? 0.24 : 0.12);
  }

  /// Primary text color for custom-painted surfaces.
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  /// Muted text color for secondary content.
  static Color textMuted(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
  }

  /// Subtle text color for low-emphasis labels and icons.
  static Color textSubtle(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.42);
  }

  /// Shadow color adjusted for light and dark surfaces.
  static Color shadow(BuildContext context) {
    return Colors.black.withValues(alpha: isDark(context) ? 0.18 : 0.08);
  }
}
