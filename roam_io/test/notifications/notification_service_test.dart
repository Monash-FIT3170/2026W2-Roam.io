/*
 * Author: Sam Sutherland
 * Last Modified: 01/08/2026
 * Description:
 *   Tests the central NotificationService action stream to ensure user
 *   interactions are emitted as NotificationActionEvent objects.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/notifications/notification.dart';

void main() {
  // Initialises the Flutter test environment required by services that use
  // Flutter bindings, lifecycle state or platform-aware functionality.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService', () {
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
      final eventFuture =
          NotificationService.instance.actionEvents.first;

      // Act: report that the action was selected.
      NotificationService.instance.handleAction(
        notification: notification,
        action: action,
      );

      final event = await eventFuture;

      // Assert: the emitted event should contain the original objects.
      expect(event.notification, same(notification));
      expect(event.action, same(action));
      expect(
        event.action.type,
        NotificationActionType.accept,
      );
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

      final eventFuture =
          NotificationService.instance.actionEvents.first;

      NotificationService.instance.handleAction(
        notification: notification,
        action: action,
      );

      final event = await eventFuture;

      expect(
        event.notification.id,
        'activity-notification',
      );
      expect(
        event.action.type,
        NotificationActionType.pause,
      );
      expect(event.action.label, 'Pause');
    });
  });
}