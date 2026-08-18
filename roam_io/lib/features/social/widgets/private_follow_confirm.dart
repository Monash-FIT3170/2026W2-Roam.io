/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 9 August 2026
 * Description:
 *   Confirmation dialogs for private-account unfollow and remove-follower
 *   actions. Public accounts skip these prompts at the call site.
 */

import 'package:flutter/material.dart';

/// Confirms unfollowing a private account (caller already checked privacy).
Future<bool> confirmPrivateUnfollow(
  BuildContext context, {
  String? username,
}) async {
  final title = username == null || username.isEmpty
      ? 'Unfollow this account?'
      : 'Unfollow @$username?';
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: const Text(
          'You will need to request to follow again to see this private account\'s activity.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unfollow'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Confirms removing a private account from the caller's followers list.
Future<bool> confirmRemovePrivateFollower(
  BuildContext context, {
  String? username,
}) async {
  final title = username == null || username.isEmpty
      ? 'Remove this follower?'
      : 'Remove @$username?';
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
