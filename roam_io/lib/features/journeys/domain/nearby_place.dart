/*
 * Author: GitHub Copilot
 * Last Modified: 30/07/2026
 * Description:
 *   Represents a nearby place that can be selected as a journey start or end
 *   location. Simplified from PlaceOfInterest for location selection UI.
 */

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A nearby place for journey location selection.
class NearbyPlace {
  const NearbyPlace({
    this.placeId,
    required this.name,
    required this.address,
    required this.latLng,
    this.distanceMeters,
    this.isCustomLocation = false,
  });

  /// The Google Places ID. Null for custom saved locations.
  final String? placeId;

  /// The place name.
  final String name;

  /// The formatted address.
  final String address;

  /// The location coordinates.
  final LatLng latLng;

  /// Distance from user's current position in meters.
  final int? distanceMeters;

  /// Whether this is a custom saved location (black dot) vs Google Place.
  final bool isCustomLocation;

  /// Creates a NearbyPlace from a JSON map (API response).
  factory NearbyPlace.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>;
    return NearbyPlace(
      placeId: json['placeId'] as String?,
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      latLng: LatLng(
        (location['lat'] as num).toDouble(),
        (location['lng'] as num).toDouble(),
      ),
      distanceMeters: json['distanceMeters'] as int?,
      isCustomLocation: json['isCustomLocation'] as bool? ?? false,
    );
  }

  /// Returns a formatted distance string (e.g., "5m away").
  String get formattedDistance {
    if (distanceMeters == null) return '';
    return '${distanceMeters}m away';
  }
}
