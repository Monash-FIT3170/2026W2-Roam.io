/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Displays a read-only public profile for another registered user loaded
 *   from public_profiles/{selectedUserId}. Analytics bind exclusively to
 *   selectedUserId (visits, tiles, xp_events, follow counts). Follow /
 *   Following is always the shared stadium relationship button (never plain
 *   text); Following taps unfollow immediately via
 *   follows/{followerId_followeeId}. Following/Followers stats open lists
 *   for selectedUserId.
 */

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import '../../../services/profile_service.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../theme/app_surfaces.dart';
import '../../activity_feed/data/activity_feed_service.dart';
import '../../activity_feed/data/comment_service.dart';
import '../../activity_feed/models/activity_feed_item.dart';
import '../../activity_feed/screens/activity_detail_screen.dart';
import '../../activity_feed/screens/comments_screen.dart';
import '../../activity_feed/widgets/activity_feed_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../map/data/visit.dart';
import '../../map/data/visit_service.dart';
import '../../map/data/visited_region_service.dart';
import '../../profile/domain/profile_stats.dart';
import '../../profile/domain/visited_polygon_record.dart';
import '../../profile/widgets/profile_identity_header.dart';
import '../../profile/widgets/profile_dashboard.dart';
import '../../you/providers/you_analytics_provider.dart';
import '../data/follow_service.dart';
import '../data/friendship_service.dart';
import '../data/social_privacy_service.dart';
import '../domain/follow_relationship_state.dart';
import '../domain/public_profile.dart';
import '../widgets/follow_relationship_button.dart';
import 'follow_connections_screen.dart';

/// Read-only social profile for a selected user.
class OtherUserProfileScreen extends StatefulWidget {
  const OtherUserProfileScreen({
    super.key,
    required this.selectedUserId,
    FriendshipService? friendshipService,
    VisitService? visitService,
    VisitedRegionService? visitedRegionService,
    ProfileService? profileService,
    FollowService? followService,
    SocialPrivacyService? privacyService,
    ActivityFeedService? activityFeedService,
    CommentService? commentService,
  }) : _friendshipService = friendshipService,
       _visitService = visitService,
       _visitedRegionService = visitedRegionService,
       _profileService = profileService,
       _followService = followService,
       _privacyService = privacyService,
       _activityFeedService = activityFeedService,
       _commentService = commentService;

  final String selectedUserId;
  final FriendshipService? _friendshipService;
  final VisitService? _visitService;
  final VisitedRegionService? _visitedRegionService;
  final ProfileService? _profileService;
  final FollowService? _followService;
  final SocialPrivacyService? _privacyService;
  final ActivityFeedService? _activityFeedService;
  final CommentService? _commentService;

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final FriendshipService _friendshipService;
  late final FollowService _followService;
  late final SocialPrivacyService _privacyService;
  late final ActivityFeedService _activityFeedService;
  late final CommentService? _commentService;
  late final YouAnalyticsProvider _analytics;
  ProfileGraphMetric _selectedGraphMetric = ProfileGraphMetric.locationsVisited;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _friendshipService = widget._friendshipService ?? FriendshipService();
    final hasFirebase = Firebase.apps.isNotEmpty;
    _followService =
        widget._followService ??
        (hasFirebase ? FollowService() : _EmptyFollowService());
    _privacyService =
        widget._privacyService ??
        (hasFirebase ? SocialPrivacyService() : _EmptySocialPrivacyService());
    _activityFeedService =
        widget._activityFeedService ??
        (hasFirebase ? ActivityFeedService() : _EmptyActivityFeedService());
    _commentService =
        widget._commentService ?? (hasFirebase ? CommentService() : null);
    _analytics = YouAnalyticsProvider(
      visitService:
          widget._visitService ?? (hasFirebase ? null : _EmptyVisitService()),
      visitedRegionService:
          widget._visitedRegionService ??
          (hasFirebase ? null : _EmptyVisitedRegionService()),
      profileService:
          widget._profileService ?? (hasFirebase ? ProfileService() : null),
      followService: _followService,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _analytics.dispose();
    super.dispose();
  }

  void _selectGraphMetric(ProfileGraphMetric metric) {
    if (_selectedGraphMetric == metric) return;
    setState(() {
      _selectedGraphMetric = metric;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId(context);

    return ChangeNotifierProvider<YouAnalyticsProvider>.value(
      value: _analytics,
      child: Scaffold(
        backgroundColor: AppSurfaces.pageBackground(context),
        appBar: AppBar(title: const Text('Profile')),
        body: SafeArea(
          child: StreamBuilder<PublicProfile?>(
            stream: _friendshipService.watchPublicProfile(
              widget.selectedUserId,
            ),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final profile = profileSnapshot.data;
              if (profile == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'This profile is unavailable.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppSurfaces.textMuted(context),
                      ),
                    ),
                  ),
                );
              }

              return StreamBuilder<SocialAccessPermissions>(
                stream: _privacyService.watchProfileActivityAccess(
                  viewerId: currentUserId,
                  profileId: widget.selectedUserId,
                ),
                builder: (context, accessSnapshot) {
                  if (accessSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      !accessSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final access =
                      accessSnapshot.data ??
                      SocialAccessPermissions(
                        canViewProfileActivity: !profile.isPrivateAccount,
                        isPrivateAccount: profile.isPrivateAccount,
                      );
                  _bindAnalytics(
                    access.canViewProfileActivity
                        ? widget.selectedUserId
                        : null,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ExternalProfileTabBar(controller: _tabController),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            access.canViewProfileActivity
                                ? _ExternalProfileDashboard(
                                    profile: profile,
                                    currentUserId: currentUserId,
                                    followService: _followService,
                                    friendshipService: _friendshipService,
                                    selectedMetric: _selectedGraphMetric,
                                    onMetricSelected: _selectGraphMetric,
                                  )
                                : _PrivateProfileSummary(
                                    profile: profile,
                                    currentUserId: currentUserId,
                                    followService: _followService,
                                    friendshipService: _friendshipService,
                                  ),
                            access.canViewProfileActivity
                                ? _ExternalActivitiesTab(
                                    selectedUserId: widget.selectedUserId,
                                    activityFeedService: _activityFeedService,
                                    commentService: _commentService,
                                  )
                                : const _PrivateActivitiesTab(),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _bindAnalytics(String? uid) {
    if (_analytics.boundUid == uid) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _analytics.bindUid(uid);
    });
  }

  String? _currentUserId(BuildContext context) {
    try {
      return context.watch<AuthProvider>().currentUser?.uid;
    } on ProviderNotFoundException {
      if (Firebase.apps.isEmpty) return null;
      return firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    }
  }
}

class _ExternalProfileTabBar extends StatelessWidget {
  const _ExternalProfileTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: AppSurfaces.textMuted(context),
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 3,
          dividerColor: AppSurfaces.border(context),
          labelStyle: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
          unselectedLabelStyle: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Activities'),
          ],
        ),
      ),
    );
  }
}

class _ExternalProfileDashboard extends StatelessWidget {
  const _ExternalProfileDashboard({
    required this.profile,
    required this.currentUserId,
    required this.followService,
    required this.friendshipService,
    required this.selectedMetric,
    required this.onMetricSelected,
  });

  final PublicProfile profile;
  final String? currentUserId;
  final FollowService followService;
  final FriendshipService friendshipService;
  final ProfileGraphMetric selectedMetric;
  final ValueChanged<ProfileGraphMetric> onMetricSelected;

  @override
  Widget build(BuildContext context) {
    final analytics = context.watch<YouAnalyticsProvider>();

    return ProfileDashboard(
      displayName: profile.displayName,
      username: profile.username,
      photoUrl: profile.photoUrl,
      level: profile.level,
      xp: profile.xp,
      headerAction: currentUserId == null || currentUserId == profile.uid
          ? null
          : FollowRelationshipButton(
              followerId: currentUserId!,
              followeeId: profile.uid,
              followService: followService,
              followeeProfile: profile,
              expandWidth: true,
            ),
      stats: ProfileStats(
        following: analytics.followingCount,
        followers: analytics.followerCount,
        tiles: analytics.tileCount,
        xpGained: profile.xp ?? 0,
        journeys: 0,
        sidequests: 0,
        onFollowingTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FollowConnectionsScreen(
                selectedUserId: profile.uid,
                mode: FollowConnectionsMode.following,
                followService: followService,
                friendshipService: friendshipService,
              ),
            ),
          );
        },
        onFollowersTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FollowConnectionsScreen(
                selectedUserId: profile.uid,
                mode: FollowConnectionsMode.followers,
                followService: followService,
                friendshipService: friendshipService,
              ),
            ),
          );
        },
      ),
      visits: analytics.visits,
      recentVisits: analytics.recentVisits,
      tileRecords: analytics.tileRecords,
      xpEvents: analytics.xpEvents,
      selectedMetric: selectedMetric,
      onMetricSelected: onMetricSelected,
      recentVisitsReady: analytics.recentVisitsReady,
      recentVisitsError: analytics.recentVisitsError,
      visitsError: analytics.visitsError,
      bottomPadding: AppBottomNavBar.clearanceFromScreenBottom(context) + 12,
    );
  }
}

class _PrivateProfileSummary extends StatelessWidget {
  const _PrivateProfileSummary({
    required this.profile,
    required this.currentUserId,
    required this.followService,
    required this.friendshipService,
  });

  final PublicProfile profile;
  final String? currentUserId;
  final FollowService followService;
  final FriendshipService friendshipService;

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        AppBottomNavBar.clearanceFromScreenBottom(context) + 12;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FollowCountHeader(
              profile: profile,
              currentUserId: currentUserId,
              followService: followService,
              friendshipService: friendshipService,
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppSurfaces.card(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppSurfaces.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Private account',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppSurfaces.textPrimary(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Follow this account to see their activity',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppSurfaces.textMuted(context),
                      fontWeight: FontWeight.w700,
                    ),
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

class _FollowCountHeader extends StatelessWidget {
  const _FollowCountHeader({
    required this.profile,
    required this.currentUserId,
    required this.followService,
    required this.friendshipService,
  });

  final PublicProfile profile;
  final String? currentUserId;
  final FollowService followService;
  final FriendshipService friendshipService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: followService.watchFollowingCount(profile.uid),
      builder: (context, followingSnapshot) {
        return StreamBuilder<int>(
          stream: followService.watchFollowerCount(profile.uid),
          builder: (context, followerSnapshot) {
            return ProfileIdentityHeader(
              displayName: profile.displayName,
              username: profile.username,
              photoUrl: profile.photoUrl,
              level: profile.level,
              xp: profile.xp,
              stats: [
                ProfileStatItem(
                  label: 'Following',
                  value: _formatCount(followingSnapshot.data ?? 0),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FollowConnectionsScreen(
                          selectedUserId: profile.uid,
                          mode: FollowConnectionsMode.following,
                          followService: followService,
                          friendshipService: friendshipService,
                        ),
                      ),
                    );
                  },
                ),
                ProfileStatItem(
                  label: 'Followers',
                  value: _formatCount(followerSnapshot.data ?? 0),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FollowConnectionsScreen(
                          selectedUserId: profile.uid,
                          mode: FollowConnectionsMode.followers,
                          followService: followService,
                          friendshipService: friendshipService,
                        ),
                      ),
                    );
                  },
                ),
              ],
              action: currentUserId == null || currentUserId == profile.uid
                  ? null
                  : FollowRelationshipButton(
                      followerId: currentUserId!,
                      followeeId: profile.uid,
                      followService: followService,
                      followeeProfile: profile,
                      expandWidth: true,
                    ),
            );
          },
        );
      },
    );
  }
}

class _PrivateActivitiesTab extends StatelessWidget {
  const _PrivateActivitiesTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Follow this account to see their activity',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppSurfaces.textMuted(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _formatCount(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index += 1) {
    final fromEnd = raw.length - index;
    buffer.write(raw[index]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

class _ExternalActivitiesTab extends StatelessWidget {
  const _ExternalActivitiesTab({
    required this.selectedUserId,
    required this.activityFeedService,
    required this.commentService,
  });

  final String selectedUserId;
  final ActivityFeedService activityFeedService;
  final CommentService? commentService;

  @override
  Widget build(BuildContext context) {
    final bottomClearance =
        AppBottomNavBar.clearanceFromScreenBottom(context) + 12;

    return StreamBuilder<List<ActivityFeedItem>>(
      stream: activityFeedService.watchPublicActivitiesForProfile(
        selectedUserId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final activities = snapshot.data ?? const <ActivityFeedItem>[];
        if (activities.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No activities yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppSurfaces.textMuted(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomClearance),
          itemCount: activities.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final activity = activities[index];
            return ActivityFeedCard.fromItem(
              activity,
              commentService: commentService,
              showKudos: true,
              showComments: true,
              showShare: false,
              onOverflowTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ActivityDetailScreen(activity: activity),
                  ),
                );
              },
              onKudosTap: () {},
              onCommentTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CommentsScreen(
                      activityId: activity.id,
                      commentService: commentService,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _EmptyVisitService implements VisitService {
  @override
  Stream<List<Visit>> watchAllVisits(String userId) {
    return Stream<List<Visit>>.value(const <Visit>[]);
  }

  @override
  Stream<List<Visit>> watchRecentVisits(String userId, {int limit = 5}) {
    return Stream<List<Visit>>.value(const <Visit>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyVisitedRegionService implements VisitedRegionService {
  @override
  Stream<List<VisitedPolygonRecord>> watchVisitedPolygonRecords({
    String? profileId,
  }) {
    return Stream<List<VisitedPolygonRecord>>.value(
      const <VisitedPolygonRecord>[],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyFollowService implements FollowService {
  @override
  Stream<bool> watchIsFollowing({
    required String followerId,
    required String followeeId,
  }) {
    return Stream<bool>.value(false);
  }

  @override
  Stream<FollowRelationshipState> watchFollowState({
    required String followerId,
    required String followeeId,
  }) {
    return Stream<FollowRelationshipState>.value(
      const FollowRelationshipState(
        status: FollowRelationshipStatus.notFollowing,
        isTargetPrivate: false,
      ),
    );
  }

  @override
  Stream<int> watchFollowingCount(String uid) {
    return Stream<int>.value(0);
  }

  @override
  Stream<int> watchFollowerCount(String uid) {
    return Stream<int>.value(0);
  }

  @override
  Stream<List<String>> watchFollowingIds(String uid) {
    return Stream<List<String>>.value(const <String>[]);
  }

  @override
  Stream<List<String>> watchFollowerIds(String uid) {
    return Stream<List<String>>.value(const <String>[]);
  }

  @override
  Future<void> follow({
    required String followerId,
    required String followeeId,
  }) {
    return Future<void>.value();
  }

  @override
  Future<void> followOrRequest({
    required String followerId,
    required String followeeId,
  }) {
    return Future<void>.value();
  }

  @override
  Future<void> unfollow({
    required String followerId,
    required String followeeId,
  }) {
    return Future<void>.value();
  }

  @override
  Future<void> cancelFollowRequest({
    required String requesterId,
    required String targetId,
  }) {
    return Future<void>.value();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptySocialPrivacyService implements SocialPrivacyService {
  @override
  Stream<SocialAccessPermissions> watchProfileActivityAccess({
    required String? viewerId,
    required String profileId,
  }) {
    return Stream<SocialAccessPermissions>.value(
      const SocialAccessPermissions(
        canViewProfileActivity: true,
        isPrivateAccount: false,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyActivityFeedService implements ActivityFeedService {
  @override
  Stream<List<ActivityFeedItem>> watchPublicActivitiesForProfile(
    String profileId,
  ) {
    return Stream<List<ActivityFeedItem>>.value(const <ActivityFeedItem>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
