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
    this.customName,
    this.description,
    this.mediaUrls = const [],
    this.visitCount = 1,
    this.firstVisitedAt,
    this.lastVisitedAt,
  });

  /// The database ID of the place (from PostGIS).
  final int placeId;

  /// Google's place ID for external reference.
  final String googlePlaceId;

  /// Display name of the place (from Places API).
  final String placeName;

  /// The SA2 region this place belongs to.
  final String regionId;

  /// Simplified category (food_drink, nature, etc.).
  final String category;

  /// When the user marked this place as visited.
  final DateTime visitedAt;

  /// User's custom name for this visit (defaults to placeName if null).
  final String? customName;

  /// User's description of this visit.
  final String? description;

  /// Firebase Storage URLs for photos/videos attached to this visit.
  final List<String> mediaUrls;

  /// Total number of recorded visits to this place.
  final int visitCount;

  /// When the user first marked this place as visited.
  final DateTime? firstVisitedAt;

  /// When the user most recently marked this place as visited.
  final DateTime? lastVisitedAt;

  /// Returns the display name (custom name if set, otherwise place name).
  String get displayName => customName ?? placeName;

  /// Converts this visit to a Firestore-friendly map.
  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'googlePlaceId': googlePlaceId,
      'placeName': placeName,
      'regionId': regionId,
      'category': category,
      'visitedAt': Timestamp.fromDate(visitedAt),
      'customName': customName,
      'description': description,
      'mediaUrls': mediaUrls,
      'visitCount': visitCount,
      if (firstVisitedAt != null)
        'firstVisitedAt': Timestamp.fromDate(firstVisitedAt!),
      if (lastVisitedAt != null)
        'lastVisitedAt': Timestamp.fromDate(lastVisitedAt!),
    };
  }

  /// Creates a Visit from Firestore document data.
  factory Visit.fromMap(Map<String, dynamic> map) {
    final visitedAt = (map['visitedAt'] as Timestamp).toDate();
    return Visit(
      placeId: map['placeId'] as int,
      googlePlaceId: map['googlePlaceId'] as String,
      placeName: map['placeName'] as String,
      regionId: map['regionId'] as String,
      category: map['category'] as String,
      visitedAt: visitedAt,
      customName: map['customName'] as String?,
      description: map['description'] as String?,
      mediaUrls: (map['mediaUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      visitCount: (map['visitCount'] as num?)?.toInt() ?? 1,
      firstVisitedAt:
          _parseOptionalTimestamp(map['firstVisitedAt']) ?? visitedAt,
      lastVisitedAt: _parseOptionalTimestamp(map['lastVisitedAt']) ?? visitedAt,
    );
  }

  static DateTime? _parseOptionalTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  /// Creates a copy of this visit with updated fields.
  Visit copyWith({
    int? placeId,
    String? googlePlaceId,
    String? placeName,
    String? regionId,
    String? category,
    DateTime? visitedAt,
    String? customName,
    String? description,
    List<String>? mediaUrls,
    int? visitCount,
    DateTime? firstVisitedAt,
    DateTime? lastVisitedAt,
  }) {
    return Visit(
      placeId: placeId ?? this.placeId,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      placeName: placeName ?? this.placeName,
      regionId: regionId ?? this.regionId,
      category: category ?? this.category,
      visitedAt: visitedAt ?? this.visitedAt,
      customName: customName ?? this.customName,
      description: description ?? this.description,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      visitCount: visitCount ?? this.visitCount,
      firstVisitedAt: firstVisitedAt ?? this.firstVisitedAt,
      lastVisitedAt: lastVisitedAt ?? this.lastVisitedAt,
    );
  }

  @override
  String toString() {
    return 'Visit(placeId: $placeId, placeName: $placeName, customName: $customName, visitedAt: $visitedAt)';
  }
}
