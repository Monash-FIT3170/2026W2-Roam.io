/*
 * Author: Sam Sutherland
 * Last Modified: 31/07/2026
 * Description:
 *   Outlines the different notification templates used throughout the application. 
 *   Each template corresponds to a specific notification type and provides a consistent structure.
 */

import '../models/app_notification.dart';
import '../models/notification_action.dart';
import '../models/notification_type.dart';

class NotificationTemplates {
  NotificationTemplates._();

  static AppNotification friendRequest(String username) {
    return AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.friendRequest,
      title: 'New Friend Request',
      body: '$username sent you a friend request.',
      timestamp: DateTime.now(),
      actions: const [
        NotificationAction(
          type: NotificationActionType.accept,
          label: 'Accept',
        ),
        NotificationAction(
          type: NotificationActionType.decline,
          label: 'Decline',
        ),
      ],
    );
  }

  static AppNotification friendAccepted(String username) {
    return AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.friendAccepted,
      title: 'Friend Request Accepted',
      body: '$username accepted your friend request.',
      timestamp: DateTime.now(),
    );
  }

  static AppNotification kudos(String username) {
    return AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.kudos,
      title: 'Kudos Received',
      body: '$username gave you Kudos.',
      timestamp: DateTime.now(),
    );
  }

  static AppNotification comment(String username) {
    return AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.comment,
      title: 'New Comment',
      body: '$username commented on your activity.',
      timestamp: DateTime.now(),
    );
  }

  static AppNotification error(String message) {
    return AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.error,
      title: 'Something went wrong',
      body: message,
      timestamp: DateTime.now(),
      showOnDevice: false,
    );
  }

  static AppNotification activity({
    required String title,
    required String body,
  }) {
    return AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.activity,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      actions: const [
        NotificationAction(
          type: NotificationActionType.pause,
          label: 'Pause',
        ),
        NotificationAction(
          type: NotificationActionType.stop,
          label: 'Stop',
        ),
      ],
    );
  }
}