/*
 * Author: GitHub Copilot
 * Last Modified: 30/07/2026
 * Description:
 *   Firestore service for CRUD operations on user journeys. Journeys are
 *   stored at profiles/{userId}/journeys/{journeyId}.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/journey.dart';
import '../domain/journey_location.dart';

/// Service for managing journey data in Firestore.
class JourneyService {
  JourneyService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Gets the journeys subcollection for a user.
  CollectionReference<Map<String, dynamic>> _journeysCollection(String userId) {
    return _firestore.collection('profiles').doc(userId).collection('journeys');
  }

  /// Saves a new journey to Firestore.
  ///
  /// Returns the journey with its assigned document ID.
  Future<Journey> saveJourney(Journey journey) async {
    try {
      final docRef = _journeysCollection(journey.userId).doc();
      final journeyWithId = journey.copyWith(id: docRef.id);

      await docRef.set(journeyWithId.toMap());

      debugPrint('[JourneyService] Saved journey: ${journeyWithId.id}');
      return journeyWithId;
    } catch (e) {
      debugPrint('[JourneyService] Error saving journey: $e');
      rethrow;
    }
  }

  /// Gets a stream of all journeys for a user, ordered by start time descending.
  Stream<List<Journey>> getJourneysStream(String userId) {
    return _journeysCollection(
      userId,
    ).orderBy('startTime', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Journey.fromFirestore(doc)).toList();
    });
  }

  /// Gets all journeys for a user (one-time fetch).
  Future<List<Journey>> getJourneys(String userId) async {
    final snapshot = await _journeysCollection(
      userId,
    ).orderBy('startTime', descending: true).get();

    return snapshot.docs.map((doc) => Journey.fromFirestore(doc)).toList();
  }

  /// Gets all journeys for a user that started after the given date.
  Future<List<Journey>> getJourneysSince(String userId, DateTime since) async {
    final snapshot = await _journeysCollection(userId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('startTime', descending: true)
        .get();

    return snapshot.docs.map((doc) => Journey.fromFirestore(doc)).toList();
  }

  /// Gets a single journey by ID.
  Future<Journey?> getJourneyById({
    required String userId,
    required String journeyId,
  }) async {
    final doc = await _journeysCollection(userId).doc(journeyId).get();

    if (!doc.exists) return null;
    return Journey.fromFirestore(doc);
  }

  /// Updates journey location names (custom names).
  Future<void> updateJourneyNames({
    required String userId,
    required String journeyId,
    String? startCustomName,
    String? endCustomName,
  }) async {
    final updates = <String, dynamic>{};

    if (startCustomName != null) {
      updates['startLocation.customName'] = startCustomName;
    }
    if (endCustomName != null) {
      updates['endLocation.customName'] = endCustomName;
    }

    if (updates.isNotEmpty) {
      await _journeysCollection(userId).doc(journeyId).update(updates);
    }
  }

  /// Updates one custom location embedded in a saved journey.
  Future<void> updateJourneyLocation({
    required String userId,
    required String journeyId,
    required bool isStartLocation,
    required JourneyLocation location,
  }) {
    final field = isStartLocation ? 'startLocation' : 'endLocation';
    return _journeysCollection(
      userId,
    ).doc(journeyId).update({field: location.toMap()});
  }

  /// Updates the reviewed title of a saved journey.
  Future<void> updateJourneyTitle({
    required String userId,
    required String journeyId,
    required String title,
  }) {
    return _journeysCollection(
      userId,
    ).doc(journeyId).update({'title': title.trim()});
  }

  /// Deletes a journey.
  Future<void> deleteJourney({
    required String userId,
    required String journeyId,
  }) async {
    await _journeysCollection(userId).doc(journeyId).delete();
    debugPrint('[JourneyService] Deleted journey: $journeyId');
  }

  /// Gets the total number of journeys for a user.
  Future<int> getJourneyCount(String userId) async {
    final snapshot = await _journeysCollection(userId).count().get();
    return snapshot.count ?? 0;
  }

  /// Gets total distance traveled across all journeys (in meters).
  Future<double> getTotalDistance(String userId) async {
    final journeys = await getJourneys(userId);
    double total = 0.0;
    for (final j in journeys) {
      total += j.distanceMeters;
    }
    return total;
  }

  /// Gets journeys within a date range.
  Future<List<Journey>> getJourneysByDateRange({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _journeysCollection(userId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('startTime', descending: true)
        .get();

    return snapshot.docs.map((doc) => Journey.fromFirestore(doc)).toList();
  }
}
