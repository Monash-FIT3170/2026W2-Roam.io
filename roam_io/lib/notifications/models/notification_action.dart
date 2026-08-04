/*
 * Author: Sam Sutherland
 * Last Modified: 31/07/2026
 * Description:
 *   The available actions that can be attached to a notification.
 */

enum NotificationActionType {
  /// Opens the related content.
  open,

  /// Accepts a pending request.
  accept,

  /// Declines a pending request.
  decline,

  /// Pauses an active journey or activity.
  pause,

  /// Resumes a paused journey or activity.
  resume,

  /// Stops an active journey or activity.
  stop,

  /// Attempts the failed operation again.
  retry,

  /// Dismisses the notification.
  dismiss,
}

/// Represents an action button displayed on a notification.
///
/// Notification actions allow the user to respond directly from either
/// the in-app notification banner or an Android device notification
/// without navigating through the application.
class NotificationAction {
  final NotificationActionType type;

  /// Text shown to the user.
  final String label;

  const NotificationAction({required this.type, required this.label});
}
