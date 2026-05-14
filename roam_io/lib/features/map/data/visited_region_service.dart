/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Loads and persists visited region IDs while preserving first-time unlock
 *   results for duplicate XP prevention.
 */

import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/polygon_service.dart';

/// Persists region visits and reports whether each visit is a new unlock.
class VisitedRegionService {
  VisitedRegionService({FirebaseAuth? auth, PolygonService? polygonService})
    : _auth = auth ?? FirebaseAuth.instance,
      _polygonService = polygonService ?? PolygonService();

  final FirebaseAuth _auth;
  final PolygonService _polygonService;

  // Loads the set of region IDs the user has visited. Returns empty set if not
  Future<Set<String>> loadVisitedRegionIds() async {
    final user = _auth.currentUser;

    if (user == null) {
      return <String>{};
    }

    final records = await _polygonService.getVisitedPolygonRecords(
      profileId: user.uid,
    );

    return records.map((record) => record.polygonId).toSet();
  }

  // Marks a region as visited for the current user. Returns true only when the
  // persisted data confirms this is the first unlock for the user.
  Future<bool> markVisited(String regionId, {DateTime? visitedAt}) async {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    return _polygonService.upsertVisitedPolygon(
      profileId: user.uid,
      polygonId: regionId,
      visitedAt: visitedAt ?? DateTime.now(),
    );
  }
}
