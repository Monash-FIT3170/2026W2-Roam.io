import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:roam_io/features/mapfeature/PlaceOfInterest.dart';
import 'package:roam_io/features/mapfeature/api_config.dart';


class PlacesService {
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
        .map((item) => PlaceOfInterest.fromJson(Map<String, dynamic>.from(item as Map)))
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
          .map((item) => PlaceOfInterest.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      result[entry.key] = places;
    }

    return result;
  }
}
