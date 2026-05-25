/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 23/05/2026
 * Description:
 *   Caches loaded region polygons so map rendering can reuse already-fetched
 *   geometry instead of rebuilding everything after every camera movement.
 *
 *   This class owns polygon styling only:
 *   - unvisited/fogged tiles
 *   - visited/unlocked tiles
 *   - current user tile
 *   - heatmap colouring
 *
 *   It also supports display filtering so SA1 fog tiles can be hidden when the
 *   user zooms out, while still keeping visited/current regions visible.
 */

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'region_polygon.dart';

/// Keeps loaded [RegionPolygon] objects and rendered Google Maps polygons in sync.
class RegionPolygonCache {
  /*
  static const Color _visitedStrokeColor = Color(0xB0F3D27A);
  static const Color _visitedFillColor = Color(0x18F3D27A);
  static const int _visitedStrokeWidth = 3;

  static const Color _unvisitedStrokeColor = Color(0xFF4A4A4A);
  static const Color _unvisitedFillColor = Color(0xCC000000);
  static const int _unvisitedStrokeWidth = 2;

  static const Color _currentRegionStrokeColor = Color(0xFFF3D27A);
  static const Color _currentRegionFillColor = Color(0x33F3D27A);
  static const int _currentRegionStrokeWidth = 5;

*/
  static const Color _visitedStrokeColor = Color(0xFFFFFFFF);
  static const Color _visitedFillColor = Color(0x30FFFFFF);
  static const int _visitedStrokeWidth = 5;

  static const Color _currentRegionStrokeColor = Color(0xFFFFFFFF);
  static const Color _currentRegionFillColor = Color(0x30FFFFFF);
  static const int _currentRegionStrokeWidth = 7;

  static const Color _unvisitedStrokeColor = Color(0xFF4A4A4A);
  static const Color _unvisitedFillColor = Color(0xCC000000);
  static const int _unvisitedStrokeWidth = 2;

  static const Color _heatmapColdColor = Color(0xFF3D8BFF);
  static const Color _heatmapWarmColor = Color(0xFFFFC247);
  static const Color _heatmapHotColor = Color(0xFFE53935);

  final Map<String, RegionPolygon> _regionsById = <String, RegionPolygon>{};
  final Map<String, Polygon> _polygonsById = <String, Polygon>{};
  final Map<String, String> _polygonIdToRegionId = <String, String>{};

  /// Saves a region, builds its polygons, and applies the correct visual style.
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
        isCurrentRegion: isCurrentRegion,
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
      _polygonIdToRegionId[polygon.polygonId.value] = effectiveRegion.id;
    }

    return RegionPolygonCacheResult(
      region: effectiveRegion,
      wasAdded: !wasAlreadyCached,
    );
  }

  /// Rebuilds styles for every cached region.
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

  /// Returns all polygons, including unvisited/fogged polygons.
  Set<Polygon> get polygons => _polygonsById.values.toSet();

  /// Returns polygons that should currently be displayed.
  ///
  /// When zoomed in, [showUnvisitedRegions] is true and SA1 fog tiles render.
  /// When zoomed out, unvisited fog tiles are hidden, but visited/current tiles
  /// remain visible so the user still sees meaningful progress.
  Set<Polygon> polygonsForDisplay({
    required bool showUnvisitedRegions,
    required Set<String> visitedRegionIds,
    String? currentRegionId,
  }) {
    final visiblePolygons = <Polygon>{};

    for (final entry in _polygonsById.entries) {
      final polygonId = entry.key;
      final polygon = entry.value;
      final regionId = _polygonIdToRegionId[polygonId];

      if (regionId == null) continue;

      final isVisited = visitedRegionIds.contains(regionId);
      final isCurrent = currentRegionId == regionId;

      if (showUnvisitedRegions || isVisited || isCurrent) {
        visiblePolygons.add(polygon);
      }
    }

    return visiblePolygons;
  }

  RegionPolygon? regionForId(String regionId) {
    return _regionsById[regionId];
  }

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
    required bool isCurrentRegion,
    double? heatmapIntensity,
  }) {
    if (isCurrentRegion) {
      return _currentRegionFillColor;
    }

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

/// Returned when a region is cached.
class RegionPolygonCacheResult {
  const RegionPolygonCacheResult({
    required this.region,
    required this.wasAdded,
  });

  final RegionPolygon region;
  final bool wasAdded;
}
