/*
 * Author: GitHub Copilot
 * Last Modified: 30/07/2026
 * Description:
 *   Defines the transport modes available for journeys. Each mode has an icon,
 *   display name, and can influence XP calculations.
 */

import 'package:flutter/material.dart';

/// Available transport modes for journey tracking.
enum TransportMode {
  walk,
  run,
  cycle,
  drive,
  transit;

  /// Returns the display name for this transport mode.
  String get displayName {
    switch (this) {
      case TransportMode.walk:
        return 'Walk';
      case TransportMode.run:
        return 'Run';
      case TransportMode.cycle:
        return 'Cycle';
      case TransportMode.drive:
        return 'Drive';
      case TransportMode.transit:
        return 'Transit';
    }
  }

  /// Returns the icon for this transport mode.
  IconData get icon {
    switch (this) {
      case TransportMode.walk:
        return Icons.directions_walk;
      case TransportMode.run:
        return Icons.directions_run;
      case TransportMode.cycle:
        return Icons.directions_bike;
      case TransportMode.drive:
        return Icons.directions_car;
      case TransportMode.transit:
        return Icons.directions_transit;
    }
  }

  /// Returns the XP multiplier for this transport mode.
  /// Walking and running earn more XP than driving.
  double get xpMultiplier {
    switch (this) {
      case TransportMode.walk:
        return 1.0;
      case TransportMode.run:
        return 1.2;
      case TransportMode.cycle:
        return 0.8;
      case TransportMode.drive:
        return 0.3;
      case TransportMode.transit:
        return 0.5;
    }
  }

  /// Creates a TransportMode from a string value.
  static TransportMode fromString(String value) {
    return TransportMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => TransportMode.walk,
    );
  }
}
