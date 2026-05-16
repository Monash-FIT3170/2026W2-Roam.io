/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Caches loaded region polygons so map rendering and region unlock reward
 *   lookups can reuse the same RegionPolygon data.
 */

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'region_polygon.dart';

/// Keeps loaded RegionPolygon objects and rendered Google Maps polygons in sync.
class RegionPolygonCache {
  static const Color _visitedStrokeColor = Color(0x80F3D27A);
  static const Color _visitedFillColor = Color(0x00000000);
  static const int _visitedStrokeWidth = 3;

  static const Color _unvisitedStrokeColor = Color(0xFF4A4A4A);
  static const Color _unvisitedFillColor = Color(0xCC080808);
  static const int _unvisitedStrokeWidth = 2;

  static const Color _currentRegionStrokeColor = Color(0xFFF3D27A);
  static const int _currentRegionStrokeWidth = 5;

  static const Color _heatmapColdColor = Color(0xFF3D8BFF);
  static const Color _heatmapWarmColor = Color(0xFFFFC247);
  static const Color _heatmapHotColor = Color(0xFFE53935);

  // Keeps the original region data in memory so we can reuse it later.
  // The key is the region's unique ID.
  final Map<String, RegionPolygon> _regionsById = <String, RegionPolygon>{};

  // Keeps the Google Maps polygons that were built from the region data.
  // These are the actual shapes the map widget will render.
  final Map<String, Polygon> _polygonsById = <String, Polygon>{};

  /// Saves a region, builds its map polygons, and applies the correct style.
  ///
  /// [RegionPolygon.areaSquareMetres] is calculated by PostGIS and returned as
  /// area_square_metres by the backend. If a later API response omits that
  /// value, the cache keeps the last confirmed square-metre area so valid
  /// unlock XP remains area-scaled. The 50 XP fallback is only for regions with
  /// genuinely missing or invalid area.
  RegionPolygonCacheResult cacheRegion({
    required RegionPolygon region,
    required bool isVisited,
    required bool isCurrentRegion,
    required void Function(String regionId, String regionName) onRegionTapped,
    double? heatmapIntensity,
  }) {
    final wasAlreadyCached = _regionsById.containsKey(region.id);
    final previousRegion = _regionsById[region.id];
    final effectiveRegion =
        region.areaSquareMetres == null &&
            previousRegion?.areaSquareMetres != null
        ? RegionPolygon(
            id: region.id,
            name: region.name,
            areaSquareMetres: previousRegion!.areaSquareMetres,
            geometry: region.geometry,
          )
        : region;

    _regionsById[region.id] = effectiveRegion;

    final googlePolygons = effectiveRegion.toGooglePolygons(
      strokeColor: _strokeColorForRegion(
        isVisited: isVisited,
        isCurrentRegion: isCurrentRegion,
        heatmapIntensity: heatmapIntensity,
      ),
      fillColor: _fillColorForRegion(
        isVisited: isVisited,
        heatmapIntensity: heatmapIntensity,
      ),
      strokeWidth: _strokeWidthForRegion(
        isVisited: isVisited,
        isCurrentRegion: isCurrentRegion,
      ),
      onTap: onRegionTapped,
    );

    for (final polygon in googlePolygons) {
      _polygonsById[polygon.polygonId.value] = polygon;
    }

    return RegionPolygonCacheResult(
      region: effectiveRegion,
      wasAdded: !wasAlreadyCached,
    );
  }

  // Rebuilds the polygons for every cached region.
  // This is useful when the visited state changes and the colors need to update.
  void refreshStyles({
    required bool Function(String regionId) shouldRenderAsVisited,
    required bool Function(String regionId) isCurrentRegion,
    required void Function(String regionId, String regionName) onRegionTapped,
    double? Function(String regionId)? heatmapIntensityForRegion,
  }) {
    for (final region in _regionsById.values) {
      cacheRegion(
        region: region,
        isVisited: shouldRenderAsVisited(region.id),
        isCurrentRegion: isCurrentRegion(region.id),
        onRegionTapped: onRegionTapped,
        heatmapIntensity: heatmapIntensityForRegion?.call(region.id),
      );
    }
  }

  // Returns all polygons that are ready to be drawn on the map.
  Set<Polygon> get polygons => _polygonsById.values.toSet();

  RegionPolygon? regionForId(String regionId) => _regionsById[regionId];

  Color _strokeColorForRegion({
    required bool isVisited,
    required bool isCurrentRegion,
    double? heatmapIntensity,
  }) {
    if (isCurrentRegion) {
      return _currentRegionStrokeColor;
    }

    if (isVisited && heatmapIntensity != null) {
      return _heatmapColor(heatmapIntensity).withValues(alpha: 0.9);
    }

    return isVisited ? _visitedStrokeColor : _unvisitedStrokeColor;
  }

  Color _fillColorForRegion({
    required bool isVisited,
    double? heatmapIntensity,
  }) {
    if (!isVisited) {
      return _unvisitedFillColor;
    }

    if (heatmapIntensity != null) {
      return _heatmapColor(heatmapIntensity).withValues(alpha: 0.48);
    }

    return _visitedFillColor;
  }

  int _strokeWidthForRegion({
    required bool isVisited,
    required bool isCurrentRegion,
  }) {
    if (isCurrentRegion) {
      return _currentRegionStrokeWidth;
    }

    return isVisited ? _visitedStrokeWidth : _unvisitedStrokeWidth;
  }

  Color _heatmapColor(double intensity) {
    final clampedIntensity = intensity.clamp(0.0, 1.0).toDouble();

    if (clampedIntensity <= 0.5) {
      return Color.lerp(
        _heatmapColdColor,
        _heatmapWarmColor,
        clampedIntensity * 2,
      )!;
    }

    return Color.lerp(
      _heatmapWarmColor,
      _heatmapHotColor,
      (clampedIntensity - 0.5) * 2,
    )!;
  }
}

/// The effective cached region plus whether it was newly added to the cache.
class RegionPolygonCacheResult {
  const RegionPolygonCacheResult({
    required this.region,
    required this.wasAdded,
  });

  final RegionPolygon region;
  final bool wasAdded;
}
