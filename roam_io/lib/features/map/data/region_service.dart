/*
 * Author: Rushil Patel
 * Last Modified: 27/04/2026
 * Description:
 *   Fetches spatial region data from the backend for current-location and
 *   viewport-based map queries.
 */
// Fetches region data for the current location and visible viewport from the
// spatial API. This service exists so networking stays separate from map state
// management and rendering concerns.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'region_polygon.dart';

/// Calls the spatial API and converts region responses into map polygons.
class RegionService {
  final http.Client _client;

  RegionService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches the region containing the given latitude and longitude.
  // get the polygon for the region I am currently located in
  Future<RegionPolygon?> getContainingRegion({
    required double lat,
    required double lng,
  }) async {
    // The spatial API will return the containing region for the given lat/lng, or null if no region contains that point.
    final response = await _client.post(
      Uri.parse('${ApiConfig.spatialApiBaseUrl}/region/contains'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch containing region: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded == null) return null;

    return RegionPolygon.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  /// Fetches regions intersecting the visible map viewport bounds.
  // get all the regions that intersect with the current viewport
  Future<List<RegionPolygon>> getRegionsForViewport({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    // The spatial API will return a list of regions that intersect with the given bounding box.
    final response = await _client.post(
      Uri.parse('${ApiConfig.spatialApiBaseUrl}/regions/viewport'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'south': south,
        'west': west,
        'north': north,
        'east': east,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch viewport regions: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;

    return decoded
        .map(
          (item) =>
              RegionPolygon.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }
}
