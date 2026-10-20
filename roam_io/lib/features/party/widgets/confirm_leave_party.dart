import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import 'party_style.dart';

/// Returns true only when the user explicitly confirms leaving their party.
Future<bool> confirmLeaveParty(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppSurfaces.pageBackground(dialogContext),
      shape: PartyStyle.dialogShape(dialogContext),
      title: const Text(
        'Are you sure?',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
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
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
          child: const Text('Leave Party'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
