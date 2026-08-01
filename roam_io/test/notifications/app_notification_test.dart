/*
 * Author: Sam Sutherland
 * Last Modified: 01/08/2026
 * Description:
 *   Tests the AppNotification data model, including its default values,
 *   configurable visibility settings, display duration, actions and metadata.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/notifications/notification.dart';

void main() {
  group('AppNotification', () {
    test('uses expected default values', () {
      // Arrange and act: create a notification using only required fields.
      final notification = AppNotification(
        id: 'notification-1',
        type: NotificationType.comment,
        title: 'New Comment',
        body: 'Alex commented on your activity.',
        timestamp: DateTime(2026, 8, 1),
      );

      // Assert: required fields should retain their supplied values.
      expect(notification.id, 'notification-1');
      expect(notification.type, NotificationType.comment);
      expect(notification.title, 'New Comment');
      expect(notification.body, 'Alex commented on your activity.');
      expect(notification.timestamp, DateTime(2026, 8, 1));

      // Assert: optional fields should use the model's default values.
      expect(notification.showInApp, isTrue);
      expect(notification.showOnDevice, isTrue);
      expect(
        notification.displayDuration,
        const Duration(seconds: 4),
      );
      expect(notification.actions, isEmpty);
      expect(notification.data, isEmpty);
    });

    test('stores custom configuration values', () {
      // Arrange: define an action associated with a friend request.
      const action = NotificationAction(
        type: NotificationActionType.accept,
        label: 'Accept',
      );

      // Act: create a notification with custom presentation settings,
      // actions and feature-specific metadata.
      final notification = AppNotification(
        id: 'notification-2',
        type: NotificationType.friendRequest,
        title: 'New Friend Request',
        body: 'Alex sent you a friend request.',
        timestamp: DateTime(2026, 8, 1),
        showInApp: false,
        showOnDevice: true,
        displayDuration: const Duration(seconds: 7),
        actions: const [action],
        data: const {
          'friendRequestId': 'request-123',
          'senderId': 'user-456',
        },
      );

      // Assert: custom configuration should be stored unchanged.
      expect(notification.showInApp, isFalse);
      expect(notification.showOnDevice, isTrue);
      expect(
        notification.displayDuration,
        const Duration(seconds: 7),
      );

      expect(notification.actions, hasLength(1));
      expect(
        notification.actions.first.type,
        NotificationActionType.accept,
      );

      expect(
        notification.data['friendRequestId'],
        'request-123',
      );
      expect(notification.data['senderId'], 'user-456');
    });
  });
}