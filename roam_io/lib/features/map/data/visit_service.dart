/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 17/05/2026
 * Description:
 *   Firestore-backed service for reading and writing user place visits under
 *   profiles/{userId}/visits. It supports visit lookup, recent visit streams,
 *   total counts, region grouped counts for heatmaps, and most-visited place
 *   summaries for analytics.
 */

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/visit_event.dart';
import '../../you/services/stats_summary_service.dart';
import 'place_of_interest.dart';
import 'visit.dart';

/// Result of persisting a place visit.
class VisitWriteResult {
  const VisitWriteResult({required this.isFirstVisit});

  final bool isFirstVisit;
}

/// Service for managing user visits to places.
///
/// Visits are stored in Firestore at `profiles/{userId}/visits/{placeId}`.
/// This service owns all read/write operations for visit data.
class VisitService {
  VisitService({
    FirebaseFirestore? firestore,
    StatsSummaryService? statsSummaryService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _statsSummaryService =
           statsSummaryService ??
           StatsSummaryService(firestore: firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;
  final StatsSummaryService _statsSummaryService;

  /// Gets the visits subcollection for a user.
  CollectionReference<Map<String, dynamic>> _visitsCollection(String userId) {
    return _firestore.collection('profiles').doc(userId).collection('visits');
  }

  /// Gets the append-only visit events subcollection for analytics history.
  CollectionReference<Map<String, dynamic>> _visitEventsCollection(
    String userId,
  ) {
    return _firestore
        .collection('profiles')
        .doc(userId)
        .collection('visit_events');
  }

  /// Marks a place as visited by the user.
  ///
  /// Appends a visit event and updates the per-place summary document.
  Future<VisitWriteResult> markVisited({
    required String userId,
    required PlaceOfInterest place,
    String? customName,
    String? description,
    List<String>? mediaUrls,
  }) async {
    final now = DateTime.now();
    final existing = await getVisit(userId: userId, placeId: place.id);
    final isFirstVisit = existing == null;
    final visitCount = (existing?.visitCount ?? 0) + 1;
    final firstVisitedAt = existing?.firstVisitedAt ?? now;

    final visit = Visit(
      placeId: place.id,
      googlePlaceId: place.googlePlaceId,
      placeName: place.name,
      regionId: place.regionId,
      category: place.category.name,
      visitedAt: now,
      customName: customName ?? existing?.customName,
      description: description ?? existing?.description,
      mediaUrls: mediaUrls ?? existing?.mediaUrls ?? const [],
      visitCount: visitCount,
      firstVisitedAt: firstVisitedAt,
      lastVisitedAt: now,
    );

    final eventRef = _visitEventsCollection(userId).doc();
    final event = VisitEvent(
      id: eventRef.id,
      placeId: place.id,
      googlePlaceId: place.googlePlaceId,
      placeName: place.name,
      regionId: place.regionId,
      category: place.category.name,
      lat: place.location.latitude,
      lng: place.location.longitude,
      visitedAt: now,
    );

    final batch = _firestore.batch();
    batch.set(
      _visitsCollection(userId).doc(place.id.toString()),
      visit.toMap(),
    );
    batch.set(eventRef, event.toMap());
    await batch.commit();

    await _statsSummaryService.recordVisit(
      uid: userId,
      isFirstVisit: isFirstVisit,
    );

    return VisitWriteResult(isFirstVisit: isFirstVisit);
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

  /// Watches all visits for a user with full details.
  ///
  /// Use this for analytics surfaces that need to update as visits are created
  /// or edited.
  Stream<List<Visit>> watchAllVisits(String userId) {
    return _visitsCollection(userId).snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => Visit.fromMap(doc.data())).toList(),
    );
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

  /// Gets completed visit counts grouped by region for a user.
  ///
  /// This counts saved place visits, not unlocked map tiles. Analytics and
  /// heatmap UIs can combine this with visited region IDs to keep visits and
  /// tiles distinct.
  Future<Map<String, int>> getVisitCountsByRegion(
    String userId, {
    Set<String>? validRegionIds,
  }) async {
    final visits = await getAllVisits(userId);
    final countsByRegion = <String, int>{};

    for (final visit in visits) {
      final regionId = visit.regionId.trim();

      if (regionId.isEmpty) continue;

      // Ignore old SA2/stale region IDs after the SA1 migration.
      if (validRegionIds != null && !validRegionIds.contains(regionId)) {
        continue;
      }

      final count = visit.visitCount <= 0 ? 1 : visit.visitCount;
      countsByRegion.update(
        regionId,
        (existingCount) => existingCount + count,
        ifAbsent: () => count,
      );
    }

    return countsByRegion;
  }

  /// Stream of visited place IDs for real-time updates.
  ///
  /// Use this to keep the UI in sync when visits change.
  Stream<Set<int>> watchVisitedPlaceIds(String userId) {
    return _visitsCollection(userId).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => int.parse(doc.id)).toSet(),
    );
  }

  /// Gets the most visited place name for a user.
  ///
  /// Returns the display name of the place with the highest visit count.
  /// If no visits, returns null.
  Future<String?> getMostVisitedPlaceName(String userId) async {
    final visits = await getAllVisits(userId);
    if (visits.isEmpty) return null;

    final counts = <String, int>{};
    for (final visit in visits) {
      final name = visit.displayName;
      final count = visit.visitCount <= 0 ? 1 : visit.visitCount;
      counts[name] = (counts[name] ?? 0) + count;
    }

    final mostVisited = counts.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    return mostVisited.key;
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

  /// Watches append-only visit events for analytics timelines.
  Stream<List<VisitEvent>> watchVisitEvents(String userId, {int limit = 100}) {
    return _visitEventsCollection(userId)
        .orderBy('visitedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => VisitEvent.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }
}
