/*
 * Author: Amarprit Singh
 * Last Modified: 07/05/2026
 * Description:
 * 
 *   Caches loaded regions and their rendered polygons so the map can restyle and
 *   reuse them without rebuilding everything from scratch. This helps viewport
 *   loading stay efficient as the user moves around.
 * 
 */

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'region_polygon.dart';

class RegionPolygonCache {
  static const Color _visitedStrokeColor = Color(0x80F3D27A);
  static const Color _visitedFillColor = Color(0x00000000);
  static const int _visitedStrokeWidth = 3;

  static const Color _unvisitedStrokeColor = Color(0xFF4A4A4A);
  static const Color _unvisitedFillColor = Color(0xCC080808);
  static const int _unvisitedStrokeWidth = 2;

  // Keeps the original region data in memory so we can reuse it later.
  // The key is the region's unique ID.
  final Map<String, RegionPolygon> _regionsById = <String, RegionPolygon>{};

  // Keeps the Google Maps polygons that were built from the region data.
  // These are the actual shapes the map widget will render.
  final Map<String, Polygon> _polygonsById = <String, Polygon>{};

  // Saves a region, builds its map polygons, and applies the correct style.
  // Returns `true` if this region was not already in the cache.
  bool cacheRegion({
    required RegionPolygon region,
    required bool isVisited,
    required void Function(String regionId, String regionName) onRegionTapped,
  }) {
    final wasAlreadyCached = _regionsById.containsKey(region.id);
    _regionsById[region.id] = region;

    final googlePolygons = region.toGooglePolygons(
      strokeColor: _strokeColorForVisited(isVisited),
      fillColor: _fillColorForVisited(isVisited),
      strokeWidth: _strokeWidthForVisited(isVisited),
      onTap: onRegionTapped,
    );

    for (final polygon in googlePolygons) {
      _polygonsById[polygon.polygonId.value] = polygon;
    }

    return !wasAlreadyCached;
  }


  // Rebuilds the polygons for every cached region.
  // This is useful when the visited state changes and the colors need to update.
  void refreshStyles({
    required bool Function(String regionId) shouldRenderAsVisited,
    required void Function(String regionId, String regionName) onRegionTapped,
  }) {
    for (final region in _regionsById.values) {
      cacheRegion(
        region: region,
        isVisited: shouldRenderAsVisited(region.id),
        onRegionTapped: onRegionTapped,
      );
    }
  }

  
  // Returns all polygons that are ready to be drawn on the map.
  Set<Polygon> get polygons => _polygonsById.values.toSet();

  Color _strokeColorForVisited(bool isVisited) {
    return isVisited ? _visitedStrokeColor : _unvisitedStrokeColor;
  }

  Color _fillColorForVisited(bool isVisited) {
    return isVisited ? _visitedFillColor : _unvisitedFillColor;
  }

  int _strokeWidthForVisited(bool isVisited) {
    return isVisited ? _visitedStrokeWidth : _unvisitedStrokeWidth;
  }
}
