import 'package:flutter/material.dart';

/// Returns true only when the user explicitly confirms leaving their party.
Future<bool> confirmLeaveParty(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Are you sure?'),
      content: const Text('You will leave this party.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          child: const Text('Leave Party'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
