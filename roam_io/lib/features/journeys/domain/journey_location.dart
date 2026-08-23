/*
 * Author: GitHub Copilot
 * Last Modified: 30/07/2026
 * Description:
 *   Represents a location point in a journey (start or end). Can be derived
 *   from the user's current location or a selected PlaceOfInterest.
 */

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A location point used as a journey's start or end.
class JourneyLocation {
  /// Creates a new journey location.
  const JourneyLocation({
    required this.latLng,
    this.placeId,
    required this.displayName,
    this.customName,
    this.description,
    this.mediaUrls = const [],
  });

  /// The geographic coordinates of this location.
  final LatLng latLng;

  /// The Google Places ID, if this location was selected from nearby places.
  final String? placeId;

  /// The default display name (e.g., place name or "Current Location").
  final String displayName;

  /// User-defined custom name that overrides displayName when set.
  final String? customName;

  /// Optional user-authored details for custom journey locations.
  final String? description;

  /// Photos and videos attached to this custom location.
  final List<String> mediaUrls;

  /// Returns the name to display (customName if set, otherwise displayName).
  String get name => customName ?? displayName;

  /// Creates a copy with optional field overrides.
  JourneyLocation copyWith({
    LatLng? latLng,
    String? placeId,
    String? displayName,
    String? customName,
    String? description,
    List<String>? mediaUrls,
  }) {
    return JourneyLocation(
      latLng: latLng ?? this.latLng,
      placeId: placeId ?? this.placeId,
      displayName: displayName ?? this.displayName,
      customName: customName ?? this.customName,
      description: description ?? this.description,
      mediaUrls: mediaUrls ?? this.mediaUrls,
    );
  }

  /// Creates a JourneyLocation from a map (Firestore deserialization).
  factory JourneyLocation.fromMap(Map<String, dynamic> map) {
    final geoPoint = map['latLng'] as Map<String, dynamic>;
    return JourneyLocation(
      latLng: LatLng(
        (geoPoint['latitude'] as num).toDouble(),
        (geoPoint['longitude'] as num).toDouble(),
      ),
      placeId: map['placeId'] as String?,
      displayName: map['displayName'] as String,
      customName: map['customName'] as String?,
      description: map['description'] as String?,
      mediaUrls:
          (map['mediaUrls'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  /// Converts this location to a map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'latLng': {'latitude': latLng.latitude, 'longitude': latLng.longitude},
      'placeId': placeId,
      'displayName': displayName,
      'customName': customName,
      'description': description,
      'mediaUrls': mediaUrls,
    };
  }

  /// Creates a location representing the user's current position.
  factory JourneyLocation.currentLocation(LatLng position) {
    return JourneyLocation(latLng: position, displayName: 'Current Location');
  }

  @override
  String toString() => 'JourneyLocation(name: $name, latLng: $latLng)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JourneyLocation &&
        other.latLng == latLng &&
        other.placeId == placeId &&
        other.displayName == displayName &&
        other.customName == customName &&
        other.description == description &&
        listEquals(other.mediaUrls, mediaUrls);
  }

  @override
  int get hashCode => Object.hash(
    latLng,
    placeId,
    displayName,
    customName,
    description,
    Object.hashAll(mediaUrls),
  );
}
