/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
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

/// Represents an action selected from an application notification.
class NotificationActionEvent {
  /// Notification from which the action originated.
  final AppNotification notification;

  /// Action selected by the user.
  final NotificationAction action;

  const NotificationActionEvent({
    required this.notification,
    required this.action,
  });
}

/// Represents a notification body tap from the in-app banner.
class NotificationTapEvent {
  /// Notification selected by the user.
  final AppNotification notification;

  const NotificationTapEvent({required this.notification});
}

/// Service that manages notifications within the application.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final StreamController<AppNotification> _notificationController =
      StreamController<AppNotification>.broadcast();

  final StreamController<NotificationActionEvent> _actionController =
      StreamController<NotificationActionEvent>.broadcast();

  final StreamController<NotificationTapEvent> _tapController =
      StreamController<NotificationTapEvent>.broadcast();

  /// Notifications consumed by the in-app overlay.
  Stream<AppNotification> get notifications => _notificationController.stream;

  /// Actions selected from notification banners.
  Stream<NotificationActionEvent> get actionEvents => _actionController.stream;

  /// Body taps selected from notification banners.
  Stream<NotificationTapEvent> get tapEvents => _tapController.stream;

  /// Sends a notification to the appropriate presentation layers.
  Future<void> show(AppNotification notification) async {
    debugPrint(
      '[Notification] ${notification.type.name}: '
      '${notification.title}',
    );

    final isForeground = AppLifecycleService.instance.isInForeground;

    if (notification.showInApp && isForeground) {
      _notificationController.add(notification);
    }

    // iOS can explicitly present a local notification banner while the app is
    // in the foreground. Keeping this enabled makes device-level notification
    // delivery observable and usable on iOS while retaining Android's existing
    // background-only system-notification behaviour.
    final shouldShowOnDevice =
        notification.showOnDevice &&
        (!isForeground ||
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS));

    if (shouldShowOnDevice) {
      await AndroidNotificationService.instance.show(notification);
    }

    // Old version, showing android notifications even when app is in foreground
    // if (notification.showInApp) {
    //   _notificationController.add(notification);
    // }

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
      NotificationActionEvent(notification: notification, action: action),
    );
  }

  /// Reports that the body of an in-app notification was selected.
  void handleTap({required AppNotification notification}) {
    debugPrint(
      '[Notification tap] ${notification.type.name} ${notification.id}',
    );
    _tapController.add(NotificationTapEvent(notification: notification));
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _notificationController.close();
    await _actionController.close();
    await _tapController.close();
  }
}
