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

import '../../../theme/app_surfaces.dart';
import '../../../theme/app_colours.dart';
import '../../party/data/party_service.dart';
import '../../party/providers/current_party_provider.dart';
import '../../party/screens/party_screen.dart';
import '../data/follow_service.dart';
import '../data/friendship_service.dart';
import '../domain/public_profile.dart';
import '../widgets/social_card.dart';
import '../widgets/social_layout.dart';
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
            _SocialHeader(
              onSearch: () {
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
            Expanded(
              child: SocialContentWidth(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    SocialLayout.gutter,
                    6,
                    SocialLayout.gutter,
                    118,
                  ),
                  children: [
                    _SocialDestinationCard(
                      title: 'Leaderboards',
                      subtitle: 'Compete with your social group!',
                      icon: Icons.leaderboard_rounded,
                      color: AppColors.sage,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LeaderboardScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: SocialLayout.rowGap),
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Large page title matching the Home header, with a Find People action.
class _SocialHeader extends StatelessWidget {
  const _SocialHeader({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Social',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: AppSurfaces.textPrimary(context),
                  fontSize: 32,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Find people',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            color: AppSurfaces.textPrimary(context),
            icon: const Icon(Icons.search),
            onPressed: onSearch,
          ),
        ],
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
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: SocialCard.borderRadius,
          focusColor: Colors.white.withValues(alpha: 0.12),
          splashColor: Colors.white.withValues(alpha: 0.16),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Ink(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: SocialCard.borderRadius,
              color: color,
              boxShadow: AppSurfaces.cardShadow(context),
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
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        // Pure white keeps AA contrast on both sage and clay.
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
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
