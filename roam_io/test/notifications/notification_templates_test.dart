/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 31 August 2026
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
      expect(notification.showInApp, isTrue);
      expect(notification.showOnDevice, isTrue);
      expect(notification.displayDuration, const Duration(seconds: 7));

      // Friend requests should provide Accept and Decline actions.
      expect(notification.actions, hasLength(2));
      expect(notification.actions[0].type, NotificationActionType.accept);
      expect(notification.actions[0].label, 'Accept');
      expect(notification.actions[1].type, NotificationActionType.decline);
      expect(notification.actions[1].label, 'Decline');

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
      expect(notification.showOnDevice, isTrue);
      expect(notification.actions, isEmpty);
    });

    test('kudos creates a short Glaze notification', () {
      final notification = NotificationTemplates.kudos('Alex');

      expect(notification.type, NotificationType.kudos);
      expect(notification.title, 'Glaze Received');
      expect(notification.body, 'Alex gave you Glaze.');
      expect(notification.showOnDevice, isTrue);
      expect(notification.displayDuration, const Duration(seconds: 3));
    });

    test('comment creates the expected notification', () {
      final notification = NotificationTemplates.comment('Alex');

      expect(notification.type, NotificationType.comment);
      expect(notification.title, 'New Comment');
      expect(notification.body, 'Alex commented on your activity.');
      expect(notification.showOnDevice, isTrue);
    });

    test('activity interaction templates use distinct types and copy', () {
      final kudos = NotificationTemplates.activityKudos('Nathan');
      final comment = NotificationTemplates.activityComment('Maya');
      final reply = NotificationTemplates.commentReply('Liam');
      final commentLike = NotificationTemplates.commentLike('Sofia');

      expect(kudos.type, NotificationType.kudos);
      expect(kudos.body, 'Nathan gave Glaze to your activity');

      expect(comment.type, NotificationType.comment);
      expect(comment.body, 'Maya commented on your activity');

      expect(reply.type, NotificationType.commentReply);
      expect(reply.body, 'Liam replied to your comment');

      expect(commentLike.type, NotificationType.commentLike);
      expect(commentLike.body, 'Sofia liked your comment');
    });

    test('activity interaction templates include supplied metadata', () {
      final notifications = [
        NotificationTemplates.activityKudos(
          'Nathan',
          notificationId: 'notification-1',
          actorId: 'actor-1',
          activityId: 'activity-1',
        ),
        NotificationTemplates.activityComment(
          'Maya',
          notificationId: 'notification-2',
          actorId: 'actor-2',
          activityId: 'activity-2',
          commentId: 'comment-2',
        ),
        NotificationTemplates.commentReply(
          'Liam',
          notificationId: 'notification-3',
          actorId: 'actor-3',
          activityId: 'activity-3',
          commentId: 'comment-3',
        ),
        NotificationTemplates.commentLike(
          'Sofia',
          notificationId: 'notification-4',
          actorId: 'actor-4',
          activityId: 'activity-4',
          commentId: 'comment-4',
        ),
      ];

      for (final notification in notifications) {
        expect(notification.showInApp, isTrue);
        expect(notification.showOnDevice, isTrue);
        expect(notification.displayDuration, const Duration(seconds: 5));
        expect(notification.data['notificationId'], isNotNull);
        expect(notification.data['actorId'], isNotNull);
        expect(notification.data['activityId'], isNotNull);
      }

      expect(notifications[0].id, 'notification-1');
      expect(notifications[1].data['commentId'], 'comment-2');
      expect(notifications[2].data['commentId'], 'comment-3');
      expect(notifications[3].data['commentId'], 'comment-4');
    });

    test('activityThreadReply creates a reply notification', () {
      final notification = NotificationTemplates.activityThreadReply(
        'Priya',
        notificationId: 'notification-reply',
        actorId: 'actor-1',
        activityId: 'activity-1',
        commentId: 'comment-1',
      );

      expect(notification.id, 'notification-reply');
      expect(notification.type, NotificationType.commentReply);
      expect(notification.title, 'New Reply');
      expect(notification.body, 'Priya replied to your comment');
      expect(notification.showOnDevice, isTrue);
      expect(notification.displayDuration, const Duration(seconds: 5));
      expect(notification.data['actorId'], 'actor-1');
      expect(notification.data['activityId'], 'activity-1');
      expect(notification.data['commentId'], 'comment-1');
    });

    test('error creates retry and dismiss actions', () {
      final notification = NotificationTemplates.error(
        'Unable to upload activity.',
      );

      expect(notification.type, NotificationType.error);
      expect(notification.title, 'Something went wrong');
      expect(notification.body, 'Unable to upload activity.');

      // Application errors intentionally remain in-app only.
      expect(notification.showInApp, isTrue);
      expect(notification.showOnDevice, isFalse);
      expect(notification.displayDuration, const Duration(seconds: 6));

      expect(notification.actions, hasLength(2));
      expect(notification.actions[0].type, NotificationActionType.retry);
      expect(notification.actions[0].label, 'Retry');
      expect(notification.actions[1].type, NotificationActionType.dismiss);
      expect(notification.actions[1].label, 'Dismiss');
    });

    test('activity creates pause and stop actions', () {
      final notification = NotificationTemplates.activity(
        title: 'Morning Walk',
        body: 'Activity is currently running.',
      );

      expect(notification.type, NotificationType.activity);
      expect(notification.title, 'Morning Walk');
      expect(notification.body, 'Activity is currently running.');
      expect(notification.showOnDevice, isTrue);

      expect(notification.actions, hasLength(2));
      expect(notification.actions[0].type, NotificationActionType.pause);
      expect(notification.actions[0].label, 'Pause');
      expect(notification.actions[1].type, NotificationActionType.stop);
      expect(notification.actions[1].label, 'Stop');
    });

    test('followedYou creates a follow notification', () {
      final notification = NotificationTemplates.followedYou(
        'Alex',
        notificationId: 'follow-1',
        actorId: 'actor-1',
      );

      expect(notification.id, 'follow-1');
      expect(notification.type, NotificationType.follow);
      expect(notification.title, 'New Follower');
      expect(notification.body, 'Alex followed you');
      expect(notification.showInApp, isTrue);
      expect(notification.showOnDevice, isTrue);
      expect(notification.displayDuration, const Duration(seconds: 5));
      expect(notification.data['notificationId'], 'follow-1');
      expect(notification.data['actorId'], 'actor-1');
    });

    test('followSummary creates a summary notification', () {
      final notification = NotificationTemplates.followSummary(4);

      expect(notification.type, NotificationType.follow);
      expect(notification.title, 'New Followers');
      expect(notification.body, '4 people followed you');
      expect(notification.showInApp, isTrue);
      expect(notification.showOnDevice, isTrue);
      expect(notification.displayDuration, const Duration(seconds: 6));
      expect(notification.data['followSummaryCount'], '4');
    });

    test('followSummary clamps invalid counts to one', () {
      final notification = NotificationTemplates.followSummary(0);

      expect(notification.body, '1 people followed you');
      expect(notification.data['followSummaryCount'], '1');
      expect(notification.showOnDevice, isTrue);
    });

    test('followRequest creates actionable request notification', () {
      final notification = NotificationTemplates.followRequest(
        'Jordan',
        notificationId: 'follow-request-notification',
        requestId: 'request-123',
        requesterId: 'user-456',
      );

      expect(notification.id, 'follow-request-notification');
      expect(notification.type, NotificationType.followRequest);
      expect(notification.title, 'Follow Request');
      expect(notification.body, 'Jordan requested to follow you');
      expect(notification.showInApp, isTrue);
      expect(notification.showOnDevice, isTrue);
      expect(notification.displayDuration, const Duration(seconds: 7));

      expect(notification.actions, hasLength(2));
      expect(notification.actions[0].type, NotificationActionType.accept);
      expect(notification.actions[0].label, 'Accept');
      expect(notification.actions[1].type, NotificationActionType.decline);
      expect(notification.actions[1].label, 'Decline');

      expect(
        notification.data['notificationId'],
        'follow-request-notification',
      );
      expect(notification.data['requestId'], 'request-123');
      expect(notification.data['requesterId'], 'user-456');
    });

    test('followRequestAccepted creates accepted notification', () {
      final notification = NotificationTemplates.followRequestAccepted(
        'Casey',
        notificationId: 'accepted-notification',
        actorId: 'actor-1',
      );

      expect(notification.id, 'accepted-notification');
      expect(notification.type, NotificationType.followRequestAccepted);
      expect(notification.title, 'Follow Request Accepted');
      expect(notification.body, 'Casey accepted your follow request');
      expect(notification.showInApp, isTrue);
      expect(notification.showOnDevice, isTrue);
      expect(notification.displayDuration, const Duration(seconds: 5));
      expect(notification.data['notificationId'], 'accepted-notification');
      expect(notification.data['actorId'], 'actor-1');
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
