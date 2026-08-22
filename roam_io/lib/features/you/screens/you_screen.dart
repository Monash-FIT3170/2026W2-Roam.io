/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Provides the You destination with Profile and Activities tabs. Profile
 *   analytics are owned by YouAnalyticsProvider bound to the authenticated
 *   uid (visits, tiles, xp_events, follow counts). Following/Followers use
 *   the same follows collection as external profiles so counts update without
 *   manual refresh and open dedicated connection lists. A notifications bell
 *   opens the social inbox; numeric unread badges share SocialNotificationCoordinator
 *   state with the You nav item.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/profile_service.dart';
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
import '../../social/data/social_notification_coordinator.dart';
import '../../social/screens/follow_connections_screen.dart';
import '../../social/screens/notifications_screen.dart';
import '../../journeys/widgets/journey_share_sheet.dart';
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
    this.commentLikeService,
    this.kudosService,
    this.activityFeedService,
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
  final CommentLikeService? commentLikeService;
  final KudosService? kudosService;
  final ActivityFeedService? activityFeedService;

  @override
  State<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends State<YouScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final YouAnalyticsProvider _analytics;
  late final FollowService _followService;
  late final ActivityFeedService? _activityFeedService;
  ProfileGraphMetric _selectedGraphMetric = ProfileGraphMetric.locationsVisited;
  Stream<List<ActivityFeedItem>>? _profileMediaActivitiesStream;
  String? _profileMediaActivitiesStreamUserId;
  ActivityFeedService? _profileMediaActivitiesStreamService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // When tests inject VisitService without ProfileService, skip Firebase XP.
    final profileService =
        widget.profileService ??
        (widget.visitService != null ? null : ProfileService());
    _followService =
        widget.followService ??
        (widget.visitService != null ? _EmptyFollowService() : FollowService());
    _activityFeedService = widget.activityFeedService;
    _analytics = YouAnalyticsProvider(
      visitService: widget.visitService,
      visitedRegionService: widget.visitedRegionService,
      profileService: profileService,
      followService: _followService,
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

  Stream<List<ActivityFeedItem>>? _ownedProfileMediaActivitiesStream(
    String? currentUserId,
  ) {
    final activityFeedService = _activityFeedService;
    if (currentUserId == null || activityFeedService == null) {
      _profileMediaActivitiesStream = null;
      _profileMediaActivitiesStreamUserId = null;
      _profileMediaActivitiesStreamService = null;
      return null;
    }

    final hasCachedStream =
        _profileMediaActivitiesStream != null &&
        _profileMediaActivitiesStreamUserId == currentUserId &&
        identical(_profileMediaActivitiesStreamService, activityFeedService);
    if (hasCachedStream) return _profileMediaActivitiesStream;

    _profileMediaActivitiesStream = activityFeedService.watchActivitiesOwnedBy(
      currentUserId,
    );
    _profileMediaActivitiesStreamUserId = currentUserId;
    _profileMediaActivitiesStreamService = activityFeedService;
    return _profileMediaActivitiesStream;
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
                          currentUserId: uid,
                          followService: _followService,
                          mediaActivitiesStream:
                              _ownedProfileMediaActivitiesStream(uid),
                          selectedGraphMetric: _selectedGraphMetric,
                          onGraphMetricSelected: _selectGraphMetric,
                        ),
                        _ActivitiesTab(
                          activityFeedService: _activityFeedService,
                          currentUserId: uid,
                          commentService: widget.commentService,
                          commentLikeService: widget.commentLikeService,
                          kudosService: widget.kudosService,
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
    required this.mediaActivitiesStream,
    required this.selectedGraphMetric,
    required this.onGraphMetricSelected,
  });

  final ProfileModel? profile;
  final String? currentUserId;
  final FollowService followService;
  final Stream<List<ActivityFeedItem>>? mediaActivitiesStream;
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
        onFollowingTap: currentUserId == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FollowConnectionsScreen(
                      selectedUserId: currentUserId!,
                      mode: FollowConnectionsMode.following,
                      followService: followService,
                    ),
                  ),
                );
              },
        onFollowersTap: currentUserId == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FollowConnectionsScreen(
                      selectedUserId: currentUserId!,
                      mode: FollowConnectionsMode.followers,
                      followService: followService,
                    ),
                  ),
                );
              },
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
      mediaActivitiesStream: mediaActivitiesStream,
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

class _ActivitiesTab extends StatefulWidget {
  const _ActivitiesTab({
    required this.activityFeedService,
    required this.currentUserId,
    this.commentService,
    this.commentLikeService,
    this.kudosService,
  });

  final ActivityFeedService? activityFeedService;
  final String? currentUserId;
  final CommentService? commentService;
  final CommentLikeService? commentLikeService;
  final KudosService? kudosService;

  @override
  State<_ActivitiesTab> createState() => _ActivitiesTabState();
}

class _ActivitiesTabState extends State<_ActivitiesTab> {
  Stream<List<ActivityFeedItem>>? _activitiesStream;
  String? _activitiesStreamUserId;
  ActivityFeedService? _activitiesStreamService;

  Stream<List<ActivityFeedItem>> _ownedActivitiesStream() {
    final currentUserId = widget.currentUserId;
    final activityFeedService = widget.activityFeedService;
    if (currentUserId == null || activityFeedService == null) {
      if (_activitiesStream != null ||
          _activitiesStreamUserId != null ||
          _activitiesStreamService != null) {
        debugPrint(
          '[YouScreen] activities stream cleared currentUserId=$currentUserId '
          'hasActivityFeedService=${activityFeedService != null}',
        );
      }
      _activitiesStream = Stream<List<ActivityFeedItem>>.value(
        const <ActivityFeedItem>[],
      );
      _activitiesStreamUserId = null;
      _activitiesStreamService = null;
      return _activitiesStream!;
    }

    final hasCachedStream =
        _activitiesStream != null &&
        _activitiesStreamUserId == currentUserId &&
        identical(_activitiesStreamService, activityFeedService);
    if (hasCachedStream) return _activitiesStream!;

    debugPrint(
      '[YouScreen] activities stream created currentUserId=$currentUserId '
      'query=ownerId==$currentUserId',
    );
    _activitiesStream = activityFeedService.watchActivitiesOwnedBy(
      currentUserId,
    );
    _activitiesStreamUserId = currentUserId;
    _activitiesStreamService = activityFeedService;
    return _activitiesStream!;
  }

  @override
  Widget build(BuildContext context) {
    final bottomClearance =
        AppBottomNavBar.clearanceFromScreenBottom(context) + 12;
    final comments = widget.commentService;
    final stream = _ownedActivitiesStream();

    return StreamBuilder<List<ActivityFeedItem>>(
      stream: stream,
      builder: (context, snapshot) {
        debugPrint(
          '[YouScreen] activities builder currentUserId=${widget.currentUserId} '
          'hasActivityFeedService=${widget.activityFeedService != null} '
          'query=ownerId==${widget.currentUserId} '
          'connectionState=${snapshot.connectionState} '
          'hasError=${snapshot.hasError} hasData=${snapshot.hasData} '
          'renderedCount=${snapshot.data?.length ?? 0} '
          'titles=${_activityTitles(snapshot.data)}',
        );
        if (snapshot.hasError) {
          debugPrint('[YouScreen] activities failed ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
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
          padding: EdgeInsets.fromLTRB(24, 20, 24, bottomClearance),
          itemCount: activities.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final activity = activities[index];
            return ActivityFeedCard.fromItem(
              activity,
              commentService: comments,
              kudosService: widget.kudosService,
              currentUserId: widget.currentUserId,
              showKudos: true,
              showComments: true,
              showShare: true,
              onOverflowTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ActivityDetailScreen(
                      activity: activity,
                      showEngagementActions: true,
                      showShare: true,
                      currentUserId: widget.currentUserId,
                      commentService: comments,
                      commentLikeService: widget.commentLikeService,
                      kudosService: widget.kudosService,
                    ),
                  ),
                );
              },
              onCommentTap: () {
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
                      commentLikeService: widget.commentLikeService,
                    ),
                  ),
                );
              },
              onShareTap: () {
                JourneyShareSheet.shareFromActivity(context, activity);
              },
            );
          },
        );
      },
    );
  }
}

String _activityTitles(List<ActivityFeedItem>? activities) {
  if (activities == null || activities.isEmpty) return '';
  return activities.map((activity) => activity.title).join('|');
}
