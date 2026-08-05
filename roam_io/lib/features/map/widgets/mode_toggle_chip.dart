/*
 * Author: GitHub Copilot
 * Last Modified: 30/07/2026
 * Description:
 *   A pill-shaped "Start Journey" button that opens the journey flow when tapped.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';

/// A tappable chip button to start a new journey.
class StartJourneyChip extends StatelessWidget {
  const StartJourneyChip({super.key, required this.onPressed});

  /// Callback invoked when the user taps to start a journey.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.sage,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Start Journey',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
