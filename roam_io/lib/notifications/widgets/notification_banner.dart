/*
 * Author: Sam Sutherland
 * Last Modified: 31/07/2026
 * Description:
 *   
 */

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/notification_action.dart';
import '../models/notification_type.dart';

class NotificationBanner extends StatelessWidget {
  final AppNotification notification;

  /// Called when the main body of the notification is selected.
  final VoidCallback? onTap;

  /// Called when an action button is selected.
  final ValueChanged<NotificationAction>? onActionSelected;

  /// Called when the close button is selected.
  final VoidCallback? onDismiss;

  const NotificationBanner({
    super.key,
    required this.notification,
    this.onTap,
    this.onActionSelected,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colourScheme = theme.colorScheme;

    return Semantics(
      label: '${notification.title}. ${notification.body}',
      container: true,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: colourScheme.surface,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colourScheme.outlineVariant,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NotificationIcon(type: notification.type),
                const SizedBox(width: 12),
                Expanded(
                  child: _NotificationContent(
                    notification: notification,
                    onActionSelected: onActionSelected,
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss notification',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationContent extends StatelessWidget {
  final AppNotification notification;
  final ValueChanged<NotificationAction>? onActionSelected;

  const _NotificationContent({
    required this.notification,
    this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notification.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          notification.body,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        if (notification.actions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: notification.actions.map((action) {
              return _NotificationActionButton(
                action: action,
                onPressed: onActionSelected == null
                    ? null
                    : () => onActionSelected!(action),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _NotificationActionButton extends StatelessWidget {
  final NotificationAction action;
  final VoidCallback? onPressed;

  const _NotificationActionButton({
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary = switch (action.type) {
      NotificationActionType.accept ||
      NotificationActionType.resume ||
      NotificationActionType.retry =>
        true,
      _ => false,
    };

    if (isPrimary) {
      return FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(action.label),
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(action.label),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  final NotificationType type;

  const _NotificationIcon({
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final colourScheme = Theme.of(context).colorScheme;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colourScheme.secondaryContainer,
      ),
      child: Icon(
        _iconFor(type),
        color: colourScheme.onSecondaryContainer,
      ),
    );
  }

  IconData _iconFor(NotificationType type) {
    return switch (type) {
      NotificationType.kudos => Icons.favorite_outline,
      NotificationType.comment => Icons.chat_bubble_outline,
      NotificationType.friendRequest => Icons.person_add_alt_1,
      NotificationType.friendAccepted => Icons.people_outline,
      NotificationType.error => Icons.error_outline,
      NotificationType.activity => Icons.directions_walk,
    };
  }
}