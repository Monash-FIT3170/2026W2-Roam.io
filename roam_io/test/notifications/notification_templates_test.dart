/*
 * Author: Sam Sutherland
 * Last Modified: 01/08/2026
 * Description:
 *   Tests the reusable notification templates to ensure each template
 *   produces the expected type, content, actions, duration and metadata.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/notifications/notification.dart';

void main() {
  group('NotificationTemplates', () {
    test('friendRequest creates the expected notification', () {
      // Act: create a friend-request notification with related IDs.
      final notification = NotificationTemplates.friendRequest(
        'Alex',
        friendRequestId: 'request-123',
        senderId: 'user-456',
      );

      // Assert: verify the notification content and presentation settings.
      expect(notification.type, NotificationType.friendRequest);
      expect(notification.title, 'New Friend Request');
      expect(notification.body, 'Alex sent you a friend request.');
      expect(notification.displayDuration, const Duration(seconds: 7));

      // Friend requests should provide Accept and Decline actions.
      expect(notification.actions, hasLength(2));
      expect(notification.actions[0].type, NotificationActionType.accept);
      expect(notification.actions[1].type, NotificationActionType.decline);

      // Metadata should identify the related request and sender.
      expect(notification.data['friendRequestId'], 'request-123');
      expect(notification.data['senderId'], 'user-456');
    });

    test('friendRequest omits optional metadata when not supplied', () {
      // Act: create a friend request without feature-specific identifiers.
      final notification = NotificationTemplates.friendRequest('Alex');

      // Assert: no empty or null metadata entries should be added.
      expect(notification.data, isEmpty);
    });

    test('friendAccepted creates the expected notification', () {
      final notification = NotificationTemplates.friendAccepted('Alex');

      expect(notification.type, NotificationType.friendAccepted);
      expect(notification.title, 'Friend Request Accepted');
      expect(notification.body, 'Alex accepted your friend request.');
      expect(notification.actions, isEmpty);
    });

    test('kudos creates a short notification', () {
      final notification = NotificationTemplates.kudos('Alex');

      expect(notification.type, NotificationType.kudos);
      expect(notification.title, 'Kudos Received');
      expect(notification.body, 'Alex gave you Kudos.');
      expect(notification.displayDuration, const Duration(seconds: 3));
    });

    test('comment creates the expected notification', () {
      final notification = NotificationTemplates.comment('Alex');

      expect(notification.type, NotificationType.comment);
      expect(notification.title, 'New Comment');
      expect(notification.body, 'Alex commented on your activity.');
    });

    test('error creates retry and dismiss actions', () {
      final notification = NotificationTemplates.error(
        'Unable to upload activity.',
      );

      expect(notification.type, NotificationType.error);
      expect(notification.title, 'Something went wrong');
      expect(notification.body, 'Unable to upload activity.');

      // Application errors are currently restricted to in-app display.
      expect(notification.showOnDevice, isFalse);
      expect(notification.displayDuration, const Duration(seconds: 6));

      expect(notification.actions, hasLength(2));
      expect(notification.actions[0].type, NotificationActionType.retry);
      expect(notification.actions[1].type, NotificationActionType.dismiss);
    });

    test('activity creates pause and stop actions', () {
      final notification = NotificationTemplates.activity(
        title: 'Morning Walk',
        body: 'Activity is currently running.',
      );

      expect(notification.type, NotificationType.activity);
      expect(notification.title, 'Morning Walk');
      expect(notification.body, 'Activity is currently running.');

      expect(notification.actions, hasLength(2));
      expect(notification.actions[0].type, NotificationActionType.pause);
      expect(notification.actions[1].type, NotificationActionType.stop);
    });

    test('generated notification IDs are not empty', () {
      final notification = NotificationTemplates.kudos('Alex');

      expect(notification.id, isNotEmpty);
    });

    test('sequential templates generate different IDs', () {
      final first = NotificationTemplates.kudos('Alex');
      final second = NotificationTemplates.comment('Jordan');

      expect(first.id, isNot(equals(second.id)));
    });
  });
}
