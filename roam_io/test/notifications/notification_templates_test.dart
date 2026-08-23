/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
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

    test('kudos creates a short Glaze notification', () {
      final notification = NotificationTemplates.kudos('Alex');

      expect(notification.type, NotificationType.kudos);
      expect(notification.title, 'Glaze Received');
      expect(notification.body, 'Alex gave you Glaze.');
      expect(notification.displayDuration, const Duration(seconds: 3));
    });

    test('comment creates the expected notification', () {
      final notification = NotificationTemplates.comment('Alex');

      expect(notification.type, NotificationType.comment);
      expect(notification.title, 'New Comment');
      expect(notification.body, 'Alex commented on your activity.');
    });

    test('activity interaction templates use distinct types and copy', () {
      final kudos = NotificationTemplates.activityKudos('Nathan');
      final comment = NotificationTemplates.activityComment('Nathan');
      final threadReply = NotificationTemplates.activityThreadReply('Nathan');
      final reply = NotificationTemplates.commentReply('Nathan');
      final commentLike = NotificationTemplates.commentLike('Nathan');

      expect(kudos.type, NotificationType.kudos);
      expect(kudos.body, 'Nathan gave Glaze to your activity');
      expect(comment.type, NotificationType.comment);
      expect(comment.body, 'Nathan commented on your activity');
      expect(threadReply.type, NotificationType.commentReply);
      expect(threadReply.body, 'Nathan replied to your comment');
      expect(reply.type, NotificationType.commentReply);
      expect(reply.body, 'Nathan replied to your comment');
      expect(commentLike.type, NotificationType.commentLike);
      expect(commentLike.body, 'Nathan liked your comment');
    });

    test('activity interaction templates include supplied metadata', () {
      final kudos = NotificationTemplates.activityKudos(
        'Nathan',
        notificationId: 'notification-1',
        actorId: 'actor-1',
        activityId: 'activity-1',
      );
      final comment = NotificationTemplates.activityComment(
        'Maya',
        notificationId: 'notification-2',
        actorId: 'actor-2',
        activityId: 'activity-2',
        commentId: 'comment-2',
      );
      final threadReply = NotificationTemplates.activityThreadReply(
        'Priya',
        notificationId: 'notification-3',
        actorId: 'actor-3',
        activityId: 'activity-3',
        commentId: 'comment-3',
      );
      final reply = NotificationTemplates.commentReply(
        'Liam',
        notificationId: 'notification-4',
        actorId: 'actor-4',
        activityId: 'activity-4',
        commentId: 'comment-4',
      );
      final commentLike = NotificationTemplates.commentLike(
        'Sofia',
        notificationId: 'notification-5',
        actorId: 'actor-5',
        activityId: 'activity-5',
        commentId: 'comment-5',
      );

      expect(kudos.id, 'notification-1');
      expect(kudos.showOnDevice, isFalse);
      expect(kudos.data['actorId'], 'actor-1');
      expect(kudos.data['activityId'], 'activity-1');

      expect(comment.id, 'notification-2');
      expect(comment.data['commentId'], 'comment-2');
      expect(threadReply.id, 'notification-3');
      expect(threadReply.data['commentId'], 'comment-3');
      expect(reply.id, 'notification-4');
      expect(reply.data['commentId'], 'comment-4');
      expect(commentLike.id, 'notification-5');
      expect(commentLike.data['commentId'], 'comment-5');
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

    test('followedYou creates an in-app follow notification', () {
      final notification = NotificationTemplates.followedYou(
        'Alex',
        notificationId: 'follow-notification',
        actorId: 'follower-123',
      );

      expect(notification.id, 'follow-notification');
      expect(notification.type, NotificationType.follow);
      expect(notification.title, 'New Follower');
      expect(notification.body, 'Alex followed you');
      expect(notification.showOnDevice, isFalse);
      expect(notification.displayDuration, const Duration(seconds: 5));
      expect(notification.data['actorId'], 'follower-123');
    });

    test('followedYou generates an ID when notificationId is omitted', () {
      final notification = NotificationTemplates.followedYou('Alex');

      expect(notification.id, isNotEmpty);
      expect(notification.type, NotificationType.follow);
      expect(notification.data, isEmpty);
    });

    test('followSummary clamps invalid counts to one', () {
      final notification = NotificationTemplates.followSummary(0);

      expect(notification.id, startsWith('follow-summary-'));
      expect(notification.type, NotificationType.follow);
      expect(notification.title, 'New Followers');
      expect(notification.body, '1 people followed you');
      expect(notification.showOnDevice, isFalse);
      expect(notification.displayDuration, const Duration(seconds: 6));
      expect(notification.data['followSummaryCount'], '1');
    });

    test('followSummary uses supplied positive count', () {
      final notification = NotificationTemplates.followSummary(4);

      expect(notification.body, '4 people followed you');
      expect(notification.data['followSummaryCount'], '4');
    });

    test('followRequest creates actionable request notification', () {
      final notification = NotificationTemplates.followRequest(
        'Jordan',
        notificationId: 'request-notification',
        requestId: 'request-123',
        requesterId: 'requester-456',
      );

      expect(notification.id, 'request-notification');
      expect(notification.type, NotificationType.followRequest);
      expect(notification.title, 'Follow Request');
      expect(notification.body, 'Jordan requested to follow you');
      expect(notification.showOnDevice, isFalse);
      expect(notification.displayDuration, const Duration(seconds: 7));
      expect(notification.actions, hasLength(2));
      expect(notification.actions[0].type, NotificationActionType.accept);
      expect(notification.actions[1].type, NotificationActionType.decline);
      expect(notification.data['requestId'], 'request-123');
      expect(notification.data['requesterId'], 'requester-456');
    });

    test('followRequest generates an ID when notificationId is omitted', () {
      final notification = NotificationTemplates.followRequest('Jordan');

      expect(notification.id, isNotEmpty);
      expect(notification.type, NotificationType.followRequest);
      expect(notification.data, isEmpty);
    });

    test('followRequestAccepted creates accepted notification', () {
      final notification = NotificationTemplates.followRequestAccepted(
        'Casey',
        notificationId: 'accepted-notification',
        actorId: 'actor-789',
      );

      expect(notification.id, 'accepted-notification');
      expect(notification.type, NotificationType.followRequestAccepted);
      expect(notification.title, 'Follow Request Accepted');
      expect(notification.body, 'Casey accepted your follow request');
      expect(notification.showOnDevice, isFalse);
      expect(notification.displayDuration, const Duration(seconds: 5));
      expect(notification.data['actorId'], 'actor-789');
    });

    test(
      'followRequestAccepted generates an ID when notificationId is omitted',
      () {
        final notification = NotificationTemplates.followRequestAccepted(
          'Casey',
        );

        expect(notification.id, isNotEmpty);
        expect(notification.type, NotificationType.followRequestAccepted);
        expect(notification.data, isEmpty);
      },
    );

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
