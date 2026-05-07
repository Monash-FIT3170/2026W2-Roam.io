import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum PlaceCategory {
  foodDrink,
  nature,
  culture,
  shopping,
  entertainment,
  healthFitness,
  attraction,
  other;

  static PlaceCategory fromString(String value) {
    switch (value) {
      case 'food_drink':
        return PlaceCategory.foodDrink;
      case 'nature':
        return PlaceCategory.nature;
      case 'culture':
        return PlaceCategory.culture;
      case 'shopping':
        return PlaceCategory.shopping;
      case 'entertainment':
        return PlaceCategory.entertainment;
      case 'health_fitness':
        return PlaceCategory.healthFitness;
      case 'attraction':
        return PlaceCategory.attraction;
      default:
        return PlaceCategory.other;
    }
  }

  String get displayName {
    switch (this) {
      case PlaceCategory.foodDrink:
        return 'Food & Drink';
      case PlaceCategory.nature:
        return 'Nature';
      case PlaceCategory.culture:
        return 'Culture';
      case PlaceCategory.shopping:
        return 'Shopping';
      case PlaceCategory.entertainment:
        return 'Entertainment';
      case PlaceCategory.healthFitness:
        return 'Health & Fitness';
      case PlaceCategory.attraction:
        return 'Attractions';
      case PlaceCategory.other:
        return 'Other';
    }
  }

  Color get markerColor {
    switch (this) {
      case PlaceCategory.foodDrink:
        return const Color(0xFFFF9800); // Orange
      case PlaceCategory.nature:
        return const Color(0xFF4CAF50); // Green
      case PlaceCategory.culture:
        return const Color(0xFF9C27B0); // Purple
      case PlaceCategory.shopping:
        return const Color(0xFF2196F3); // Blue
      case PlaceCategory.entertainment:
        return const Color(0xFFE91E63); // Pink
      case PlaceCategory.healthFitness:
        return const Color(0xFFF44336); // Red
      case PlaceCategory.attraction:
        return const Color(0xFFFFEB3B); // Yellow
      case PlaceCategory.other:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  double get markerHue {
    return BitmapDescriptor.hueOrange;
  }
}

/// Marker size levels based on zoom
enum MarkerSize {
  small(15),   // zoom < 13
  medium(20),  // zoom 13-15
  large(25);   // zoom > 15

  final double pixelSize;
  const MarkerSize(this.pixelSize);

  /// Get the appropriate size for a given zoom level
  static MarkerSize fromZoom(double zoom) {
    if (zoom < 13) return MarkerSize.small;
    if (zoom <= 15) return MarkerSize.medium;
    return MarkerSize.large;
  }
}

class PlaceOfInterest {
  // Cache for circle icons: [category][size] -> icon
  static final Map<PlaceCategory, Map<MarkerSize, BitmapDescriptor>> _iconCache = {};
  
  // Current marker size level
  static MarkerSize _currentSize = MarkerSize.medium;
  
  /// Get the current marker size
  static MarkerSize get currentSize => _currentSize;

  /// Pre-generate all category icons at all sizes. Call this once at app startup.
  static Future<void> preloadIcons() async {
    for (final category in PlaceCategory.values) {
      _iconCache[category] = {};
      for (final size in MarkerSize.values) {
        _iconCache[category]![size] = await _createCircleIcon(
          category.markerColor,
          size: size.pixelSize,
        );
      }
    }
  }

  /// Update the current marker size based on zoom level.
  /// Returns true if the size changed (markers need rebuilding).
  static bool updateSizeForZoom(double zoom) {
    final newSize = MarkerSize.fromZoom(zoom);
    if (newSize != _currentSize) {
      _currentSize = newSize;
      return true; // Size changed, need to rebuild markers
    }
    return false;
  }

  /// Creates a circle icon with the given color.
  static Future<BitmapDescriptor> _createCircleIcon(
    Color color, {
    double size = 36,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final strokeWidth = size / 12; // Proportional border

    // Fill circle
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // White border
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size / 18);

    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - strokeWidth - 2;

    canvas.drawCircle(center + Offset(1, size / 18), radius, shadowPaint);
    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, strokePaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  final int id;
  final String googlePlaceId;
  final String name;
  final PlaceCategory category;
  final List<String> types;
  final LatLng location;
  final String regionId;
  final double? rating;
  final int? userRatingsTotal;
  final String? address;
  final String? photoReference;

  const PlaceOfInterest({
    required this.id,
    required this.googlePlaceId,
    required this.name,
    required this.category,
    required this.types,
    required this.location,
    required this.regionId,
    this.rating,
    this.userRatingsTotal,
    this.address,
    this.photoReference,
  });

  factory PlaceOfInterest.fromJson(Map<String, dynamic> json) {
    final locationJson = json['location'];
    final coords = locationJson is String
        ? jsonDecode(locationJson)['coordinates']
        : locationJson['coordinates'];

    // Helper to safely parse numbers that might come as strings
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return PlaceOfInterest(
      id: parseInt(json['id']) ?? 0,
      googlePlaceId: json['google_place_id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      category: PlaceCategory.fromString(json['category'] as String? ?? 'other'),
      types: (json['types'] as List<dynamic>?)?.cast<String>() ?? [],
      location: LatLng(
        parseDouble(coords[1]) ?? 0.0,
        parseDouble(coords[0]) ?? 0.0,
      ),
      regionId: json['region_id'].toString(),
      rating: parseDouble(json['rating']),
      userRatingsTotal: parseInt(json['user_ratings_total']),
      address: json['address'] as String?,
      photoReference: json['photo_reference'] as String?,
    );
  }

  /// Creates a marker with a circle icon at the current size level.
  /// Uses cached icons (call preloadIcons() at app start).
  /// Falls back to default marker if icons not yet loaded.
  Marker toMarker({
    void Function(PlaceOfInterest place)? onTap,
  }) {
    final icon = _iconCache[category]?[_currentSize] ??
        BitmapDescriptor.defaultMarkerWithHue(category.markerHue);

    return Marker(
      markerId: MarkerId('place_$id'),
      position: location,
      infoWindow: InfoWindow(
        title: name,
        snippet: _buildSnippet(),
      ),
      icon: icon,
      onTap: onTap == null ? null : () => onTap(this),
    );
  }

  String _buildSnippet() {
    final parts = <String>[category.displayName];
    if (rating != null) {
      parts.add('★ ${rating!.toStringAsFixed(1)}');
    }
    return parts.join(' • ');
  }
}
