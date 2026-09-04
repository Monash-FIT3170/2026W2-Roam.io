import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'place_of_interest.dart';
import 'api_config.dart';
import '../../journeys/domain/nearby_place.dart';

class PlacesService {
  static const int transportEligibilityRadiusMeters = 200;

  final http.Client _client;

  PlacesService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch places for a single region.
  ///
  /// On the backend:
  /// - If cached: returns immediately from PostGIS
  /// - If not cached: calls Google Places API, caches, then returns
  ///
  /// This should ONLY be called when a region is unlocked.

  Future<List<PlaceOfInterest>> getPlacesForRegion({
    required String regionId,
  }) async {
    final url = '${ApiConfig.spatialApiBaseUrl}/places/region/$regionId';
    debugPrint('[PlacesService] GET $url');

    final response = await _client.get(Uri.parse(url));

    debugPrint('[PlacesService] Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch places: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    final places = decoded['places'] as List<dynamic>;

    debugPrint('[PlacesService] Parsed ${places.length} places');

    return places
        .map(
          (item) =>
              PlaceOfInterest.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  /// Batch fetch places for multiple regions at once.
  ///
  /// This endpoint only returns cached places (no Google API calls).
  /// Use when loading existing unlocked regions on app startup.

  Future<Map<String, List<PlaceOfInterest>>> getPlacesForRegions({
    required List<String> regionIds,
  }) async {
    if (regionIds.isEmpty) return {};

    final response = await _client.post(
      Uri.parse('${ApiConfig.spatialApiBaseUrl}/places/regions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'regionIds': regionIds}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch batch places: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = <String, List<PlaceOfInterest>>{};

    for (final entry in decoded.entries) {
      final places = (entry.value as List<dynamic>)
          .map(
            (item) => PlaceOfInterest.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      result[entry.key] = places;
    }

    return result;
  }

  /// Fetch nearby places within a radius of a location.
  ///
  /// Used by Journey Mode for selecting start/end locations.
  /// Returns up to 5 nearest places, sorted by distance.
  ///
  /// On failure, returns an empty list (graceful degradation).
  Future<List<NearbyPlace>> getNearbyPlaces({
    required double lat,
    required double lng,
    int radiusMeters = 25,
    bool transportOnly = false,
  }) async {
    final url = '${ApiConfig.spatialApiBaseUrl}/places/nearby';
    debugPrint(
      '[PlacesService] POST $url (lat: $lat, lng: $lng, radius: ${radiusMeters}m)',
    );

    try {
      final response = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': lat,
          'lng': lng,
          'radiusMeters': radiusMeters,
          'transportOnly': transportOnly,
        }),
      );

      debugPrint('[PlacesService] Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('[PlacesService] Error: ${response.body}');
        return [];
      }

      final decoded = jsonDecode(response.body) as List<dynamic>;
      final places =
          decoded
              .map(
                (item) => NearbyPlace.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
            ..sort((a, b) {
              // Missing distances must never displace a place whose distance was
              // calculated by the API.
              final aDistance = a.distanceMeters;
              final bDistance = b.distanceMeters;
              if (aDistance == null) return bDistance == null ? 0 : 1;
              if (bDistance == null) return -1;
              return aDistance.compareTo(bDistance);
            });

      debugPrint('[PlacesService] Found ${places.length} nearby places');
      return places;
    } catch (e) {
      debugPrint('[PlacesService] Error fetching nearby places: $e');
      return [];
    }
  }
}
