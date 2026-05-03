import 'package:flutter/material.dart';
import 'app_colours.dart';

class AppSurfaces {
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color pageBackground(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  // Level 1: main cards, e.g. profile card, journey card, analytics stat card
  static Color card(BuildContext context) {
    return isDark(context) ? const Color(0xFF171A20) : AppColors.sand;
  }

  // Level 2: nested cards/fields inside a main card
  static Color innerCard(BuildContext context) {
    return isDark(context) ? const Color(0xFF242832) : const Color(0xFFF6EBD8);
  }

  // Level 3: subtle standalone surfaces, e.g. chips, controls, secondary cards
  static Color softCard(BuildContext context) {
    return isDark(context) ? const Color(0xFF20242C) : AppColors.cream;
  }

  static Color border(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return colorScheme.primary.withValues(
      alpha: isDark(context) ? 0.24 : 0.12,
    );
  }

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color textMuted(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
  }

  static Color textSubtle(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.42);
  }

  static Color shadow(BuildContext context) {
    return Colors.black.withValues(
      alpha: isDark(context) ? 0.18 : 0.08,
    );
  }
}