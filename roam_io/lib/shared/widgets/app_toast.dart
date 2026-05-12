/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Provides reusable floating toast messages for success, error, and general
 *   feedback (optional subtitle for two-line messages, e.g. visit + XP).
 */

import 'package:flutter/material.dart';

import '../../theme/app_colours.dart';

/// Shows app-styled snack bar feedback from screen event handlers.
class AppToast {
  const AppToast._();

  static SnackBar _styledSnackBar({
    required String message,
    required IconData icon,
    String? subtitle,
  }) {
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      backgroundColor: AppColors.sage,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: subtitle == null || subtitle.isEmpty
                ? Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Displays a floating toast with an optional leading icon.
  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.info_rounded,
    String? subtitle,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      _styledSnackBar(message: message, icon: icon, subtitle: subtitle),
    );
  }

  /// Same styling as [show], but uses an existing [ScaffoldMessengerState].
  ///
  /// Use this after closing a modal route (e.g. bottom sheet): passing
  /// [ScaffoldMessenger.of] on the messenger's own [BuildContext] fails,
  /// because that context is not an ancestor of itself.
  static void showForMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    IconData icon = Icons.info_rounded,
    String? subtitle,
  }) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      _styledSnackBar(message: message, icon: icon, subtitle: subtitle),
    );
  }

  /// Displays a success toast.
  static void success(
    BuildContext context,
    String message, {
    String? subtitle,
  }) {
    show(context, message, icon: Icons.check_circle_rounded, subtitle: subtitle);
  }

  /// Success toast on a known messenger (see [showForMessenger]).
  static void successForMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    String? subtitle,
  }) {
    showForMessenger(
      messenger,
      message,
      icon: Icons.check_circle_rounded,
      subtitle: subtitle,
    );
  }

  /// Displays an error toast.
  static void error(BuildContext context, String message) {
    show(context, message, icon: Icons.error_rounded);
  }
}
