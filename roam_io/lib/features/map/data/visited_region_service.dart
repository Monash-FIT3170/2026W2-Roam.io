/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 21 August 2026
 * Description:
 *   Loads and persists visited region IDs and timestamped unlock records while
 *   preserving first-time unlock results for duplicate XP prevention.
 */

import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/polygon_service.dart';
import '../../profile/domain/visited_polygon_meta.dart';
import '../../profile/domain/visited_polygon_record.dart';

/// Persists region visits and reports whether each visit is a new unlock.
class VisitedRegionService {
  VisitedRegionService({FirebaseAuth? auth, PolygonService? polygonService})
    : _auth = auth,
      _polygonService = polygonService ?? PolygonService();

  final FirebaseAuth? _auth;
  final PolygonService _polygonService;

  FirebaseAuth get _resolvedAuth => _auth ?? FirebaseAuth.instance;

  // Loads the set of region IDs the user has visited. Returns empty set if not
  Future<Set<String>> loadVisitedRegionIds() async {
    final user = _resolvedAuth.currentUser;

    if (user == null) {
      return <String>{};
    }

    final records = await _polygonService.getVisitedPolygonRecords(
      profileId: user.uid,
    );

    return records.map((record) => record.polygonId).toSet();
  }

  // Streams the set of region IDs the user has visited. Emits an empty set if
  // no user is signed in.
  Stream<Set<String>> watchVisitedRegionIds() {
    final user = _resolvedAuth.currentUser;

    if (user == null) {
      return Stream<Set<String>>.value(<String>{});
    }

    return _polygonService
        .watchVisitedPolygonRecords(profileId: user.uid)
        .map((records) => records.map((record) => record.polygonId).toSet());
  }

  /// Streams timestamped tile unlock records for profile analytics.
  Stream<List<VisitedPolygonRecord>> watchVisitedPolygonRecords({
    String? profileId,
  }) {
    final resolvedProfileId = profileId ?? _resolvedAuth.currentUser?.uid;

    if (resolvedProfileId == null) {
      return Stream<List<VisitedPolygonRecord>>.value(
        const <VisitedPolygonRecord>[],
      );
    }

    return _polygonService.watchVisitedPolygonRecords(
      profileId: resolvedProfileId,
    );
  }

  /// Streams enriched unlock metadata for tile analytics.
  Stream<Map<String, VisitedPolygonMeta>> watchVisitedPolygonMeta() {
    final user = _resolvedAuth.currentUser;

    if (user == null) {
      return Stream<Map<String, VisitedPolygonMeta>>.value(
        const <String, VisitedPolygonMeta>{},
      );
    }

    return _polygonService.watchVisitedPolygonMeta(profileId: user.uid);
  }

  /// Streams tile re-entry counts for loyalty analytics.
  Stream<Map<String, int>> watchPolygonEntryCounts() {
    final user = _resolvedAuth.currentUser;

    if (user == null) {
      return Stream<Map<String, int>>.value(const <String, int>{});
    }

    return _polygonService.watchPolygonEntryCounts(profileId: user.uid);
  }

  // Marks a region as visited for the current user. Returns true only when the
  // persisted data confirms this is the first unlock for the user.
  Future<bool> markVisited(
    String regionId, {
    DateTime? visitedAt,
    double? areaSquareMetres,
    String? name,
  }) async {
    final user = _resolvedAuth.currentUser;

    if (user == null) {
      return false;
    }

    return _polygonService.upsertVisitedPolygon(
      profileId: user.uid,
      polygonId: regionId,
      visitedAt: visitedAt ?? DateTime.now(),
      areaSquareMetres: areaSquareMetres,
      name: name,
    );
  }
}

/// Non-breaking helpers for loading visited region ids for a specific profile.
extension VisitedRegionServiceProfileReads on VisitedRegionService {
  Future<Set<String>> loadVisitedRegionIdsForProfile(String profileId) async {
    final records = await watchVisitedPolygonRecords(
      profileId: profileId,
    ).first;
    return records.map((record) => record.polygonId).toSet();
  }
}
