import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SA2Overlay {
  static Future<Map<String, List<Map<String, dynamic>>>>? _stateFeaturesFuture;

  static Future<Set<Polygon>> loadPolygons({
    Color strokeColor = Colors.blue,
    Color fillColor = const Color(0x226200EE),
    double strokeWidth = 1.0,
    String? filterState,
    LatLngBounds? visibleBounds,
  }) async {
    final Map<String, List<Map<String, dynamic>>> stateFeatures =
        await _loadStateFeatures();
    final List<Map<String, dynamic>> features = filterState == null
        ? _flattenFeatures(stateFeatures)
        : (stateFeatures[filterState] ?? const []);

    final polygons = await compute(_buildPolygonsForViewport, {
      'features': features,
      'strokeColorValue': strokeColor.toARGB32(),
      'fillColorValue': fillColor.toARGB32(),
      'strokeWidth': strokeWidth,
      'bounds': _encodeBounds(visibleBounds),
    });

    return polygons;
  }

  static Future<Map<String, List<Map<String, dynamic>>>> _loadStateFeatures() {
    return _stateFeaturesFuture ??= _loadStateFeaturesImpl();
  }

  static Future<Map<String, List<Map<String, dynamic>>>>
  _loadStateFeaturesImpl() async {
    final String data = await rootBundle.loadString(
      'assets/SA2_2021_AUST_GDA2020.json',
    );
    return compute(_indexGeoJsonByState, data);
  }

  static List<Map<String, dynamic>> _flattenFeatures(
    Map<String, List<Map<String, dynamic>>> stateFeatures,
  ) {
    final List<Map<String, dynamic>> features = <Map<String, dynamic>>[];
    for (final List<Map<String, dynamic>> stateGroup in stateFeatures.values) {
      features.addAll(stateGroup);
    }
    return features;
  }

  static Map<String, double>? _encodeBounds(LatLngBounds? bounds) {
    if (bounds == null) return null;

    final double south = bounds.southwest.latitude;
    final double west = bounds.southwest.longitude;
    final double north = bounds.northeast.latitude;
    final double east = bounds.northeast.longitude;

    final double latPadding = (north - south).abs() * 0.15;
    final double lngPadding = (east - west).abs() * 0.15;

    return <String, double>{
      'south': south - latPadding,
      'west': west - lngPadding,
      'north': north + latPadding,
      'east': east + lngPadding,
    };
  }
}

Map<String, List<Map<String, dynamic>>> _indexGeoJsonByState(String rawData) {
  final Map<String, dynamic> geoJson =
      jsonDecode(rawData) as Map<String, dynamic>;
  final List<dynamic> features = geoJson['features'] as List<dynamic>;
  final Map<String, List<Map<String, dynamic>>> featuresByState =
      <String, List<Map<String, dynamic>>>{};

  for (final dynamic rawFeature in features) {
    final Map<String, dynamic> feature = rawFeature as Map<String, dynamic>;
    final Map<String, dynamic>? geometry =
        feature['geometry'] as Map<String, dynamic>?;
    final Map<String, dynamic>? properties =
        feature['properties'] as Map<String, dynamic>?;

    if (geometry == null || properties == null) continue;

    final String geometryType = geometry['type'] as String? ?? '';
    final List<dynamic>? coordinates =
        geometry['coordinates'] as List<dynamic>?;
    if (coordinates == null) continue;
    if (geometryType != 'Polygon' && geometryType != 'MultiPolygon') continue;

    final String stateName = properties['STE_NAME21']?.toString() ?? 'Unknown';
    final Map<String, double>? bbox = _computeBoundingBox(
      geometryType: geometryType,
      coordinates: coordinates,
    );
    if (bbox == null) continue;

    final Map<String, dynamic> indexedFeature = <String, dynamic>{
      'sa2Code': properties['SA2_CODE21']?.toString() ?? '',
      'sa2Name': properties['SA2_NAME21']?.toString() ?? '',
      'geometryType': geometryType,
      'coordinates': coordinates,
      'bbox': bbox,
    };

    featuresByState
        .putIfAbsent(stateName, () => <Map<String, dynamic>>[])
        .add(indexedFeature);
  }

  return featuresByState;
}

Set<Polygon> _buildPolygonsForViewport(Map<String, dynamic> args) {
  final List<dynamic> rawFeatures = args['features'] as List<dynamic>;
  final int strokeColorValue = args['strokeColorValue'] as int;
  final int fillColorValue = args['fillColorValue'] as int;
  final double strokeWidth = args['strokeWidth'] as double;
  final Map<String, dynamic>? bounds = args['bounds'] as Map<String, dynamic>?;

  final Color strokeColor = Color(strokeColorValue);
  final Color fillColor = Color(fillColorValue);
  final Set<Polygon> polygons = <Polygon>{};

  for (final dynamic rawFeature in rawFeatures) {
    final Map<String, dynamic> feature = rawFeature as Map<String, dynamic>;
    final Map<String, dynamic>? bbox = feature['bbox'] as Map<String, dynamic>?;
    if (bounds != null && bbox != null && !_boundsIntersect(bounds, bbox)) {
      continue;
    }

    final String sa2Code = feature['sa2Code'] as String? ?? '';
    final String geometryType = feature['geometryType'] as String? ?? '';
    final List<dynamic>? coordinates = feature['coordinates'] as List<dynamic>?;
    if (coordinates == null) continue;

    if (geometryType == 'Polygon') {
      final Polygon? polygon = _buildPolygon(
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
        final Polygon? polygon = _buildPolygon(
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

Map<String, double>? _computeBoundingBox({
  required String geometryType,
  required List<dynamic> coordinates,
}) {
  double? south;
  double? west;
  double? north;
  double? east;

  void addPoint(List<dynamic> point) {
    final double lng = (point[0] as num).toDouble();
    final double lat = (point[1] as num).toDouble();
    south = south == null ? lat : (lat < south! ? lat : south!);
    north = north == null ? lat : (lat > north! ? lat : north!);
    west = west == null ? lng : (lng < west! ? lng : west!);
    east = east == null ? lng : (lng > east! ? lng : east!);
  }

  if (geometryType == 'Polygon') {
    for (final dynamic ring in coordinates) {
      for (final dynamic point in ring as List<dynamic>) {
        addPoint(point as List<dynamic>);
      }
    }
  } else if (geometryType == 'MultiPolygon') {
    for (final dynamic polygon in coordinates) {
      for (final dynamic ring in polygon as List<dynamic>) {
        for (final dynamic point in ring as List<dynamic>) {
          addPoint(point as List<dynamic>);
        }
      }
    }
  }

  if (south == null || west == null || north == null || east == null) {
    return null;
  }

  return <String, double>{
    'south': south!,
    'west': west!,
    'north': north!,
    'east': east!,
  };
}

bool _boundsIntersect(Map<String, dynamic> a, Map<String, dynamic> b) {
  final double aSouth = (a['south'] as num).toDouble();
  final double aWest = (a['west'] as num).toDouble();
  final double aNorth = (a['north'] as num).toDouble();
  final double aEast = (a['east'] as num).toDouble();
  final double bSouth = (b['south'] as num).toDouble();
  final double bWest = (b['west'] as num).toDouble();
  final double bNorth = (b['north'] as num).toDouble();
  final double bEast = (b['east'] as num).toDouble();

  return aSouth <= bNorth &&
      aNorth >= bSouth &&
      aWest <= bEast &&
      aEast >= bWest;
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
  if (points.length < 3) return null;

  final List<List<LatLng>> holes = rings.length > 1
      ? rings
            .sublist(1)
            .map<List<LatLng>>(
              (dynamic ring) => _toLatLngList(ring as List<dynamic>),
            )
            .where((List<LatLng> hole) => hole.length >= 3)
            .toList()
      : <List<LatLng>>[];

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

List<LatLng> _toLatLngList(List<dynamic> coords) {
  final List<LatLng> points = <LatLng>[];
  for (int i = 0; i < coords.length; i++) {
    final List<dynamic> point = coords[i] as List<dynamic>;
    points.add(
      LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble()),
    );
  }
  return points;
}
