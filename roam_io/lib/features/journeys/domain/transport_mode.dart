/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 21 August 2026
 * Description:
 *   Defines the transport modes available for journeys. Each mode has an icon,
 *   display name, and can influence XP calculations.
 */

import 'package:flutter/material.dart';

/// Available transport modes for journey tracking.
enum TransportMode {
  walk,
  drive,
  bus,
  train,
  tram,

  // Retained so journeys saved by older app versions still deserialize and
  // display correctly. These modes are not offered for new journeys.
  run,
  cycle,
  transit;

  /// Modes offered when starting a new journey.
  static const List<TransportMode> journeyOptions = [
    walk,
    drive,
    bus,
    train,
    tram,
  ];

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
      case TransportMode.bus:
        return 'Bus';
      case TransportMode.train:
        return 'Train';
      case TransportMode.tram:
        return 'Tram';
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
      case TransportMode.bus:
        return Icons.directions_bus;
      case TransportMode.train:
        return Icons.train;
      case TransportMode.tram:
        return Icons.tram;
      case TransportMode.transit:
        return Icons.directions_transit;
    }
  }

  /// Colour used to draw this transport mode's journey route on the map.
  Color get routeColor {
    switch (this) {
      case TransportMode.walk:
      case TransportMode.drive:
      case TransportMode.run:
        return const Color(0xFFD946EF);
      case TransportMode.bus:
        return const Color(0xFFF97316);
      case TransportMode.train:
      case TransportMode.transit:
        return const Color(0xFF2563EB);
      case TransportMode.tram:
      case TransportMode.cycle:
        return const Color(0xFF16A34A);
    }
  }

  /// Parses optional route colour inputs without crashing on future mode names.
  static Color routeColorForWireValue(String? value) {
    final mode = tryFromString(value);
    return mode?.routeColor ?? const Color(0xFF5C734C);
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
      case TransportMode.bus:
      case TransportMode.train:
      case TransportMode.tram:
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

  /// Creates a TransportMode from a string value, or null for future modes.
  static TransportMode? tryFromString(String? value) {
    if (value == null) return null;
    for (final mode in TransportMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }
}
