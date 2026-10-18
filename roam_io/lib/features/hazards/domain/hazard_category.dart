import 'package:flutter/material.dart';

/// Stable hazard types persisted in Firestore.
enum HazardCategory {
  crash('crash', 'Crash', Icons.car_crash),
  pothole('pothole', 'Pothole', Icons.warning_rounded),
  roadworks('roadworks', 'Roadworks', Icons.construction),
  obstruction('obstruction', 'Obstruction', Icons.block),
  flooding('flooding', 'Flooding', Icons.water),
  slipperySurface(
    'slippery_surface',
    'Slippery surface',
    Icons.warning_amber_rounded,
  );

  const HazardCategory(this.id, this.displayLabel, this.icon);

  final String id;
  final String displayLabel;
  final IconData icon;

  static HazardCategory fromId(String id) {
    return values.firstWhere(
      (category) => category.id == id,
      orElse: () => throw FormatException('Unknown hazard category: $id'),
    );
  }
}
