/*
 * Author: Sam Sutherland
 * Last Modified: 31/07/2026
 * Description:
 *   Handles all notifications within the application. Every feature should communicate 
 * through this service rather than displaying notifications directly.
 */

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../models/notification_action.dart';
import 'package:roam_io/notifications/services/android_notification_service.dart';
import 'package:roam_io/notifications/services/app_lifecycle_service.dart';

/// Contains the notification and the action selected by the user.
class NotificationActionEvent {
  final AppNotification notification;
  final NotificationAction action;

  const NotificationActionEvent({
    required this.notification,
    required this.action,
  });
}

/// Service that manages notifications within the application.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final StreamController<AppNotification> _notificationController =
      StreamController<AppNotification>.broadcast();

  final StreamController<NotificationActionEvent> _actionController =
      StreamController<NotificationActionEvent>.broadcast();

  /// Notifications consumed by the in-app overlay.
  Stream<AppNotification> get notifications =>
      _notificationController.stream;

  /// Actions selected from notification banners.
  Stream<NotificationActionEvent> get actionEvents =>
      _actionController.stream;

  /// Sends a notification to the appropriate presentation layers.
  Future<void> show(AppNotification notification) async {
    debugPrint(
      '[Notification] ${notification.type.name}: '
      '${notification.title}',
    );

    final isForeground =
      AppLifecycleService.instance.isInForeground;

    if (notification.showInApp && isForeground) {
      _notificationController.add(notification);
    }

    if (notification.showOnDevice && !isForeground) {
      await AndroidNotificationService.instance.show(notification);
    }

    // Old version, showing android notifications even when app is in foreground
    // if (notification.showInApp) {
    //   _notificationController.add(notification);
    // }
    // 
    // if (notification.showOnDevice) {
    //   await AndroidNotificationService.instance.show(notification);
    // }
  }

  /// Reports that an action was selected from a notification.
  void handleAction({
    required AppNotification notification,
    required NotificationAction action,
  }) {
    debugPrint(
      '[Notification action] ${action.type.name} '
      'for notification ${notification.id}',
    );

    _actionController.add(
      NotificationActionEvent(
        notification: notification,
        action: action,
      ),
    );
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _notificationController.close();
    await _actionController.close();
  }
}