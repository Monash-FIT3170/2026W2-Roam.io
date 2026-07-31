/*
 * Author: Sam Sutherland
 * Last Modified: 31/07/2026
 * Description:
 *   Defines the different categories of notifications supported by the app
 */

enum NotificationType {
  /// User has received Kudos on an activity.
  kudos,

  /// Someone has commented on an activity.
  comment,

  /// User has received a new friend request.
  friendRequest,

  /// A previously sent friend request has been accepted.
  friendAccepted,

  /// An application or activity error occurred.
  error,

  /// Notifications relating to a live activity (walk, ride, etc.).
  activity,
}