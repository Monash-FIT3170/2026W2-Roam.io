import 'package:firebase_auth/firebase_auth.dart';
import '../../services/polygon_service.dart';

/*
 * Author: Amarprit Singh
 * Last Modified: 07/05/2026
 * Description:
 * 
 *   VisitedRegionServive reads and writes the user's visited region IDs from the database
 *   and stores them in visitedPolygoIds for map_controller to cache.
 *   Thus we can check the visited polygons locally in O(1) time when rendering the map
 * 
 */


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

  // Marks a region as visited for the current user. Returns false if no user is
  Future<bool> markVisited(String regionId, {DateTime? visitedAt}) async {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    await _polygonService.upsertVisitedPolygon(
      profileId: user.uid,
      polygonId: regionId,
      visitedAt: visitedAt ?? DateTime.now(),
    );

    return true;
  }
}
