/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 9 August 2026
 * Description:
 *   Provides the Social destination with Find People as the entry point.
 *   Private follow requests are managed from Notifications only.
 */

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../shared/widgets/app_page_header.dart';
import '../../../theme/app_surfaces.dart';
import '../../../theme/app_colours.dart';
import '../data/follow_service.dart';
import '../data/friendship_service.dart';
import '../domain/public_profile.dart';
import 'find_people_screen.dart';
import 'leaderboard_screen.dart';

/// Top-level Social tab for follow and community functionality.
class SocialScreen extends StatelessWidget {
  const SocialScreen({
    super.key,
    FriendshipService? friendshipService,
    FollowService? followService,
  }) : _friendshipService = friendshipService,
       _followService = followService;

  final FriendshipService? _friendshipService;
  final FollowService? _followService;

  @override
  Widget build(BuildContext context) {
    final friendshipService =
        _friendshipService ??
        (Firebase.apps.isNotEmpty
            ? FriendshipService()
            : _EmptyFriendshipService());

    return Container(
      color: AppSurfaces.pageBackground(context),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Social',
              subtitle: 'Follow and community tools',
              trailing: IconButton(
                tooltip: 'Find people',
                color: AppSurfaces.textPrimary(context),
                icon: const Icon(Icons.search),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FindPeopleScreen(
                        friendshipService: friendshipService,
                        followService: _followService,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LeaderboardScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.sage,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.leaderboard,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Leaderboards',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Compete with your social group!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFriendshipService implements FriendshipService {
  @override
  Future<List<PublicProfile>> searchUsers({
    required String query,
    required String currentUserId,
    int limit = 20,
  }) async {
    return const <PublicProfile>[];
  }

  @override
  Stream<PublicProfile?> watchPublicProfile(String uid) {
    return Stream<PublicProfile?>.value(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
