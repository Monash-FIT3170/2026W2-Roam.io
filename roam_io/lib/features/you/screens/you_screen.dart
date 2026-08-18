/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 16 August 2026
 * Description:
 *   Provides the You destination with Profile, Activities, Stats, and
 *   Milestones tabs. Profile shows identity header only; Stats owns analytics
 *   via [StatsAnalyticsProvider]. Milestones owns claim progress via
 *   [MilestonesProvider]. Activities shows the personal stub feed.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/profile_service.dart';
import '../../journeys/data/journey_service.dart';
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
import '../../profile/domain/xp_event.dart';
import '../milestones/milestone_service.dart';
import '../milestones/milestones_provider.dart';
import '../milestones/milestones_screen.dart';
import '../providers/stats_analytics_provider.dart';
import '../screens/stats_screen.dart';
import '../services/home_base_service.dart';
import '../services/stats_aggregation_service.dart';
import '../services/stats_summary_service.dart';
import '../widgets/profile_header.dart';

/// Displays profile identity, personal activities, stats, and milestones.
class YouScreen extends StatefulWidget {
  const YouScreen({
    super.key,
    this.visitService,
    this.visitedRegionService,
    this.profileService,
    this.xpEventsStream,
    this.commentService,
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

  /// Injected XP event stream for tests; production watches Firestore.
  final Stream<List<XpEvent>>? xpEventsStream;

  /// Injected for tests; production receives a shared instance from MainShell.
  final CommentService? commentService;

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
  final StatsAggregationService _aggregationService =
      const StatsAggregationService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final profileService =
        widget.profileService ??
        (widget.visitService != null ? null : ProfileService());
    _analytics = StatsAnalyticsProvider(
      visitService: widget.visitService,
      visitedRegionService: widget.visitedRegionService,
      profileService: profileService,
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
                          tileCount: _aggregationService.tileCountFromSummary(
                            analytics.statsSummary,
                            analytics.tileRecords,
                          ),
                          journeyCount: analytics.journeys.length,
                        ),
                        _ActivitiesTab(
                          profile: profile,
                          commentService: widget.commentService,
                        ),
                        StatsScreen(profile: profile),
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
            Tab(text: 'Stats'),
            Tab(text: 'Milestones'),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.profile,
    required this.tileCount,
    required this.journeyCount,
  });

  final ProfileModel? profile;
  final int tileCount;
  final int journeyCount;

  @override
  Widget build(BuildContext context) {
    final bottomClearance = AppBottomNavBar.clearanceFromScreenBottom(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 14, 24, bottomClearance + 12),
      child: ProfileHeader(
        profile: profile,
        tileCount: tileCount,
        journeyCount: journeyCount,
      ),
    );
  }
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
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activities',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppSurfaces.textPrimary(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ActivityFeedCard.fromItem(
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
        ],
      ),
    );
  }
}
