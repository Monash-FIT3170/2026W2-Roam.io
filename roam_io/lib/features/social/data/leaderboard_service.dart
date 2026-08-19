import 'package:cloud_firestore/cloud_firestore.dart';

import '../../journeys/data/journey_service.dart';
import '../domain/leaderboard_entry.dart';
import 'follow_service.dart';

class LeaderboardService {
  LeaderboardService({
    FirebaseFirestore? firestore,
    JourneyService? journeyService,
    FollowService? followService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _journeyService = journeyService ?? JourneyService(),
        _followService = followService ?? FollowService();

  final FirebaseFirestore _firestore;
  final JourneyService _journeyService;
  final FollowService _followService;

  Future<List<LeaderboardEntry>> getLeaderboard(String currentUserId) async {
    // 1. Get following IDs
    List<String> userIds = [currentUserId];
    
    // watchFollowingIds returns a stream, we take the first value
    try {
      final following = await _followService.watchFollowingIds(currentUserId).first;
      userIds.addAll(following);
    } catch (e) {
      // In case the stream fails or is empty, we just continue with current user
    }

    // De-duplicate just in case
    userIds = userIds.toSet().toList();

    // 2. Fetch data for each user
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    
    final List<LeaderboardEntry> entries = [];
    
    for (final id in userIds) {
      // Fetch profile
      final profileDoc = await _firestore.collection('public_profiles').doc(id).get();
      if (!profileDoc.exists) continue;
      
      final data = profileDoc.data()!;
      final displayName = data['displayName'] as String? ?? 'Unknown';
      final photoUrl = data['photoUrl'] as String?;

      // Fetch journeys
      final journeys = await _journeyService.getJourneysSince(id, thirtyDaysAgo);

      int xpEarned = 0;

      for (final journey in journeys) {
        final jXp = journey.journeyXpEarned ?? journey.xpEarned ?? 0;
        final tXp = journey.tileXpEarned;
        xpEarned += (jXp + tXp);
      }

      entries.add(
        LeaderboardEntry(
          userId: id,
          displayName: displayName,
          photoUrl: photoUrl,
          xpEarned: xpEarned,
        ),
      );
    }

    return entries;
  }
}
