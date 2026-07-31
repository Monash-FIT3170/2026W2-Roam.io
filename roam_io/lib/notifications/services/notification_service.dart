/*
 * Author: Sam Sutherland
 * Last Modified: 31/07/2026
 * Description:
 *   Handles all notifications within the application. Every feature should communicate 
 * through this service rather than displaying notifications directly.
 */

import 'dart:async';

import '../models/app_notification.dart';


class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final StreamController<AppNotification> _controller =
      StreamController<AppNotification>.broadcast();

  /// Stream listened to by the UI.
  Stream<AppNotification> get notifications => _controller.stream;

  /// Displays a notification.
  Future<void> show(AppNotification notification) async {
    // Notify in-app listeners.
    _controller.add(notification);

    // Temporary debugging.
    print('[Notification] ${notification.title}');
  }

  /// Dispose of resources.
  void dispose() {
    _controller.close();
  }
}