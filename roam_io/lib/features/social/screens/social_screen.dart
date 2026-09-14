/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 9 August 2026
 * Description:
 *   Provides the Social destination with Find People, leaderboards, and
 *   Party Mode entry points.
 *   Private follow requests are managed from Notifications only.
 */

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_page_header.dart';
import '../../../theme/app_surfaces.dart';
import '../../../theme/app_colours.dart';
import '../../party/data/party_service.dart';
import '../../party/providers/current_party_provider.dart';
import '../../party/screens/party_screen.dart';
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
    PartyService? partyService,
  }) : _friendshipService = friendshipService,
       _followService = followService,
       _partyService = partyService;

  final FriendshipService? _friendshipService;
  final FollowService? _followService;
  final PartyService? _partyService;

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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 118),
                children: [
                  _SocialDestinationCard(
                    title: 'Leaderboards',
                    subtitle: 'Compete with your social group!',
                    icon: Icons.leaderboard,
                    color: AppColors.sage,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LeaderboardScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SocialDestinationCard(
                    title: 'Party Mode',
                    subtitle: 'Team up and claim map tiles together.',
                    icon: Icons.groups_rounded,
                    color: AppColors.clay,
                    onTap: () {
                      final currentParty = context
                          .read<CurrentPartyProvider?>();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PartyScreen(
                            partyService: _partyService ?? PartyService(),
                            initialParty: currentParty?.currentParty,
                            onPartyChanged: currentParty?.setParty,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialDestinationCard extends StatelessWidget {
  const _SocialDestinationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
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
