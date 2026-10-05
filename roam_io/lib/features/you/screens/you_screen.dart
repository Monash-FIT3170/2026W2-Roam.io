/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 4 October 2026 — Amarprit Singh
 * Description:
 *   Provides the You destination with Profile, Statistics, and Milestones tabs.
 *   Profile ([ProfileTab]) shows identity, this week's summary, recent badges
 *   and the owned journey feed in one scroll. Statistics owns detailed
 *   analytics via [StatsAnalyticsProvider]. Milestones owns claim progress via
 *   [MilestonesProvider]. A notifications bell opens the social inbox.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/profile_service.dart';
import '../../journeys/data/journey_service.dart';
import '../../../shared/widgets/app_page_transition.dart';
import '../../../theme/app_surfaces.dart';
import '../../activity_feed/data/activity_feed_service.dart';
import '../../activity_feed/data/comment_service.dart';
import '../../activity_feed/data/comment_like_service.dart';
import '../../activity_feed/data/kudos_service.dart';
import '../../activity_feed/models/activity_feed_item.dart';
import '../../auth/providers/auth_provider.dart';
import '../../map/data/visit_service.dart';
import '../../map/data/visited_region_service.dart';
import '../../party/providers/current_party_provider.dart';
import '../../profile/domain/xp_event.dart';
import '../../social/data/follow_service.dart';
import '../../social/data/friendship_service.dart';
import '../../social/data/social_notification_coordinator.dart';
import '../../social/screens/notifications_screen.dart';
import '../milestones/milestone_service.dart';
import '../milestones/milestones_provider.dart';
import '../milestones/milestones_screen.dart';
import '../providers/stats_analytics_provider.dart';
import '../services/home_base_service.dart';
import '../services/stats_summary_service.dart';
import '../widgets/profile/profile_tab.dart';
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

  /// Reconnects the owned-activities query for pull-to-refresh, completing
  /// once the new subscription delivers its first result.
  ///
  /// The feed is already live, so this mostly reassures; it does recover a
  /// subscription that died on an error.
  Future<void> _refreshOwnedActivities() async {
    final uid = _ownedActivitiesStreamUserId;
    final service = _ownedActivitiesStreamService;
    if (uid == null || service == null) return;

    final arrived = Completer<void>();
    void settle() {
      if (!arrived.isCompleted) arrived.complete();
    }

    setState(() {
      _ownedActivitiesStream = service
          .watchActivitiesOwnedBy(uid)
          .transform(
            StreamTransformer<
              List<ActivityFeedItem>,
              List<ActivityFeedItem>
            >.fromHandlers(
              handleData: (items, sink) {
                settle();
                sink.add(items);
              },
              handleError: (error, stackTrace, sink) {
                settle();
                sink.addError(error, stackTrace);
              },
            ),
          );
    });
    await arrived.future.timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  Stream<List<ActivityFeedItem>> _ownedActivitiesForProfileStream(
    String? currentUserId,
  ) {
    final activityFeedService = _activityFeedService;
    if (currentUserId == null || activityFeedService == null) {
      // Re-listenable like the Firestore query it stands in for: TabBarView
      // rebuilds the Profile tab each time it is revisited, and that rebuild
      // subscribes again to whatever stream was cached.
      _ownedActivitiesStream = Stream<List<ActivityFeedItem>>.multi((
        controller,
      ) {
        controller
          ..add(const <ActivityFeedItem>[])
          ..close();
      });
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
                        ProfileTab(
                          profile: profile,
                          currentUserId: uid,
                          followService: _followService,
                          friendshipService: _friendshipService,
                          ownedActivitiesStream: ownedActivitiesStream,
                          onRefresh: _refreshOwnedActivities,
                          commentService: widget.commentService,
                          commentLikeService: widget.commentLikeService,
                          kudosService: widget.kudosService,
                          onOpenStatistics: () => _tabController.animateTo(1),
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
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
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
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: AppSurfaces.border(context),
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(height: 40, text: 'Profile'),
                  Tab(height: 40, text: 'Statistics'),
                  Tab(height: 40, text: 'Milestones'),
                ],
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notifications',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: () {
                  final currentParty = context.read<CurrentPartyProvider>();
                  Navigator.of(context).push(
                    appHorizontalPageRoute<void>(
                      builder: (_) => NotificationsScreen(
                        currentPartyProvider: currentParty,
                      ),
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
