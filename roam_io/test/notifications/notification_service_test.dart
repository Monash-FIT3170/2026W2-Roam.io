/*
 * Author: Sam Sutherland
 * Last Modified: 01/08/2026
 * Description:
 *   Tests the central NotificationService action stream to ensure user
 *   interactions are emitted as NotificationActionEvent objects.
 */

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/notifications/notification.dart';
import 'package:roam_io/notifications/services/app_lifecycle_service.dart';

void main() {
  // Initialises the Flutter test environment required by services that use
  // Flutter bindings, lifecycle state or platform-aware functionality.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService', () {
    test('show emits in-app notification while app is foregrounded', () async {
      AppLifecycleService.instance.didChangeAppLifecycleState(
        AppLifecycleState.resumed,
      );
      final notification = AppNotification(
        id: 'foreground-notification',
        type: NotificationType.kudos,
        title: 'Glaze Received',
        body: 'Alex gave you Glaze.',
        timestamp: DateTime(2026, 8, 1),
      );

      final eventFuture = NotificationService.instance.notifications.first;

      await NotificationService.instance.show(notification);

      final event = await eventFuture;

      expect(event, same(notification));
    });

    test('handleAction emits a NotificationActionEvent', () async {
      // Arrange: create a notification and an associated action.
      final notification = AppNotification(
        id: 'request-notification',
        type: NotificationType.friendRequest,
        title: 'New Friend Request',
        body: 'Alex sent you a friend request.',
        timestamp: DateTime(2026, 8, 1),
      );

      const action = NotificationAction(
        type: NotificationActionType.accept,
        label: 'Accept',
      );

      // Begin listening before emitting the event so it is not missed by
      // the broadcast stream.
      final eventFuture = NotificationService.instance.actionEvents.first;

      // Act: report that the action was selected.
      NotificationService.instance.handleAction(
        notification: notification,
        action: action,
      );

      final event = await eventFuture;

      // Assert: the emitted event should contain the original objects.
      expect(event.notification, same(notification));
      expect(event.action, same(action));
      expect(event.action.type, NotificationActionType.accept);
    });

    test('handleAction supports different action types', () async {
      final notification = AppNotification(
        id: 'activity-notification',
        type: NotificationType.activity,
        title: 'Morning Walk',
        body: 'Activity running.',
        timestamp: DateTime(2026, 8, 1),
      );

      const action = NotificationAction(
        type: NotificationActionType.pause,
        label: 'Pause',
      );

      final eventFuture = NotificationService.instance.actionEvents.first;

      NotificationService.instance.handleAction(
        notification: notification,
        action: action,
      );

      final event = await eventFuture;

      expect(event.notification.id, 'activity-notification');
      expect(event.action.type, NotificationActionType.pause);
      expect(event.action.label, 'Pause');
    });

    test('handleTap emits a NotificationTapEvent', () async {
      final notification = AppNotification(
        id: 'tap-notification',
        type: NotificationType.comment,
        title: 'New Comment',
        body: 'Alex commented on your activity.',
        timestamp: DateTime(2026, 8, 1),
      );

      final eventFuture = NotificationService.instance.tapEvents.first;

      NotificationService.instance.handleTap(notification: notification);

      final event = await eventFuture;

      expect(event.notification, same(notification));
      expect(event.notification.id, 'tap-notification');
    });
  });
}
