import 'package:flutter/material.dart';

import 'quest_enums.dart';

/// A readable lifecycle label; colour is never the only status indicator.
class QuestStatusBadge extends StatelessWidget {
  const QuestStatusBadge({super.key, required this.status});

  final QuestStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, background, foreground) = switch (status) {
      QuestStatus.available => (
        Icons.explore_outlined,
        scheme.surfaceContainerHighest,
        scheme.onSurface,
      ),
      QuestStatus.active => (
        Icons.flag_outlined,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      QuestStatus.submitted => (
        Icons.hourglass_top_rounded,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      QuestStatus.completed => (
        Icons.check_circle_outline,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      QuestStatus.rejected => (
        Icons.error_outline,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      QuestStatus.expired => (
        Icons.event_busy_outlined,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              status.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
