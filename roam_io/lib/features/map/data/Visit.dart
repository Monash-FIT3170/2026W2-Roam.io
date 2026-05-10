import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user's visit to a place.
///
/// Stored in Firestore at `users/{userId}/visits/{placeId}`.
/// The document ID is the place's database ID (not google_place_id).
class Visit {
  const Visit({
    required this.placeId,
    required this.googlePlaceId,
    required this.placeName,
    required this.regionId,
    required this.category,
    required this.visitedAt,
  });

  /// The database ID of the place (from PostGIS).
  final int placeId;

  /// Google's place ID for external reference.
  final String googlePlaceId;

  /// Display name of the place.
  final String placeName;

  /// The SA2 region this place belongs to.
  final String regionId;

  /// Simplified category (food_drink, nature, etc.).
  final String category;

  /// When the user marked this place as visited.
  final DateTime visitedAt;

  /// Converts this visit to a Firestore-friendly map.
  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'googlePlaceId': googlePlaceId,
      'placeName': placeName,
      'regionId': regionId,
      'category': category,
      'visitedAt': Timestamp.fromDate(visitedAt),
    };
  }

  /// Creates a Visit from Firestore document data.
  factory Visit.fromMap(Map<String, dynamic> map) {
    return Visit(
      placeId: map['placeId'] as int,
      googlePlaceId: map['googlePlaceId'] as String,
      placeName: map['placeName'] as String,
      regionId: map['regionId'] as String,
      category: map['category'] as String,
      visitedAt: (map['visitedAt'] as Timestamp).toDate(),
    );
  }

  @override
  String toString() {
    return 'Visit(placeId: $placeId, placeName: $placeName, visitedAt: $visitedAt)';
  }
}
