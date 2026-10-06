import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../theme/app_colours.dart';
import '../domain/place_visit_feedback.dart';

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
  small(20), // zoom < 13
  medium(26), // zoom 13-15
  large(32); // zoom > 15

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
  static final Map<
    (TransportMarkerType?, MarkerSize, PlaceMarkerState),
    BitmapDescriptor
  >
  _markerIcons = {};
  static Future<void>? _iconLoading;
  static MarkerSize _currentSize = MarkerSize.medium;

  static MarkerSize get currentSize => _currentSize;

  /// Share rendering across categories and controller instances. A GPS update
  /// selects cached artwork; it never decodes assets or renders new bitmaps.
  static Future<void> preloadIcons() => _iconLoading ??= _loadIcons();

  static Future<void> _loadIcons() async {
    try {
      for (final transport in <TransportMarkerType?>[
        null,
        ...TransportMarkerType.values,
      ]) {
        ui.Image? artwork;
        if (transport != null) {
          final asset = await rootBundle.load(transport.assetPath);
          final codec = await ui.instantiateImageCodec(
            asset.buffer.asUint8List(),
          );
          artwork = (await codec.getNextFrame()).image;
          codec.dispose();
        }
        try {
          for (final size in MarkerSize.values) {
            for (final state in PlaceMarkerState.values) {
              _markerIcons[(transport, size, state)] = await _createStatusIcon(
                state,
                size: size.pixelSize + 8,
                artwork: artwork,
              );
            }
          }
        } finally {
          artwork?.dispose();
        }
      }
    } catch (_) {
      _iconLoading = null;
      rethrow;
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

  /// Hollow = unvisited, target ring = in range, filled check = visited.
  /// Transport artwork keeps its identity and receives the same status cues.
  static Future<BitmapDescriptor> _createStatusIcon(
    PlaceMarkerState state, {
    required double size,
    ui.Image? artwork,
  }) async {
    const scale = 3.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    final centre = Offset(size / 2, size / 2);
    final radius = size * .33;
    final paint = Paint()..color = Colors.white;
    canvas.drawCircle(centre, radius + 2, paint);
    if (state == PlaceMarkerState.inRange) {
      canvas.drawCircle(
        centre,
        size * .45,
        Paint()
          ..color = AppColors.sage
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (artwork != null) {
      canvas.drawImageRect(
        artwork,
        Rect.fromLTWH(
          0,
          0,
          artwork.width.toDouble(),
          artwork.height.toDouble(),
        ),
        Rect.fromCircle(center: centre, radius: radius),
        Paint()..filterQuality = FilterQuality.high,
      );
    } else {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = AppColors.sage
          ..style = state == PlaceMarkerState.visited
              ? PaintingStyle.fill
              : PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (state == PlaceMarkerState.inRange) {
        canvas.drawCircle(centre, radius * .3, Paint()..color = AppColors.sage);
      }
    }
    if (state == PlaceMarkerState.visited) {
      final checkCentre = artwork == null
          ? centre
          : Offset(size * .77, size * .77);
      final checkRadius = artwork == null ? radius : size * .2;
      if (artwork != null) {
        canvas.drawCircle(
          checkCentre,
          checkRadius + 1.5,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          checkCentre,
          checkRadius,
          Paint()..color = AppColors.sage,
        );
      }
      final path = Path()
        ..moveTo(checkCentre.dx - checkRadius * .5, checkCentre.dy)
        ..lineTo(
          checkCentre.dx - checkRadius * .1,
          checkCentre.dy + checkRadius * .4,
        )
        ..lineTo(
          checkCentre.dx + checkRadius * .55,
          checkCentre.dy - checkRadius * .4,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = artwork == null ? 2.5 : 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size * scale).round(),
      (size * scale).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: size,
      height: size,
    );
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

  /// Uses cached status artwork, including visited transport stops.
  Marker toMarker({
    void Function(PlaceOfInterest place)? onTap,
    bool visited = false,
    bool inRange = false,
  }) {
    final state = visited
        ? PlaceMarkerState.visited
        : inRange
        ? PlaceMarkerState.inRange
        : PlaceMarkerState.unvisited;
    final icon =
        _markerIcons[(transportMarkerType, _currentSize, state)] ??
        BitmapDescriptor.defaultMarkerWithHue(switch (state) {
          PlaceMarkerState.visited => BitmapDescriptor.hueAzure,
          PlaceMarkerState.inRange => BitmapDescriptor.hueOrange,
          PlaceMarkerState.unvisited => category.markerHue,
        });
    return Marker(
      markerId: MarkerId('place_$id'),
      position: location,
      anchor: const Offset(.5, .5),
      infoWindow: InfoWindow.noText,
      zIndexInt: switch (state) {
        PlaceMarkerState.inRange => 3,
        PlaceMarkerState.unvisited => 2,
        PlaceMarkerState.visited => 1,
      },
      icon: icon,
      onTap: onTap == null ? null : () => onTap(this),
    );
  }
}
