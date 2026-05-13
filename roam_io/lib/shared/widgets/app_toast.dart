import 'package:flutter/material.dart';

import '../../theme/app_colours.dart';

class AppToast {
  const AppToast._();

  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.info_rounded,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.sage,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void success(BuildContext context, String message) {
    show(context, message, icon: Icons.check_circle_rounded);
  }

  static void error(BuildContext context, String message) {
    show(context, message, icon: Icons.error_rounded);
  }
}