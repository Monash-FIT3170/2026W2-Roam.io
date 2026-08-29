/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 29 August 2026 — Sanjevan Rajasegar
 * Description:
 *   Provides the You destination with Profile, Statistics, and Milestones tabs.
 *   Profile shows identity, social counts, media, dashboard statistics, and
 *   owned activities in one scroll. Statistics owns detailed analytics via
 *   [StatsAnalyticsProvider]. Milestones owns claim progress via
 *   [MilestonesProvider]. A notifications bell opens the social inbox.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/profile_service.dart';
import '../../journeys/data/journey_service.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../theme/app_surfaces.dart';
import '../../activity_feed/data/activity_feed_service.dart';
import '../../activity_feed/data/comment_service.dart';
import '../../activity_feed/data/comment_like_service.dart';
import '../../activity_feed/data/kudos_service.dart';
import '../../activity_feed/models/activity_feed_item.dart';
import '../../activity_feed/screens/activity_detail_screen.dart';
import '../../activity_feed/screens/comments_screen.dart';
import '../../activity_feed/widgets/activity_feed_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../map/data/visit_service.dart';
import '../../map/data/visited_region_service.dart';
import '../../profile/domain/profile_model.dart';
import '../../profile/domain/profile_stats.dart';
import '../../profile/domain/xp_event.dart';
import '../../profile/widgets/profile_dashboard.dart';
import '../../social/data/follow_service.dart';
import '../../social/data/friendship_service.dart';
import '../../social/data/social_notification_coordinator.dart';
import '../../social/screens/follow_connections_screen.dart';
import '../../social/screens/notifications_screen.dart';
import '../../journeys/widgets/journey_share_sheet.dart';
import '../milestones/milestone_service.dart';
import '../milestones/milestones_provider.dart';
import '../milestones/milestones_screen.dart';
import '../providers/stats_analytics_provider.dart';
import '../services/home_base_service.dart';
import '../services/stats_summary_service.dart';
import 'stats_screen.dart';

/// Displays personal profile analytics and the user's own activity area.
class YouScreen extends StatefulWidget {
  const YouScreen({
    super.key,
    this.visitService,
    this.visitedRegionService,
    this.profileService,
    this.followService,
    this.friendshipService,
    this.xpEventsStream,
    this.commentService,
    this.commentLikeService,
    this.kudosService,
    this.activityFeedService,
    this.journeyService,
    this.statsSummaryService,
    this.homeBaseService,
    this.milestoneService,
  });

  /// Injected for tests; production uses the default [VisitService].
  final VisitService? visitService;

  /// Injected for tests; production uses the default [VisitedRegionService].
  final VisitedRegionService? visitedRegionService;

  /// Injected for tests; production uses the default [ProfileService].
  final ProfileService? profileService;

  /// Injected for tests; production uses the default [FollowService].
  final FollowService? followService;

  /// Injected for tests; production uses the default [FriendshipService].
  final FriendshipService? friendshipService;

  /// Injected XP event stream for tests; production watches Firestore.
  final Stream<List<XpEvent>>? xpEventsStream;

  /// Injected for tests; production receives a shared instance from MainShell.
  final CommentService? commentService;
  final CommentLikeService? commentLikeService;
  final KudosService? kudosService;
  final ActivityFeedService? activityFeedService;

  /// Injected for tests; production uses the default [JourneyService].
  final JourneyService? journeyService;

  /// Injected for tests; production uses the default [StatsSummaryService].
  final StatsSummaryService? statsSummaryService;

  /// Injected for tests; production uses the default [HomeBaseService].
  final HomeBaseService? homeBaseService;

  /// Injected for tests; production uses the default [MilestoneService].
  final MilestoneService? milestoneService;

  @override
  State<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends State<YouScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final StatsAnalyticsProvider _analytics;
  late final MilestonesProvider _milestones;
  late final FollowService _followService;
  late final FriendshipService _friendshipService;
  late final ActivityFeedService? _activityFeedService;
  ProfileGraphMetric _selectedGraphMetric = ProfileGraphMetric.locationsVisited;
  Stream<List<ActivityFeedItem>>? _ownedActivitiesStream;
  String? _ownedActivitiesStreamUserId;
  ActivityFeedService? _ownedActivitiesStreamService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final profileService =
        widget.profileService ??
        (widget.visitService != null ? null : ProfileService());
    _followService =
        widget.followService ??
        (widget.visitService != null ? _EmptyFollowService() : FollowService());
    _friendshipService =
        widget.friendshipService ??
        (widget.visitService != null
            ? _EmptyFriendshipService()
            : FriendshipService());
    _activityFeedService = widget.activityFeedService;
    _analytics = StatsAnalyticsProvider(
      visitService: widget.visitService,
      visitedRegionService: widget.visitedRegionService,
      profileService: profileService,
      followService: _followService,
      xpEventsStream: widget.xpEventsStream,
      journeyService: widget.journeyService,
      statsSummaryService: widget.statsSummaryService,
      homeBaseService: widget.homeBaseService,
    );
    _milestones = MilestonesProvider(
      analytics: _analytics,
      milestoneService: widget.milestoneService,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _milestones.dispose();
    _analytics.dispose();
    super.dispose();
  }

  void _selectGraphMetric(ProfileGraphMetric metric) {
    if (_selectedGraphMetric == metric) return;
    setState(() {
      _selectedGraphMetric = metric;
    });
  }

  Stream<List<ActivityFeedItem>> _ownedActivitiesForProfileStream(
    String? currentUserId,
  ) {
    final activityFeedService = _activityFeedService;
    if (currentUserId == null || activityFeedService == null) {
      _ownedActivitiesStream = Stream<List<ActivityFeedItem>>.value(
        const <ActivityFeedItem>[],
      );
      _ownedActivitiesStreamUserId = null;
      _ownedActivitiesStreamService = null;
      return _ownedActivitiesStream!;
    }

    final hasCachedStream =
        _ownedActivitiesStream != null &&
        _ownedActivitiesStreamUserId == currentUserId &&
        identical(_ownedActivitiesStreamService, activityFeedService);
    if (hasCachedStream) return _ownedActivitiesStream!;

    debugPrint(
      '[YouScreen] activities stream created currentUserId=$currentUserId '
      'query=ownerId==$currentUserId',
    );
    _ownedActivitiesStream = activityFeedService.watchActivitiesOwnedBy(
      currentUserId,
    );
    _ownedActivitiesStreamUserId = currentUserId;
    _ownedActivitiesStreamService = activityFeedService;
    return _ownedActivitiesStream!;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<StatsAnalyticsProvider>.value(value: _analytics),
        ChangeNotifierProvider<MilestonesProvider>.value(value: _milestones),
      ],
      child: Container(
        color: AppSurfaces.pageBackground(context),
        child: SafeArea(
          bottom: false,
          child: Consumer2<AuthProvider, StatsAnalyticsProvider>(
            builder: (context, auth, analytics, _) {
              final profile = auth.currentProfile;
              final uid = auth.currentUser?.uid;
              if (analytics.boundUid != uid) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _analytics.bindUid(uid);
                  _milestones.bindUid(uid);
                });
              } else if (_milestones.boundUid != uid) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _milestones.bindUid(uid);
                });
              }
              final ownedActivitiesStream = _ownedActivitiesForProfileStream(
                uid,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _YouTabBar(controller: _tabController),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _ProfileTab(
                          profile: profile,
                          currentUserId: uid,
                          followService: _followService,
                          friendshipService: _friendshipService,
                          ownedActivitiesStream: ownedActivitiesStream,
                          commentService: widget.commentService,
                          commentLikeService: widget.commentLikeService,
                          kudosService: widget.kudosService,
                          selectedGraphMetric: _selectedGraphMetric,
                          onGraphMetricSelected: _selectGraphMetric,
                        ),
                        StatsScreen(profile: profile, title: 'Statistics'),
                        const MilestonesScreen(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _YouTabBar extends StatelessWidget {
  const _YouTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var unreadCount = 0;
    try {
      unreadCount = context.watch<SocialNotificationCoordinator>().unreadCount;
    } on ProviderNotFoundException {
      unreadCount = 0;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
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
                  Tab(text: 'Statistics'),
                  Tab(text: 'Milestones'),
                ],
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: AppSurfaces.textPrimary(context),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.profile,
    required this.currentUserId,
    required this.followService,
    required this.friendshipService,
    required this.ownedActivitiesStream,
    required this.commentService,
    required this.commentLikeService,
    required this.kudosService,
    required this.selectedGraphMetric,
    required this.onGraphMetricSelected,
  });

  final ProfileModel? profile;
  final String? currentUserId;
  final FollowService followService;
  final FriendshipService friendshipService;
  final Stream<List<ActivityFeedItem>> ownedActivitiesStream;
  final CommentService? commentService;
  final CommentLikeService? commentLikeService;
  final KudosService? kudosService;
  final ProfileGraphMetric selectedGraphMetric;
  final ValueChanged<ProfileGraphMetric> onGraphMetricSelected;

  @override
  Widget build(BuildContext context) {
    final analytics = context.watch<StatsAnalyticsProvider>();
    final bottomClearance = AppBottomNavBar.clearanceFromScreenBottom(context);

    final displayName = profile?.displayName ?? '-';
    final username = profile?.username ?? '-';

    return StreamBuilder<List<ActivityFeedItem>>(
      stream: ownedActivitiesStream,
      builder: (context, snapshot) {
        debugPrint(
          '[YouScreen] activities builder currentUserId=$currentUserId '
          'query=ownerId==$currentUserId '
          'connectionState=${snapshot.connectionState} '
          'hasError=${snapshot.hasError} hasData=${snapshot.hasData} '
          'renderedCount=${snapshot.data?.length ?? 0} '
          'titles=${_activityTitles(snapshot.data)}',
        );
        if (snapshot.hasError) {
          debugPrint('[YouScreen] activities failed ${snapshot.error}');
        }

        return ProfileDashboard(
          displayName: displayName,
          username: username,
          photoUrl: profile?.photoUrl,
          level: profile?.level,
          xp: profile?.xp,
          stats: ProfileStats(
            following: analytics.followingCount,
            followers: analytics.followerCount,
            tiles: analytics.tileCount,
            xpGained: profile?.xp ?? 0,
            journeys: analytics.journeys.length,
            sidequests: 0,
            onFollowingTap: currentUserId == null
                ? null
                : () => _openConnections(
                    context,
                    mode: FollowConnectionsMode.following,
                  ),
            onFollowersTap: currentUserId == null
                ? null
                : () => _openConnections(
                    context,
                    mode: FollowConnectionsMode.followers,
                  ),
          ),
          visits: analytics.visits,
          recentVisits: analytics.recentVisits,
          tileRecords: analytics.tileRecords,
          xpEvents: analytics.xpEvents,
          selectedMetric: selectedGraphMetric,
          onMetricSelected: onGraphMetricSelected,
          recentVisitsReady: analytics.recentVisitsReady,
          recentVisitsError: analytics.recentVisitsError,
          visitsError: analytics.visitsError,
          mediaProfileId: currentUserId,
          currentUserId: currentUserId,
          mediaActivities: snapshot.data,
          showDetailedAnalytics: false,
          trailingChildren: [
            _OwnedActivitiesList(
              snapshot: snapshot,
              currentUserId: currentUserId,
              commentService: commentService,
              commentLikeService: commentLikeService,
              kudosService: kudosService,
            ),
          ],
          bottomPadding: bottomClearance + 12,
        );
      },
    );
  }

  void _openConnections(
    BuildContext context, {
    required FollowConnectionsMode mode,
  }) {
    final selectedUserId = currentUserId;
    if (selectedUserId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FollowConnectionsScreen(
          selectedUserId: selectedUserId,
          mode: mode,
          followService: followService,
          friendshipService: friendshipService,
        ),
      ),
    );
  }
}

class _EmptyFollowService implements FollowService {
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyFriendshipService implements FriendshipService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OwnedActivitiesList extends StatelessWidget {
  const _OwnedActivitiesList({
    required this.snapshot,
    required this.currentUserId,
    required this.commentService,
    required this.commentLikeService,
    required this.kudosService,
  });

  final AsyncSnapshot<List<ActivityFeedItem>> snapshot;
  final String? currentUserId;
  final CommentService? commentService;
  final CommentLikeService? commentLikeService;
  final KudosService? kudosService;

  @override
  Widget build(BuildContext context) {
    final comments = commentService;

    if (snapshot.hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Text(
            'Could not load activities. Try again.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppSurfaces.textMuted(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    final activities = snapshot.data ?? const <ActivityFeedItem>[];
    if (activities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          for (var index = 0; index < activities.length; index += 1) ...[
            ActivityFeedCard.fromItem(
              activities[index],
              commentService: comments,
              kudosService: kudosService,
              currentUserId: currentUserId,
              showKudos: true,
              showComments: true,
              showShare: true,
              onOverflowTap: () => _openActivity(context, activities[index]),
              onCommentTap: () =>
                  _openComments(context, comments, activities[index]),
              onShareTap: () {
<<<<<<< HEAD
                JourneyShareSheet.shareFromActivity(
                  context,
                  activity,
                  currentUserId: widget.currentUserId,
                );
=======
                JourneyShareSheet.shareFromActivity(context, activities[index]);
>>>>>>> b473360 (ART2-83: Improving certain UI components within the app and the user's profile post-merge)
              },
            ),
            if (index != activities.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  void _openActivity(BuildContext context, ActivityFeedItem activity) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivityDetailScreen(
          activity: activity,
          showEngagementActions: true,
          showShare: true,
          currentUserId: currentUserId,
          commentService: commentService,
          commentLikeService: commentLikeService,
          kudosService: kudosService,
        ),
      ),
    );
  }

  void _openComments(
    BuildContext context,
    CommentService? comments,
    ActivityFeedItem activity,
  ) {
    debugPrint(
      '[YouScreen] open comments activityId=${activity.id} '
      'ownerId=${activity.ownerId}',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommentsScreen(
          activityId: activity.id,
          activityOwnerId: activity.ownerId,
          commentService: comments,
          commentLikeService: commentLikeService,
        ),
      ),
    );
  }
}

String _activityTitles(List<ActivityFeedItem>? activities) {
  if (activities == null || activities.isEmpty) return '';
  return activities.map((activity) => activity.title).join('|');
}
