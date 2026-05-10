<<<<<<<< HEAD:roam_io/lib/features/map/domain/region_polygon.dart
/*
 * Author: Rushil Patel
 * Last Modified: 27/04/2026
 * Description:
 *   Represents spatial region geometry and converts backend polygons into
 *   Google Maps polygon overlays.
 */
========
// Defines the region polygon model and converts backend geometry into Google
// Maps polygons. This is needed to translate raw spatial data into something
// the map can actually draw and interact with.
>>>>>>>> feature/ART-4-fog-of-war:roam_io/lib/features/map/data/region_polygon.dart

import 'dart:convert';
import 'dart:ui';

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Region shape and metadata returned by the spatial API.
class RegionPolygon {
  final String id;
  final String name;
  final Map<String, dynamic> geometry;

  const RegionPolygon({
    required this.id,
    required this.name,
    required this.geometry,
  });

  /// Creates a region polygon from API JSON.
  factory RegionPolygon.fromJson(Map<String, dynamic> json) {
    final rawGeometry = json['geometry'];

    // Geometry may arrive as decoded JSON or as a JSON string from the API.
    return RegionPolygon(
      id: json['id'] as String,
      name: json['name'] as String,
      geometry: rawGeometry is String
          ? jsonDecode(rawGeometry) as Map<String, dynamic>
          : Map<String, dynamic>.from(rawGeometry as Map),
    );
  }
<<<<<<<< HEAD:roam_io/lib/features/map/domain/region_polygon.dart

  /// Converts GeoJSON polygon geometry into Google Maps polygon overlays.
========
  
>>>>>>>> feature/ART-4-fog-of-war:roam_io/lib/features/map/data/region_polygon.dart
  List<Polygon> toGooglePolygons({
    Color strokeColor = const Color(0xFF5B5BD6),
    Color fillColor = const Color(0x225B5BD6),
    int strokeWidth = 3,
    void Function(String regionId, String regionName)? onTap,
  }) {
    final type = geometry['type'] as String;
    final coordinates = geometry['coordinates'];

    final polygons = <Polygon>[];

    if (type == 'Polygon') {
      polygons.add(
        _polygonFromRing(
          polygonId: id,
          ring: coordinates[0] as List<dynamic>,
          strokeColor: strokeColor,
          fillColor: fillColor,
          strokeWidth: strokeWidth,
          onTap: onTap,
        ),
      );
    } else if (type == 'MultiPolygon') {
      final multi = coordinates as List<dynamic>;

      // Each MultiPolygon outer ring becomes a separate Google Maps polygon.
      for (var i = 0; i < multi.length; i++) {
        final polygon = multi[i] as List<dynamic>;
        final outerRing = polygon[0] as List<dynamic>;

        polygons.add(
          _polygonFromRing(
            polygonId: '${id}_$i',
            ring: outerRing,
            strokeColor: strokeColor,
            fillColor: fillColor,
            strokeWidth: strokeWidth,
            onTap: onTap,
          ),
        );
      }
    } else {
      throw Exception('Unsupported geometry type: $type');
    }

    return polygons;
  }

  Polygon _polygonFromRing({
    required String polygonId,
    required List<dynamic> ring,
    required Color strokeColor,
    required Color fillColor,
    required int strokeWidth,
    void Function(String regionId, String regionName)? onTap,
  }) {
    return Polygon(
      polygonId: PolygonId(polygonId),
      points: _parseRing(ring),
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      fillColor: fillColor,
      consumeTapEvents: onTap != null,
      onTap: onTap == null ? null : () => onTap(id, name),
    );
  }

  static List<LatLng> _parseRing(List<dynamic> ring) {
    return ring.map<LatLng>((coord) {
      final lng = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();
      return LatLng(lat, lng);
    }).toList();
  }
}
