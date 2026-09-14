/*
 * Author: OpenAI Codex
 * Last Modified: 14 September 2026
 * Description:
 *   Presents the safety acknowledgement required before starting a driving
 *   journey.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';

/// Asks the user to acknowledge the driving safety warning.
///
/// Returns `true` only when the user explicitly chooses to start the journey.
/// Cancelling or dismissing the dialog returns `false`.
Future<bool> showDrivingSafetyDialog(BuildContext context) async {
  final acknowledged = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: AppColors.clay,
        size: 32,
      ),
      title: const Text('Drive Safely'),
      content: const Text(
        'Do not use Roam.io while driving. Set up your journey before you '
        'start moving and only interact with your phone when safely parked.',
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Start journey'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  return acknowledged ?? false;
}
