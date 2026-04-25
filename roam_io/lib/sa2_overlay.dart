import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SA2Overlay {
  static Future<Set<Polygon>> loadPolygons({
    Color strokeColor = Colors.blue,
    Color fillColor = const Color(0x226200EE),
    double strokeWidth = 1.0,
    String? filterState,
    Function(String sa2Name)? onTap,
  }) async {
    final String data = await rootBundle.loadString('assets/SA2_2021_AUST_GDA2020.json');

    final polygons = await compute(_parseGeoJson, {
      'data': data,
      'strokeColorValue': strokeColor.value,
      'fillColorValue': fillColor.value,
      'strokeWidth': strokeWidth,
      'filterState': filterState,
    });

    return polygons;
  }
}

Set<Polygon> _parseGeoJson(Map<String, dynamic> args) {
  final String rawData = args['data'] as String;
  final int strokeColorValue = args['strokeColorValue'] as int;
  final int fillColorValue = args['fillColorValue'] as int;
  final double strokeWidth = args['strokeWidth'] as double;
  final String? filterState = args['filterState'] as String?;

  final Color strokeColor = Color(strokeColorValue);
  final Color fillColor = Color(fillColorValue);

  final Map<String, dynamic> geoJson = jsonDecode(rawData) as Map<String, dynamic>;
  final List<dynamic> features = geoJson['features'] as List<dynamic>;
  final Set<Polygon> polygons = {};

  for (final dynamic rawFeature in features) {
    final feature = rawFeature as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final properties = feature['properties'] as Map<String, dynamic>?;

    if (geometry == null || properties == null) continue;

    // Filter by state early to skip unnecessary processing
    if (filterState != null && properties['STE_NAME21'] != filterState) continue;

    final String sa2Code = properties['SA2_CODE21']?.toString() ?? '';
    final String geometryType = geometry['type'] as String? ?? '';
    final coordinates = geometry['coordinates'] as List<dynamic>?;

    if (coordinates == null) continue;

    if (geometryType == 'Polygon') {
      final polygon = _buildPolygon(
        id: sa2Code,
        rings: coordinates,
        fillColor: fillColor,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
      );
      if (polygon != null) polygons.add(polygon);
    } else if (geometryType == 'MultiPolygon') {
      int part = 0;
      for (final dynamic rings in coordinates) {
        final polygon = _buildPolygon(
          id: '${sa2Code}_$part',
          rings: rings as List<dynamic>,
          fillColor: fillColor,
          strokeColor: strokeColor,
          strokeWidth: strokeWidth,
        );
        if (polygon != null) polygons.add(polygon);
        part++;
      }
    }
  }

  return polygons;
}

Polygon? _buildPolygon({
  required String id,
  required List<dynamic> rings,
  required Color fillColor,
  required Color strokeColor,
  required double strokeWidth,
}) {
  if (rings.isEmpty) return null;

  final List<LatLng> points = _toLatLngList(rings[0] as List<dynamic>);
  if (points.isEmpty) return null;

  final List<List<LatLng>> holes = rings.length > 1
      ? rings
          .sublist(1)
          .map<List<LatLng>>((r) => _toLatLngList(r as List<dynamic>))
          .toList()
      : [];

  return Polygon(
    polygonId: PolygonId(id),
    points: points,
    holes: holes,
    fillColor: fillColor,
    strokeColor: strokeColor,
    strokeWidth: strokeWidth.toInt(),
    consumeTapEvents: true,
  );
}

// Simplify coordinates by only keeping every Nth point
List<LatLng> _toLatLngList(List<dynamic> coords, {int step = 3}) {
  final list = <LatLng>[];
  for (int i = 0; i < coords.length; i += step) {
    final point = coords[i] as List<dynamic>;
    list.add(LatLng(
      (point[1] as num).toDouble(),
      (point[0] as num).toDouble(),
    ));
  }
  return list;
}