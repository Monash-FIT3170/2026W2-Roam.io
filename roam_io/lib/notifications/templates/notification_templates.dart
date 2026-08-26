/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Outlines the different notification templates used throughout the application. 
 *   Each template corresponds to a specific notification type and provides a consistent structure.
 */

import '../models/app_notification.dart';
import '../models/notification_action.dart';
import '../models/notification_type.dart';

/// Factory collection for the notification types currently supported by the application.
class NotificationTemplates {
  NotificationTemplates._(); // coverage:ignore-line

  /// Creates a notification for a new friend request from [username].
  static AppNotification friendRequest(
    String username, {
    String? friendRequestId,
    String? senderId,
  }) {
    final now = DateTime.now();

    return AppNotification(
      id: now.microsecondsSinceEpoch.toString(),
      type: NotificationType.friendRequest,
      title: 'New Friend Request',
      body: '$username sent you a friend request.',
      timestamp: now,
      displayDuration: const Duration(seconds: 7),
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
      data: {'friendRequestId': ?friendRequestId, 'senderId': ?senderId},
    );
  }

  /// Creates a notification for when a friend request is accepted by [username].
  static AppNotification friendAccepted(String username) {
    return AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.friendAccepted,
      title: 'Friend Request Accepted',
      body: '$username accepted your friend request.',
      timestamp: DateTime.now(),
    );
  }

  /// Creates a brief notification indicating that [username] gave the user Glaze.
  static AppNotification kudos(String username) {
    final now = DateTime.now();

    return AppNotification(
      id: now.microsecondsSinceEpoch.toString(),
      type: NotificationType.kudos,
      title: 'Glaze Received',
      body: '$username gave you Glaze.',
      timestamp: now,
      displayDuration: const Duration(seconds: 3),
    );
  }

  static AppNotification activityKudos(
    String username, {
    String? notificationId,
    String? actorId,
    String? activityId,
  }) {
    final now = DateTime.now();

    return AppNotification(
      id: notificationId ?? now.microsecondsSinceEpoch.toString(),
      type: NotificationType.kudos,
      title: 'Glaze Received',
      body: '$username gave Glaze to your activity',
      timestamp: now,
      showOnDevice: false,
      displayDuration: const Duration(seconds: 5),
      data: {
        'notificationId': ?notificationId,
        'actorId': ?actorId,
        'activityId': ?activityId,
      },
    );
  }

  /// Creates a notification indicating that [username] commented on an activity.
  static AppNotification comment(String username) {
    return AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.comment,
      title: 'New Comment',
      body: '$username commented on your activity.',
      timestamp: DateTime.now(),
    );
  }

  static AppNotification activityComment(
    String username, {
    String? notificationId,
    String? actorId,
    String? activityId,
    String? commentId,
  }) {
    final now = DateTime.now();
    return AppNotification(
      id: notificationId ?? now.microsecondsSinceEpoch.toString(),
      type: NotificationType.comment,
      title: 'New Comment',
      body: '$username commented on your activity',
      timestamp: now,
      showOnDevice: false,
      displayDuration: const Duration(seconds: 5),
      data: {
        'notificationId': ?notificationId,
        'actorId': ?actorId,
        'activityId': ?activityId,
        'commentId': ?commentId,
      },
    );
  }

  static AppNotification activityThreadReply(
    String username, {
    String? notificationId,
    String? actorId,
    String? activityId,
    String? commentId,
  }) {
    final now = DateTime.now();
    return AppNotification(
      id: notificationId ?? now.microsecondsSinceEpoch.toString(),
      type: NotificationType.commentReply,
      title: 'New Reply',
      body: '$username replied to your comment',
      timestamp: now,
      showOnDevice: false,
      displayDuration: const Duration(seconds: 5),
      data: {
        'notificationId': ?notificationId,
        'actorId': ?actorId,
        'activityId': ?activityId,
        'commentId': ?commentId,
      },
    );
  }

  static AppNotification commentReply(
    String username, {
    String? notificationId,
    String? actorId,
    String? activityId,
    String? commentId,
  }) {
    final now = DateTime.now();
    return AppNotification(
      id: notificationId ?? now.microsecondsSinceEpoch.toString(),
      type: NotificationType.commentReply,
      title: 'New Reply',
      body: '$username replied to your comment',
      timestamp: now,
      showOnDevice: false,
      displayDuration: const Duration(seconds: 5),
      data: {
        'notificationId': ?notificationId,
        'actorId': ?actorId,
        'activityId': ?activityId,
        'commentId': ?commentId,
      },
    );
  }

  static AppNotification commentLike(
    String username, {
    String? notificationId,
    String? actorId,
    String? activityId,
    String? commentId,
  }) {
    final now = DateTime.now();
    return AppNotification(
      id: notificationId ?? now.microsecondsSinceEpoch.toString(),
      type: NotificationType.commentLike,
      title: 'Comment Liked',
      body: '$username liked your comment',
      timestamp: now,
      showOnDevice: false,
      displayDuration: const Duration(seconds: 5),
      data: {
        'notificationId': ?notificationId,
        'actorId': ?actorId,
        'activityId': ?activityId,
        'commentId': ?commentId,
      },
    );
  }

  /// Creates an in-app error notification containing [message].
  static AppNotification error(String message) {
    final now = DateTime.now();

    return AppNotification(
      id: now.microsecondsSinceEpoch.toString(),
      type: NotificationType.error,
      title: 'Something went wrong',
      body: message,
      timestamp: now,
      showOnDevice: false,
      displayDuration: const Duration(seconds: 6),
      actions: const [
        NotificationAction(type: NotificationActionType.retry, label: 'Retry'),
        NotificationAction(
          type: NotificationActionType.dismiss,
          label: 'Dismiss',
        ),
      ],
    );
  }

  /// Creates a live activity notification using the supplied [title] and [body].
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
        NotificationAction(type: NotificationActionType.pause, label: 'Pause'),
        NotificationAction(type: NotificationActionType.stop, label: 'Stop'),
      ],
    );
  }

  /// In-app banner when [username] follows the current user (public profiles).
  static AppNotification followedYou(
    String username, {
    String? notificationId,
    String? actorId,
  }) {
    final now = DateTime.now();
    return AppNotification(
      id: notificationId ?? now.microsecondsSinceEpoch.toString(),
      type: NotificationType.follow,
      title: 'New Follower',
      body: '$username followed you',
      timestamp: now,
      showOnDevice: false,
      displayDuration: const Duration(seconds: 5),
      data: {'notificationId': ?notificationId, 'actorId': ?actorId},
    );
  }

  /// Cold-start summary when multiple unread follow notifications exist.
  static AppNotification followSummary(int count) {
    final now = DateTime.now();
    final safeCount = count < 1 ? 1 : count;
    return AppNotification(
      id: 'follow-summary-${now.microsecondsSinceEpoch}',
      type: NotificationType.follow,
      title: 'New Followers',
      body: '$safeCount people followed you',
      timestamp: now,
      showOnDevice: false,
      displayDuration: const Duration(seconds: 6),
      data: {'followSummaryCount': '$safeCount'},
    );
  }

  /// In-app banner when [username] requests to follow the current user.
  static AppNotification followRequest(
    String username, {
    String? notificationId,
    String? requestId,
    String? requesterId,
  }) {
    final now = DateTime.now();
    return AppNotification(
      id: notificationId ?? now.microsecondsSinceEpoch.toString(),
      type: NotificationType.followRequest,
      title: 'Follow Request',
      body: '$username requested to follow you',
      timestamp: now,
      showOnDevice: false,
      displayDuration: const Duration(seconds: 7),
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
      data: {
        'notificationId': ?notificationId,
        'requestId': ?requestId,
        'requesterId': ?requesterId,
      },
    );
  }

  /// In-app banner when a private-account follow request is accepted.
  static AppNotification followRequestAccepted(
    String username, {
    String? notificationId,
    String? actorId,
  }) {
    final now = DateTime.now();
    return AppNotification(
      id: notificationId ?? now.microsecondsSinceEpoch.toString(),
      type: NotificationType.followRequestAccepted,
      title: 'Follow Request Accepted',
      body: '$username accepted your follow request',
      timestamp: now,
      showOnDevice: false,
      displayDuration: const Duration(seconds: 5),
      data: {'notificationId': ?notificationId, 'actorId': ?actorId},
    );
  }
}
