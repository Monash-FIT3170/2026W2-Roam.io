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

  /// Length of time an in-app notification remains visible.
  final Duration displayDuration;

  /// Optional buttons/actions associated with this notification.
  final List<NotificationAction> actions;

  /// Optional information used to connect the notification to another feature.
  /// e.g. which activity the notification relates to, or which user sent it.
  final Map<String, String> data;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.showInApp = true,
    this.showOnDevice = true,
    this.displayDuration = const Duration(seconds: 4),
    this.actions = const [],
    this.data = const {},
  });
}