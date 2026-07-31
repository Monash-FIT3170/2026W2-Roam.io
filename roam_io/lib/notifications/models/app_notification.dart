/*
 * Author: Sam Sutherland
 * Last Modified: 31/07/2026
 * Description:
 *   Represents a notification within the application.
 */

import 'notification_action.dart';
import 'notification_type.dart';

class AppNotification {
  /// Unique identifier.
  final String id;

  /// Notification category.
  final NotificationType type;

  /// Notification heading.
  final String title;

  /// Notification message.
  final String body;

  /// Time the notification was created.
  final DateTime timestamp;

  /// Determines whether this notification appears inside the app.
  final bool showInApp;

  /// Determines whether this notification should be displayed as a
  /// device notification.
  final bool showOnDevice;

  /// Optional buttons/actions associated with this notification.
  final List<NotificationAction> actions;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.showInApp = true,
    this.showOnDevice = true,
    this.actions = const [],
  });
}