/*
 * Author: Sam Sutherland
 * Last Modified: 31/07/2026
 * Description:
 *   The available actions that can be attached to a notification.
 */

enum NotificationActionType {
  open,
  accept,
  decline,
  pause,
  resume,
  stop,
  retry,
  dismiss,
}

/// Represents a single button/action available on a notification.
class NotificationAction {
  final NotificationActionType type;

  /// Text shown to the user.
  final String label;

  const NotificationAction({
    required this.type,
    required this.label,
  });
}