/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 22 August 2026
 * Description:
 *   Defines the different categories of notifications supported by the app
 */

/// Categories used to classify notifications throughout the application.
///
/// A notification's type can be used to select its icon and other presentation behaviour.
enum NotificationType {
  /// User has received Glaze on an activity.
  kudos,

  /// Someone has commented on an activity.
  comment,

  /// Someone replied to a comment.
  commentReply,

  /// Someone liked a comment.
  commentLike,

  /// User has received a new friend request.
  friendRequest,

  /// A previously sent friend request has been accepted.
  friendAccepted,

  /// Someone followed the user on a public profile (in-app inbox + banner).
  follow,

  /// Someone requested to follow a private account.
  followRequest,

  /// A private-account follow request was accepted.
  followRequestAccepted,

  /// An application or activity error occurred.
  error,

  /// Notifications relating to a live activity (walk, ride, etc.).
  activity,

  /// Warning that explored map regions will soon become fogged again.
  fogDecay,
}
