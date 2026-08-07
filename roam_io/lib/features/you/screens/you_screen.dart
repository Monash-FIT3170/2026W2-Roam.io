/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Provides the You destination with Profile and Activities tabs. Profile
 *   analytics are owned by YouAnalyticsProvider bound to the authenticated
 *   uid (visits, tiles, xp_events, follow counts). Following/Followers use
 *   the same follows collection as external profiles so counts update without
 *   manual refresh. A notifications bell opens the social inbox; unread
 *   badges share SocialNotificationCoordinator state with the You nav item.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/profile_service.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../theme/app_surfaces.dart';
import '../../activity_feed/data/comment_service.dart';
import '../../activity_feed/data/stub_activity_feed_data.dart';
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
import '../../social/data/social_notification_coordinator.dart';
import '../../social/screens/notifications_screen.dart';
import '../providers/you_analytics_provider.dart';

/// Displays personal profile analytics and the user's own activity area.
class YouScreen extends StatefulWidget {
  const YouScreen({
    super.key,
    this.visitService,
    this.visitedRegionService,
    this.profileService,
    this.followService,
    this.xpEventsStream,
    this.commentService,
  });

  /// Injected for tests; production uses the default [VisitService].
  final VisitService? visitService;

  /// Injected for tests; production uses the default [VisitedRegionService].
  final VisitedRegionService? visitedRegionService;

  /// Injected for tests; production uses the default [ProfileService].
  final ProfileService? profileService;

  /// Injected for tests; production uses the default [FollowService].
  final FollowService? followService;

  /// Injected XP event stream for tests; production watches Firestore.
  final Stream<List<XpEvent>>? xpEventsStream;

  /// Injected for tests; production receives a shared instance from MainShell.
  final CommentService? commentService;

  @override
  State<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends State<YouScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final YouAnalyticsProvider _analytics;
  ProfileGraphMetric _selectedGraphMetric = ProfileGraphMetric.locationsVisited;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // When tests inject VisitService without ProfileService, skip Firebase XP.
    final profileService =
        widget.profileService ??
        (widget.visitService != null ? null : ProfileService());
    final followService =
        widget.followService ??
        (widget.visitService != null ? _EmptyFollowService() : FollowService());
    _analytics = YouAnalyticsProvider(
      visitService: widget.visitService,
      visitedRegionService: widget.visitedRegionService,
      profileService: profileService,
      followService: followService,
      xpEventsStream: widget.xpEventsStream,
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
    return ChangeNotifierProvider<YouAnalyticsProvider>.value(
      value: _analytics,
      child: Container(
        color: AppSurfaces.pageBackground(context),
        child: SafeArea(
          bottom: false,
          child: Consumer2<AuthProvider, YouAnalyticsProvider>(
            builder: (context, auth, analytics, _) {
              final profile = auth.currentProfile;
              final uid = auth.currentUser?.uid;
              if (analytics.boundUid != uid) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _analytics.bindUid(uid);
                });
              }

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
                          selectedGraphMetric: _selectedGraphMetric,
                          onGraphMetricSelected: _selectGraphMetric,
                        ),
                        _ActivitiesTab(
                          profile: profile,
                          commentService: widget.commentService,
                        ),
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
    var hasUnread = false;
    try {
      hasUnread = context.watch<SocialNotificationCoordinator>().hasUnread;
    } on ProviderNotFoundException {
      hasUnread = false;
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
                  Tab(text: 'Activities'),
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
              if (hasUnread)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
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
    required this.selectedGraphMetric,
    required this.onGraphMetricSelected,
  });

  final ProfileModel? profile;
  final ProfileGraphMetric selectedGraphMetric;
  final ValueChanged<ProfileGraphMetric> onGraphMetricSelected;

  @override
  Widget build(BuildContext context) {
    final bottomClearance = AppBottomNavBar.clearanceFromScreenBottom(context);
    final analytics = context.watch<YouAnalyticsProvider>();

    return ProfileDashboard(
      displayName: profile?.displayName ?? '-',
      username: profile?.username ?? '-',
      photoUrl: profile?.photoUrl,
      level: profile?.level,
      xp: profile?.xp,
      stats: ProfileStats(
        following: analytics.followingCount,
        followers: analytics.followerCount,
        tiles: analytics.tileCount,
        xpGained: profile?.xp ?? 0,
        journeys: 0,
        sidequests: 0,
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
      bottomPadding: bottomClearance + 12,
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ActivitiesTab extends StatelessWidget {
  const _ActivitiesTab({required this.profile, this.commentService});

  final ProfileModel? profile;
  final CommentService? commentService;

  @override
  Widget build(BuildContext context) {
    final bottomClearance =
        AppBottomNavBar.clearanceFromScreenBottom(context) + 12;
    final activity = StubActivityFeedData.personalJourney.copyWith(
      displayName: profile?.displayName ?? 'Traveller',
      username: profile?.username,
      photoUrl: profile?.photoUrl,
    );
    final comments = commentService;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomClearance),
      child: ActivityFeedCard.fromItem(
        activity,
        commentService: comments,
        showKudos: true,
        showComments: true,
        showShare: true,
        onOverflowTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ActivityDetailScreen(activity: activity),
            ),
          );
        },
        onKudosTap: () {
          // Kudos persistence is not wired yet; keep the action visible.
        },
        onCommentTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CommentsScreen(
                activityId: activity.id,
                commentService: comments,
              ),
            ),
          );
        },
        onShareTap: () {
          // Activity sharing backend is deferred; preserve the Share action.
        },
      ),
    );
  }
}
