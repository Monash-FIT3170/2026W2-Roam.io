/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Firestore-backed service for reading and writing user place visits under
 *   profiles/{userId}/visits, including a stream of the most recent visits.
 */

import 'package:cloud_firestore/cloud_firestore.dart';

import 'place_of_interest.dart';
import 'visit.dart';

/// Service for managing user visits to places.
///
/// Visits are stored in Firestore at `profiles/{userId}/visits/{placeId}`.
/// This service owns all read/write operations for visit data.
class VisitService {
  VisitService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Gets the visits subcollection for a user.
  CollectionReference<Map<String, dynamic>> _visitsCollection(String userId) {
    return _firestore.collection('profiles').doc(userId).collection('visits');
  }

  /// Marks a place as visited by the user.
  ///
  /// Uses the place's database ID as the document ID for easy lookup.
  /// If already visited, this will update the visitedAt timestamp.
  ///
  /// Optional fields allow the user to customize their visit entry.
  Future<void> markVisited({
    required String userId,
    required PlaceOfInterest place,
    String? customName,
    String? description,
    List<String>? mediaUrls,
  }) async {
    final visit = Visit(
      placeId: place.id,
      googlePlaceId: place.googlePlaceId,
      placeName: place.name,
      regionId: place.regionId,
      category: place.category.name,
      visitedAt: DateTime.now(),
      customName: customName,
      description: description,
      mediaUrls: mediaUrls ?? [],
    );

    await _visitsCollection(userId).doc(place.id.toString()).set(visit.toMap());
  }

  /// Updates an existing visit with new details.
  Future<void> updateVisit({
    required String userId,
    required int placeId,
    String? customName,
    String? description,
    List<String>? mediaUrls,
  }) async {
    final updates = <String, dynamic>{};
    if (customName != null) updates['customName'] = customName;
    if (description != null) updates['description'] = description;
    if (mediaUrls != null) updates['mediaUrls'] = mediaUrls;

    if (updates.isNotEmpty) {
      await _visitsCollection(userId).doc(placeId.toString()).update(updates);
    }
  }

  /// Gets a single visit by place ID.
  Future<Visit?> getVisit({
    required String userId,
    required int placeId,
  }) async {
    final doc = await _visitsCollection(userId).doc(placeId.toString()).get();
    if (!doc.exists || doc.data() == null) return null;
    return Visit.fromMap(doc.data()!);
  }

  /// Checks if a specific place has been visited by the user.
  Future<bool> isVisited({required String userId, required int placeId}) async {
    final doc = await _visitsCollection(userId).doc(placeId.toString()).get();
    return doc.exists;
  }

  /// Gets all visited place IDs for a user.
  ///
  /// Returns a Set of place IDs (as strings) for efficient lookup.
  Future<Set<int>> getVisitedPlaceIds(String userId) async {
    final snapshot = await _visitsCollection(userId).get();
    return snapshot.docs.map((doc) => int.parse(doc.id)).toSet();
  }

  /// Gets all visits for a user with full details.
  ///
  /// Use this when you need the complete visit data, not just IDs.
  Future<List<Visit>> getAllVisits(String userId) async {
    final snapshot = await _visitsCollection(userId).get();
    return snapshot.docs.map((doc) => Visit.fromMap(doc.data())).toList();
  }

  /// Gets visits for a specific region.
  ///
  /// Useful for showing visited places within a particular tile.
  Future<List<Visit>> getVisitsForRegion({
    required String userId,
    required String regionId,
  }) async {
    final snapshot = await _visitsCollection(
      userId,
    ).where('regionId', isEqualTo: regionId).get();
    return snapshot.docs.map((doc) => Visit.fromMap(doc.data())).toList();
  }

  /// Gets the total count of visited places for a user.
  Future<int> getVisitCount(String userId) async {
    final snapshot = await _visitsCollection(userId).count().get();
    return snapshot.count ?? 0;
  }

  /// Stream of visited place IDs for real-time updates.
  ///
  /// Use this to keep the UI in sync when visits change.
  Stream<Set<int>> watchVisitedPlaceIds(String userId) {
    return _visitsCollection(userId).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => int.parse(doc.id)).toSet(),
    );
  }

  /// Real-time list of the user's most recent visits (newest first).
  ///
  /// Limited to [limit] documents for efficient analytics/history UIs.
  Stream<List<Visit>> watchRecentVisits(String userId, {int limit = 5}) {
    return _visitsCollection(userId)
        .orderBy('visitedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Visit.fromMap(doc.data())).toList(),
        );
  }
}
