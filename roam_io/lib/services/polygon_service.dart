/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 27/05/2026
 * Description:
 *   Persists visited polygon records and reports whether an unlock is new.
 */

import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/profile/domain/visited_polygon_meta.dart';
import '../features/profile/domain/visited_polygon_record.dart';

/// Reads and writes persisted polygon unlock records for profiles.
class PolygonService {
  static const String _visitedPolygonsCollectionName = 'polygons_visited';
  static const String _profileIdFieldName = 'profile_id';
  static const String _legacyProfileIdFieldName = 'profileId';
  static const String _userIdFieldName = 'user_id';
  static const String _legacyUserIdFieldName = 'userId';
  static const String _visitedPolygonsMapField = 'visited_polygons';
  static const String _visitedPolygonMetaField = 'visited_polygon_meta';

  PolygonService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Exposed so companion services can share the same Firestore instance.
  FirebaseFirestore get firestore => _firestore;

  CollectionReference<Map<String, dynamic>> get _visitedPolygons =>
      _firestore.collection(_visitedPolygonsCollectionName);

  // Returns all polygons the profile has visited with their saved timestamps.
  Future<List<VisitedPolygonRecord>> getVisitedPolygonRecords({
    required String profileId,
  }) async {
    final document = await _resolveVisitedPolygonDocument(profileId);
    final currentData = (await document.get()).data();
    final rawPolygonMap = currentData?[_visitedPolygonsMapField];

    return _recordsFromVisitedPolygonMap(
      profileId: profileId,
      rawPolygonMap: rawPolygonMap,
    ).toList();
  }

  /// Streams all polygons the profile has visited with their saved timestamps.
  Stream<List<VisitedPolygonRecord>> watchVisitedPolygonRecords({
    required String profileId,
  }) {
    return Stream.fromFuture(
      _resolveVisitedPolygonDocument(profileId),
    ).asyncExpand((document) => document.snapshots()).map((snapshot) {
      final rawPolygonMap = snapshot.data()?[_visitedPolygonsMapField];
      return _recordsFromVisitedPolygonMap(
        profileId: profileId,
        rawPolygonMap: rawPolygonMap,
      ).toList();
    });
  }

  /// Inserts a visited polygon for the profile.
  ///
  /// Returns true only when this call creates the first persisted unlock for the
  /// polygon. Existing polygons are left unchanged so callers can avoid awarding
  /// duplicate unlock XP.
  Future<bool> upsertVisitedPolygon({
    required String profileId,
    required String polygonId,
    DateTime? visitedAt,
    double? areaSquareMetres,
    String? name,
  }) async {
    final time = visitedAt ?? DateTime.now();
    final document = await _resolveVisitedPolygonDocument(profileId);

    return _firestore.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(document);
      final currentData = snapshot.data();
      final currentPolygonMap =
          (currentData?[_visitedPolygonsMapField] as Map<String, dynamic>?) ??
          <String, dynamic>{};

      if (currentPolygonMap.containsKey(polygonId)) {
        return false;
      }

      final updatedPolygonMap = Map<String, dynamic>.from(currentPolygonMap)
        ..[polygonId] = Timestamp.fromDate(time);

      final currentMetaMap =
          (currentData?[_visitedPolygonMetaField] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      final updatedMetaMap = Map<String, dynamic>.from(currentMetaMap)
        ..[polygonId] = VisitedPolygonMeta(
          polygonId: polygonId,
          visitedAt: time,
          areaSquareMetres: areaSquareMetres,
          name: name,
          lastEnteredAt: time,
        ).toMap();

      transaction.set(document, <String, dynamic>{
        _profileIdFieldName: profileId,
        _userIdFieldName: profileId,
        _visitedPolygonsMapField: updatedPolygonMap,
        _visitedPolygonMetaField: updatedMetaMap,
      }, SetOptions(merge: true));

      return true;
    });
  }

  // updating the most recent visit time for a polygon if the profile has already been visited
  Future<void> updateVisitedPolygon({
    required String profileId,
    required String polygonId,
    required DateTime visitedAt,
  }) async {
    final document = await _resolveVisitedPolygonDocument(profileId);

    await document.set({
      _profileIdFieldName: profileId,
      _userIdFieldName: profileId,
    }, SetOptions(merge: true));

    await document.update({
      'visited_polygons.$polygonId': Timestamp.fromDate(visitedAt),
    });
  }

  // Deletes a visited polygon record for the profile.
  Future<void> deleteVisitedPolygon({
    required String profileId,
    required String polygonId,
  }) async {
    final document = await _resolveVisitedPolygonDocument(profileId);

    await document.set({
      _profileIdFieldName: profileId,
      _userIdFieldName: profileId,
    }, SetOptions(merge: true));

    await document.update({'visited_polygons.$polygonId': FieldValue.delete()});
  }

  Future<DocumentReference<Map<String, dynamic>>>
  _resolveVisitedPolygonDocument(String profileId) async {
    final directDocument = _visitedPolygons.doc(profileId);
    final directSnapshot = await directDocument.get();

    if (directSnapshot.exists) {
      return directDocument;
    }

    final matchedDocument = await _findExistingVisitedPolygonDocument(
      profileId,
    );

    return matchedDocument ?? directDocument;
  }

  Future<DocumentReference<Map<String, dynamic>>?>
  _findExistingVisitedPolygonDocument(String profileId) async {
    for (final fieldName in <String>[
      _profileIdFieldName,
      _legacyProfileIdFieldName,
      _userIdFieldName,
      _legacyUserIdFieldName,
    ]) {
      try {
        final snapshot = await _visitedPolygons
            .where(fieldName, isEqualTo: profileId)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs.first.reference;
        }
      } on FirebaseException {
        // Some environments deny collection queries for this collection, so we
        // fall back to the uid-keyed document shape instead of hard-failing.
      }
    }

    return null;
  }

  // Turns firestore data (polygon_id, visited_at) into polygon objects
  Iterable<VisitedPolygonRecord> _recordsFromVisitedPolygonMap({
    required String profileId,
    required dynamic rawPolygonMap,
  }) sync* {
    if (rawPolygonMap is! Map<String, dynamic>) {
      return;
    }

    for (final entry in rawPolygonMap.entries) {
      if (entry.key.isEmpty) {
        continue;
      }

      yield VisitedPolygonRecord(
        profileId: profileId,
        polygonId: entry.key,
        visitedAt: VisitedPolygonRecord.parseVisitedAt(entry.value),
      );
    }
  }

  /// Updates re-entry metadata and increments the tile entry count.
  Future<int> recordPolygonReentry({
    required String profileId,
    required String polygonId,
    DateTime? enteredAt,
  }) async {
    final time = enteredAt ?? DateTime.now();
    final document = await _resolveVisitedPolygonDocument(profileId);

    return _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(document);
      final currentData = snapshot.data();
      final currentEntryMap =
          (currentData?['entry_counts'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      final currentPolygonMap =
          (currentData?[_visitedPolygonsMapField] as Map<String, dynamic>?) ??
          <String, dynamic>{};

      final currentCountDynamic = currentEntryMap[polygonId];
      final currentCount = currentCountDynamic is num
          ? currentCountDynamic.toInt()
          : int.tryParse('$currentCountDynamic') ?? 0;
      final newCount = currentCount + 1;

      final updatedEntryMap = Map<String, dynamic>.from(currentEntryMap)
        ..[polygonId] = newCount;

      final currentMetaMap =
          (currentData?[_visitedPolygonMetaField] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      final existingMeta = currentMetaMap[polygonId];
      final updatedMetaMap = Map<String, dynamic>.from(currentMetaMap);

      if (existingMeta is Map<String, dynamic>) {
        updatedMetaMap[polygonId] = Map<String, dynamic>.from(existingMeta)
          ..['lastEnteredAt'] = Timestamp.fromDate(time);
      } else {
        updatedMetaMap[polygonId] = VisitedPolygonMeta(
          polygonId: polygonId,
          visitedAt: time,
          lastEnteredAt: time,
        ).toMap();
      }

      transaction.set(document, <String, dynamic>{
        _profileIdFieldName: profileId,
        _userIdFieldName: profileId,
        // Re-entry affects visual decay metadata, never permanent history.
        _visitedPolygonsMapField: Map<String, dynamic>.from(currentPolygonMap),
        'entry_counts': updatedEntryMap,
        _visitedPolygonMetaField: updatedMetaMap,
      }, SetOptions(merge: true));

      return newCount;
    });
  }

  /// Returns enriched unlock metadata keyed by polygon ID.
  Future<Map<String, VisitedPolygonMeta>> getVisitedPolygonMeta({
    required String profileId,
  }) async {
    final document = await _resolveVisitedPolygonDocument(profileId);
    final currentData = (await document.get()).data();
    return _metaFromMap(currentData?[_visitedPolygonMetaField]);
  }

  /// Streams enriched unlock metadata keyed by polygon ID.
  Stream<Map<String, VisitedPolygonMeta>> watchVisitedPolygonMeta({
    required String profileId,
  }) {
    return Stream.fromFuture(
      _resolveVisitedPolygonDocument(profileId),
    ).asyncExpand((document) => document.snapshots()).map((snapshot) {
      return _metaFromMap(snapshot.data()?[_visitedPolygonMetaField]);
    });
  }

  Map<String, VisitedPolygonMeta> _metaFromMap(dynamic rawMetaMap) {
    final meta = <String, VisitedPolygonMeta>{};
    if (rawMetaMap is! Map<String, dynamic>) {
      return meta;
    }

    for (final entry in rawMetaMap.entries) {
      if (entry.key.isEmpty) continue;
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      meta[entry.key] = VisitedPolygonMeta.fromMap(entry.key, value);
    }

    return meta;
  }

  /// Increments an entry count for a polygon for the given profile.
  ///
  /// Prefer [recordPolygonReentry] for new code; this remains for compatibility.
  Future<int> incrementPolygonEntryCount({
    required String profileId,
    required String polygonId,
  }) async {
    final document = await _resolveVisitedPolygonDocument(profileId);

    return _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(document);
      final currentData = snapshot.data();
      final currentEntryMap =
          (currentData?['entry_counts'] as Map<String, dynamic>?) ??
          <String, dynamic>{};

      final currentCountDynamic = currentEntryMap[polygonId];
      final currentCount = currentCountDynamic is num
          ? currentCountDynamic.toInt()
          : int.tryParse('$currentCountDynamic') ?? 0;

      final updatedEntryMap = Map<String, dynamic>.from(currentEntryMap)
        ..[polygonId] = currentCount + 1;

      transaction.set(document, <String, dynamic>{
        _profileIdFieldName: profileId,
        _userIdFieldName: profileId,
        'entry_counts': updatedEntryMap,
      }, SetOptions(merge: true));

      return currentCount + 1;
    });
  }

  /// Returns a map of polygon entry counts for the profile.
  Future<Map<String, int>> getPolygonEntryCounts({
    required String profileId,
    Set<String>? validPolygonIds,
  }) async {
    final document = await _resolveVisitedPolygonDocument(profileId);
    final currentData = (await document.get()).data();
    return _entryCountsFromMap(
      currentData?['entry_counts'],
      validPolygonIds: validPolygonIds,
    );
  }

  /// Streams polygon entry counts for the profile.
  Stream<Map<String, int>> watchPolygonEntryCounts({
    required String profileId,
    Set<String>? validPolygonIds,
  }) {
    return Stream.fromFuture(
      _resolveVisitedPolygonDocument(profileId),
    ).asyncExpand((document) => document.snapshots()).map((snapshot) {
      return _entryCountsFromMap(
        snapshot.data()?['entry_counts'],
        validPolygonIds: validPolygonIds,
      );
    });
  }

  Map<String, int> _entryCountsFromMap(
    dynamic rawEntryMap, {
    Set<String>? validPolygonIds,
  }) {
    final counts = <String, int>{};

    if (rawEntryMap is Map<String, dynamic>) {
      for (final entry in rawEntryMap.entries) {
        if (entry.key.isEmpty) continue;
        if (validPolygonIds != null && !validPolygonIds.contains(entry.key)) {
          continue;
        }

        final value = entry.value;
        final count = value is num
            ? value.toInt()
            : int.tryParse('$value') ?? 0;
        if (count > 0) counts[entry.key] = count;
      }
    }

    return counts;
  }
}
