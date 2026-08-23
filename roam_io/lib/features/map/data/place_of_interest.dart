import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../theme/app_colours.dart';

enum PlaceCategory {
  foodDrink,
  nature,
  culture,
  shopping,
  entertainment,
  healthFitness,
  attraction,
  publicTransport,
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
      case 'public_transport':
        return PlaceCategory.publicTransport;
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
      case PlaceCategory.publicTransport:
        return 'Public Transport';
      case PlaceCategory.other:
        return 'Other';
    }
  }

  Color get markerColor => AppColors.sage;

  double get markerHue => HSLColor.fromColor(AppColors.sage).hue;
}

/// Marker size levels based on zoom
enum MarkerSize {
  small(15), // zoom < 13
  medium(20), // zoom 13-15
  large(25); // zoom > 15

  final double pixelSize;
  const MarkerSize(this.pixelSize);

  /// Get the appropriate size for a given zoom level
  static MarkerSize fromZoom(double zoom) {
    if (zoom < 13) return MarkerSize.small;
    if (zoom <= 15) return MarkerSize.medium;
    return MarkerSize.large;
  }
}

enum TransportMarkerType {
  train('icons/train.webp'),
  bus('icons/bus.webp'),
  tram('icons/tram.webp');

  const TransportMarkerType(this.assetPath);

  final String assetPath;
}

class PlaceOfInterest {
  // Cache for circle icons: [category][size] -> icon
  static final Map<PlaceCategory, Map<MarkerSize, BitmapDescriptor>>
  _iconCache = {};

  // Cache for visited icons: [category][size] -> icon (keeps category color with checkmark)
  static final Map<PlaceCategory, Map<MarkerSize, BitmapDescriptor>>
  _visitedIconCache = {};

  static final Map<TransportMarkerType, Map<MarkerSize, BitmapDescriptor>>
  _transportIconCache = {};

  // Current marker size level
  static MarkerSize _currentSize = MarkerSize.medium;

  /// Get the current marker size
  static MarkerSize get currentSize => _currentSize;

  /// Pre-generate all category icons at all sizes. Call this once at app startup.
  static Future<void> preloadIcons() async {
    // Generate category icons and visited icons for each category
    for (final category in PlaceCategory.values) {
      _iconCache[category] = {};
      _visitedIconCache[category] = {};
      for (final size in MarkerSize.values) {
        _iconCache[category]![size] = await _createCircleIcon(
          category.markerColor,
          size: size.pixelSize,
        );
        _visitedIconCache[category]![size] = await _createVisitedIcon(
          category.markerColor,
          size: size.pixelSize,
        );
      }
    }

    for (final transportType in TransportMarkerType.values) {
      _transportIconCache[transportType] = {};
      for (final size in MarkerSize.values) {
        _transportIconCache[transportType]![size] = await _createTransportIcon(
          transportType.assetPath,
          size: (size.pixelSize * 1.2).round(),
        );
      }
    }
  }

  static Future<BitmapDescriptor> _createTransportIcon(
    String assetPath, {
    required int size,
  }) async {
    final asset = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      asset.buffer.asUint8List(),
      targetWidth: size,
      targetHeight: size,
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    codec.dispose();
    frame.image.dispose();
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: size.toDouble(),
      height: size.toDouble(),
    );
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
      ..color = Colors.black.withValues(alpha: 0.3)
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

  /// Creates a visited icon: colored circle with white checkmark.
  static Future<BitmapDescriptor> _createVisitedIcon(
    Color color, {
    double size = 36,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final strokeWidth = size / 12;

    // Fill circle (category color)
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
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size / 18);

    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - strokeWidth - 2;

    canvas.drawCircle(center + Offset(1, size / 18), radius, shadowPaint);
    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, strokePaint);

    // Draw checkmark
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size / 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path();
    // Checkmark proportions relative to center
    final checkSize = radius * 0.5;
    checkPath.moveTo(center.dx - checkSize * 0.5, center.dy);
    checkPath.lineTo(center.dx - checkSize * 0.1, center.dy + checkSize * 0.4);
    checkPath.lineTo(center.dx + checkSize * 0.5, center.dy - checkSize * 0.35);

    canvas.drawPath(checkPath, checkPaint);

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

  TransportMarkerType? get transportMarkerType {
    final typeSet = types.toSet();
    if (typeSet.contains('tram_stop') ||
        typeSet.contains('light_rail_station')) {
      return TransportMarkerType.tram;
    }
    if (typeSet.contains('train_station') ||
        typeSet.contains('subway_station')) {
      return TransportMarkerType.train;
    }
    if (typeSet.contains('bus_stop') || typeSet.contains('bus_station')) {
      return TransportMarkerType.bus;
    }
    return null;
  }

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
      category: PlaceCategory.fromString(
        json['category'] as String? ?? 'other',
      ),
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
  ///
  /// If [visited] is true, displays a gray checkmark icon instead of category color.
  Marker toMarker({
    void Function(PlaceOfInterest place)? onTap,
    bool visited = false,
  }) {
    final BitmapDescriptor icon;
    final transportType = transportMarkerType;

    if (transportType != null) {
      icon =
          _transportIconCache[transportType]?[_currentSize] ??
          BitmapDescriptor.defaultMarkerWithHue(
            PlaceCategory.publicTransport.markerHue,
          );
    } else if (visited) {
      // Use visited icon (category color with checkmark)
      icon =
          _visitedIconCache[category]?[_currentSize] ??
          BitmapDescriptor.defaultMarkerWithHue(category.markerHue);
    } else {
      // Use category-colored icon
      icon =
          _iconCache[category]?[_currentSize] ??
          BitmapDescriptor.defaultMarkerWithHue(category.markerHue);
    }

    return Marker(
      markerId: MarkerId('place_$id'),
      position: location,
      infoWindow: InfoWindow.noText,
      icon: icon,
      onTap: onTap == null ? null : () => onTap(this),
    );
  }
}
