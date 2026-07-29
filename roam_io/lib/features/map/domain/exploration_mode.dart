/*
 * Author: GitHub Copilot
 * Last Modified: 30/07/2026
 * Description:
 *   Defines the exploration modes available on the map page. Users can switch
 *   between modes to change how they interact with the map and unlock tiles.
 */

import 'package:flutter/material.dart';

/// The available modes for map exploration.
enum ExplorationMode {
  /// Default mode - freely explore and unlock tiles by visiting locations.
  exploration,

  /// Journey mode - follow a planned route (placeholder for future implementation).
  journey,
}

/// Extension methods for [ExplorationMode] to provide display properties.
extension ExplorationModeExtension on ExplorationMode {
  /// Returns the display label for this mode.
  String get label {
    switch (this) {
      case ExplorationMode.exploration:
        return 'Exploration';
      case ExplorationMode.journey:
        return 'Journey';
    }
  }

  /// Returns the icon for this mode.
  IconData get icon {
    switch (this) {
      case ExplorationMode.exploration:
        return Icons.explore;
      case ExplorationMode.journey:
        return Icons.route;
    }
  }

  /// Returns the next mode in the cycle.
  ExplorationMode get next {
    switch (this) {
      case ExplorationMode.exploration:
        return ExplorationMode.journey;
      case ExplorationMode.journey:
        return ExplorationMode.exploration;
    }
  }

  /// Returns whether this mode is a placeholder (not yet fully implemented).
  bool get isPlaceholder {
    switch (this) {
      case ExplorationMode.exploration:
        return false;
      case ExplorationMode.journey:
        return true;
    }
  }
}
