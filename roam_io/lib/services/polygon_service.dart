import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/profile/domain/visited_polygon_record.dart';

class PolygonService {
  static const String _visitedPolygonsCollectionName = 'polygons_visited';
  static const String _profileIdFieldName = 'profile_id';
  static const String _legacyProfileIdFieldName = 'profileId';
  static const String _userIdFieldName = 'user_id';
  static const String _legacyUserIdFieldName = 'userId';
  static const String _visitedPolygonsMapField = 'visited_polygons';

  PolygonService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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

  // Inserts or updates a visited polygon for the profile.
  Future<void> upsertVisitedPolygon({
    required String profileId,
    required String polygonId,
    DateTime? visitedAt,
  }) async {
    final time = visitedAt ?? DateTime.now();
    final document = await _resolveVisitedPolygonDocument(profileId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      final currentData = snapshot.data();
      final currentPolygonMap =
          (currentData?[_visitedPolygonsMapField] as Map<String, dynamic>?) ??
          <String, dynamic>{};

      final updatedPolygonMap = Map<String, dynamic>.from(currentPolygonMap)
        ..[polygonId] = Timestamp.fromDate(time);

      transaction.set(document, <String, dynamic>{
        _profileIdFieldName: profileId,
        _userIdFieldName: profileId,
        _visitedPolygonsMapField: updatedPolygonMap,
      }, SetOptions(merge: true));
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
}
