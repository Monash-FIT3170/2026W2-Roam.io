import 'package:cloud_firestore/cloud_firestore.dart';

/*
 * Author: Amarprit Singh
 * Last Modified: 07/05/2026
 * Description:
 * 
 *  Defined the type for a single visited polygon entry that links to a user
 *  Object represents which polygon was visited and when it was visited
 *  Defined helper to convert visited polygon data to and from firestore format
 * 
 */

// Represents a record of a user visiting a specific polygon/region.
class VisitedPolygonRecord {
  const VisitedPolygonRecord({
    required this.profileId,
    required this.polygonId,
    required this.visitedAt,
  });

  final String profileId;
  final String polygonId;
  final DateTime visitedAt;

  // Converts this object into a Map so it can be stored in Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'profile_id': profileId,
      'polygon_id': polygonId,
      'visited_at': Timestamp.fromDate(visitedAt),
    };
  }

  // Creates a VisitedPolygonRecord from Firestore data (Map).
  factory VisitedPolygonRecord.fromMap(Map<String, dynamic> map) {
    return VisitedPolygonRecord(
      profileId: (map['profile_id'] ?? map['profileId'] ?? '') as String,
      polygonId: (map['polygon_id'] ?? map['polygonId'] ?? '') as String,
      visitedAt: parseVisitedAt(map['visited_at'] ?? map['lastVisitedAt']),
    );
  }

  static DateTime parseVisitedAt(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }
}
