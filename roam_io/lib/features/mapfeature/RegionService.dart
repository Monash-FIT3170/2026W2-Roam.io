/*
 * Author: Rushil Patel
 * Last Modified: 27/04/2026
 * Description:
 *   Fetches spatial region data from the backend for current-location and
 *   viewport-based map queries.
 */

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:roam_io/features/mapfeature/RegionPolygon.dart';
import 'package:roam_io/features/mapfeature/api_config.dart';

/// Calls the spatial API and converts region responses into map polygons.
class RegionService {
  final http.Client _client;

  RegionService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches the region containing the given latitude and longitude.
  Future<RegionPolygon?> getContainingRegion({
    required double lat,
    required double lng,
  }) async {
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
  Future<List<RegionPolygon>> getRegionsForViewport({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
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
