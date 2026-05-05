import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/profile/domain/profile_model.dart';
import '../features/profile/domain/visited_polygon_record.dart';

/// Thin wrapper for Firestore profile operations.
///
/// This service owns reads/writes to the `profiles` collection so higher layers
/// do not depend on Firestore APIs directly.
class ProfileService {
  static const String _profilesCollectionName = 'profiles';
  static const String _visitedPolygonsCollectionName = 'polygons_visited';
  static const String _legacyVisitedPolygonsCollectionName = 'visited_polygons';
  static const String _visitedPolygonsMapField = 'visited_polygons';

  ProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection(_profilesCollectionName);

  CollectionReference<Map<String, dynamic>> get _visitedPolygons =>
      _firestore.collection(_visitedPolygonsCollectionName);

  CollectionReference<Map<String, dynamic>> get _legacyVisitedPolygons =>
      _firestore.collection(_legacyVisitedPolygonsCollectionName);

  /// Creates/replaces profile document at `profiles/{uid}`.
  Future<void> createProfile(ProfileModel profile) {
    return _profiles.doc(profile.uid).set(profile.toMap());
  }

  /// Updates editable profile fields and refreshes `updatedAt`.
  Future<void> updateProfile({
    required String uid,
    required String username,
    required String displayName,
    String? photoUrl,
  }) {
    final data = <String, dynamic>{
      'username': username,
      'displayName': displayName,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (photoUrl != null) {
      data['photoUrl'] = photoUrl;
    }
    return _profiles.doc(uid).update(data);
  }

  /// Updates the user's saved theme preference.
  Future<void> updateDarkModePreference({
    required String uid,
    required bool enabled,
  }) {
    return _profiles.doc(uid).update(<String, dynamic>{
      'darkModeEnabled': enabled,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateProfilePhoto({
    required String uid,
    required String photoUrl,
    required String photoHash,
  }) {
    return _profiles.doc(uid).update(<String, dynamic>{
      'photoUrl': photoUrl,
      'photoHash': photoHash,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateProfilePhotoHash({
    required String uid,
    required String photoHash,
  }) {
    return _profiles.doc(uid).update(<String, dynamic>{
      'photoHash': photoHash,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // Returns all of the visited polygons that a player has visited
  Future<List<VisitedPolygonRecord>> getVisitedPolygonRecords({
    required String profileId,
  }) async {
    final recordsByPolygonId = <String, VisitedPolygonRecord>{};

    final currentData = (await _visitedPolygons.doc(profileId).get()).data();
    final rawPolygonMap = currentData?[_visitedPolygonsMapField];
    for (final record in _recordsFromVisitedPolygonMap(
      profileId: profileId,
      rawPolygonMap: rawPolygonMap,
    )) {
      recordsByPolygonId[record.polygonId] = record;
    }

    final currentSnapshot = await _visitedPolygons
        .where('profile_id', isEqualTo: profileId)
        .get();

    for (final doc in currentSnapshot.docs) {
      final record = _recordFromStoredMap(doc.data());
      if (record != null) {
        recordsByPolygonId[record.polygonId] = record;
      }
    }

    final legacySnapshot = await _legacyVisitedPolygons
        .where('profileId', isEqualTo: profileId)
        .get();

    for (final doc in legacySnapshot.docs) {
      final record = _recordFromStoredMap(doc.data());
      if (record != null) {
        recordsByPolygonId.putIfAbsent(record.polygonId, () => record);
      }
    }

    return recordsByPolygonId.values.toList();
  }

  // Insert or update a visited polygon
  Future<void> upsertVisitedPolygon({
    required String profileId,
    required String polygonId,
    DateTime? visitedAt,
  }) async {
    final time = visitedAt ?? DateTime.now();

    final document = _visitedPolygons.doc(profileId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      final currentData = snapshot.data();
      final currentPolygonMap =
          (currentData?[_visitedPolygonsMapField] as Map<String, dynamic>?) ??
          <String, dynamic>{};

      final updatedPolygonMap = Map<String, dynamic>.from(currentPolygonMap)
        ..[polygonId] = Timestamp.fromDate(time);

      transaction.set(document, <String, dynamic>{
        'profile_id': profileId,
        _visitedPolygonsMapField: updatedPolygonMap,
      }, SetOptions(merge: true));
    });
  }

  /// Reads a profile by uid. Returns null when not found.
  Future<ProfileModel?> getProfile(String uid) async {
    final doc = await _profiles.doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return ProfileModel.fromMap(data);
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
    await _profiles.doc(uid).update(<String, dynamic>{
      'displayName': displayName,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

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

  VisitedPolygonRecord? _recordFromStoredMap(Map<String, dynamic> data) {
    final record = VisitedPolygonRecord.fromMap(data);

    if (record.profileId.isEmpty || record.polygonId.isEmpty) {
      return null;
    }

    return record;
  }
}
