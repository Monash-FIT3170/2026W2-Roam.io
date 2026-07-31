/*
 * Author: Sam Sutherland
 * Last Modified: 31/07/2026
 * Description:
 *   
 */

import 'package:flutter/material.dart';

import '../models/app_notification.dart';

class NotificationBanner extends StatelessWidget {
  final AppNotification notification;

  const NotificationBanner({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.notifications),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(notification.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}