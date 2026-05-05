// Owns visited-region persistence for the map feature behind a small API. This
// keeps auth and Firestore details out of the map controller so it can focus
// on UI state and orchestration.

import 'package:firebase_auth/firebase_auth.dart';

import '../../services/profile_service.dart';

class VisitedRegionService {
  VisitedRegionService({FirebaseAuth? auth, ProfileService? profileService})
    : _auth = auth ?? FirebaseAuth.instance,
      _profileService = profileService ?? ProfileService();

  final FirebaseAuth _auth;
  final ProfileService _profileService;

  // Loads the set of region IDs the user has visited. Returns empty set if not
  Future<Set<String>> loadVisitedRegionIds() async {
    final user = _auth.currentUser;

    if (user == null) {
      return <String>{};
    }

    final records = await _profileService.getVisitedPolygonRecords(
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

    await _profileService.upsertVisitedPolygon(
      profileId: user.uid,
      polygonId: regionId,
      visitedAt: visitedAt ?? DateTime.now(),
    );

    return true;
  }
}
