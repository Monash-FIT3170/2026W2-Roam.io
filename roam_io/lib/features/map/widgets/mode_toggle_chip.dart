/*
 * Author: GitHub Copilot
 * Last Modified: 30/07/2026
 * Description:
 *   A pill-shaped chip widget that displays the current exploration mode and
 *   allows the user to toggle between modes by tapping. Shows a "Coming Soon"
 *   toast when switching to placeholder modes like Journey.
 */

import 'package:flutter/material.dart';

import '../domain/exploration_mode.dart';
import '../../../shared/widgets/app_toast.dart';

/// A tappable chip that shows the current exploration mode and cycles to
/// the next mode when tapped.
class ModeToggleChip extends StatelessWidget {
  const ModeToggleChip({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  /// The current exploration mode to display.
  final ExplorationMode currentMode;

  /// Callback invoked when the user taps to change the mode.
  final void Function(ExplorationMode newMode) onModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.94),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                currentMode.icon,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                currentMode.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.swap_horiz,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    final nextMode = currentMode.next;

    // Show a "Coming Soon" toast when switching to a placeholder mode
    if (nextMode.isPlaceholder) {
      AppToast.show(context, '${nextMode.label} mode coming soon!');
    }

    onModeChanged(nextMode);
  }
}
