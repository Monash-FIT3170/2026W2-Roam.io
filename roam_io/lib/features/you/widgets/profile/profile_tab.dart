/*
 * Author: Amarprit Singh
 * Last Updated: 5 October 2026
 * Description:
 *   The You → Profile tab: a compact identity header, this week's totals
 *   and a one-row photo preview set straight on the page, then the
 *   traveller's journeys — the only cards, and the main content — under
 *   sticky week and month headers. The whole feed pulls to refresh.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../../shared/widgets/app_page_transition.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../theme/app_surfaces.dart';
import '../../../activity_feed/data/comment_like_service.dart';
import '../../../activity_feed/data/comment_service.dart';
import '../../../activity_feed/data/kudos_service.dart';
import '../../../activity_feed/models/activity_feed_item.dart';
import '../../../activity_feed/screens/activity_detail_screen.dart';
import '../../../activity_feed/screens/activity_media_gallery_screen.dart';
import '../../../activity_feed/screens/comments_screen.dart';
import '../../../activity_feed/widgets/activity_owner_actions.dart';
import '../../../journeys/domain/journey.dart';
import '../../../journeys/widgets/journey_share_sheet.dart';
import '../../../map/widgets/media_viewer.dart';
import '../../../profile/domain/profile_model.dart';
import '../../../profile/domain/profile_stats.dart';
import '../../../profile/domain/visited_polygon_record.dart';
import '../../../settings/screens/settings_screen.dart';
import '../../../social/data/follow_service.dart';
import '../../../social/data/friendship_service.dart';
import '../../../social/screens/follow_connections_screen.dart';
import '../../providers/stats_analytics_provider.dart';
import '../../services/profile_feed_builder.dart';
import 'journey_card.dart';
import 'journey_feed_states.dart';
import 'photo_strip.dart';
import 'profile_header.dart';
import 'weekly_summary.dart';

/// Gutter for text that sits directly on the page.
const double _textGutter = 16;

/// Gutter for cards: they run a little wider than the text column, so their
/// padded content lines up close to the page's text.
const double _cardGutter = 12;

class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.profile,
    required this.currentUserId,
    required this.followService,
    required this.friendshipService,
    required this.ownedActivitiesStream,
    required this.onRefresh,
    this.commentService,
    this.commentLikeService,
    this.kudosService,
    this.onOpenStatistics,
  });

  final ProfileModel? profile;
  final String? currentUserId;
  final FollowService followService;
  final FriendshipService friendshipService;

  /// The traveller's own posts, newest first. The query is capped at 20.
  final Stream<List<ActivityFeedItem>> ownedActivitiesStream;

  /// Reconnects the feed; completes once fresh data has arrived.
  final Future<void> Function() onRefresh;
  final CommentService? commentService;
  final CommentLikeService? commentLikeService;
  final KudosService? kudosService;
  final VoidCallback? onOpenStatistics;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  // The analytics provider notifies on every one of its many streams, so the
  // derived feed and weekly totals are only rebuilt when their inputs change.
  List<ActivityFeedItem>? _entriesFrom;
  List<Journey>? _entriesJourneys;
  int? _entriesDay;
  List<ProfileJourneyEntry> _entries = const <ProfileJourneyEntry>[];

  List<Journey>? _weeksJourneys;
  List<VisitedPolygonRecord>? _weeksTiles;
  int? _weeksDay;
  WeeklyActivityTotals? _thisWeek;
  int _streakWeeks = 0;

  List<ProfileJourneyEntry> _entriesFor(
    List<ActivityFeedItem> activities,
    List<Journey> journeys,
    DateTime now,
  ) {
    final day = _dayKey(now);
    if (!identical(activities, _entriesFrom) ||
        !identical(journeys, _entriesJourneys) ||
        day != _entriesDay) {
      _entriesFrom = activities;
      _entriesJourneys = journeys;
      _entriesDay = day;
      _entries = buildProfileJourneyEntries(
        activities: activities,
        journeys: journeys,
        now: now,
      );
    }
    return _entries;
  }

  void _syncWeeks(StatsAnalyticsProvider analytics, DateTime now) {
    final day = _dayKey(now);
    if (identical(analytics.journeys, _weeksJourneys) &&
        identical(analytics.tileRecords, _weeksTiles) &&
        day == _weeksDay) {
      return;
    }
    _weeksJourneys = analytics.journeys;
    _weeksTiles = analytics.tileRecords;
    _weeksDay = day;
    _thisWeek = buildWeeklyTotals(
      journeys: analytics.journeys,
      tileRecords: analytics.tileRecords,
      now: now,
      weeks: 1,
    ).single;
    _streakWeeks = journeyWeekStreak(journeys: analytics.journeys, now: now);
  }

  static int _dayKey(DateTime now) => now.year * 400 + now.month * 32 + now.day;

  @override
  Widget build(BuildContext context) {
    final analytics = context.watch<StatsAnalyticsProvider>();
    final now = DateTime.now();
    _syncWeeks(analytics, now);

    return StreamBuilder<List<ActivityFeedItem>>(
      stream: widget.ownedActivitiesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('[ProfileTab] activities failed ${snapshot.error}');
        }
        final activities = snapshot.data ?? const <ActivityFeedItem>[];

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          color: Theme.of(context).colorScheme.primary,
          child: CustomScrollView(
            key: const PageStorageKey<String>('you-profile-feed'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Identity and this week sit straight on the page; journeys are
              // the only cards, so they read as the content.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  _textGutter,
                  16,
                  _textGutter,
                  0,
                ),
                sliver: SliverList.list(
                  children: [
                    _buildHeader(context, analytics),
                    const SizedBox(height: 20),
                    WeeklySummary(
                      week:
                          _thisWeek ??
                          WeeklyActivityTotals(
                            weekStart: startOfProfileWeek(now),
                          ),
                      streakWeeks: _streakWeeks,
                      onTap: widget.onOpenStatistics,
                    ),
                    ..._photoSection(context, activities),
                    const SizedBox(height: 28),
                    Semantics(
                      header: true,
                      child: Text(
                        'Journeys',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppSurfaces.textPrimary(context),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ..._feedSlivers(context, snapshot, analytics.journeys, now),
              // Clears the floating nav bar so the last card can scroll fully
              // into view above it.
              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      AppBottomNavBar.clearanceFromScreenBottom(context) + 24,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The gallery preview, or nothing at all before the first photo.
  List<Widget> _photoSection(
    BuildContext context,
    List<ActivityFeedItem> activities,
  ) {
    final uid = widget.currentUserId;
    final media = [for (final activity in activities) ...activity.media];
    if (uid == null || media.isEmpty) return const <Widget>[];
    return [
      const SizedBox(height: 24),
      ProfilePhotoStrip(
        media: media,
        // The feed only loads the latest posts, so a full page may be hiding
        // older photos.
        moreAvailable: activities.length >= 20,
        onOpenGallery: () => _openGallery(context, uid),
        onOpenPhoto: (index) => MediaViewer.show(
          context: context,
          mediaUrls: [for (final item in media) item.url],
          initialIndex: index,
        ),
      ),
    ];
  }

  Widget _buildHeader(BuildContext context, StatsAnalyticsProvider analytics) {
    final uid = widget.currentUserId;
    final socialStats = ProfileStats(
      following: analytics.followingCount,
      followers: analytics.followerCount,
      tiles: null,
      xpGained: 0,
      journeys: 0,
      sidequests: 0,
      onFollowingTap: uid == null
          ? null
          : () => _openConnections(context, FollowConnectionsMode.following),
      onFollowersTap: uid == null
          ? null
          : () => _openConnections(context, FollowConnectionsMode.followers),
    ).toItems().take(2);

    return ProfileHeader(
      displayName: widget.profile?.displayName ?? '-',
      username: widget.profile?.username ?? '-',
      photoUrl: widget.profile?.photoUrl,
      // ProfileModel has no bio or home-area field yet; the line appears once
      // one is passed here.
      bio: null,
      onEditProfile: () => _openEditProfile(context),
      stats: [
        for (final stat in socialStats)
          ProfileHeaderStat(
            label: stat.label,
            value: stat.value,
            onTap: stat.onTap,
          ),
      ],
    );
  }

  List<Widget> _feedSlivers(
    BuildContext context,
    AsyncSnapshot<List<ActivityFeedItem>> snapshot,
    List<Journey> journeys,
    DateTime now,
  ) {
    if (snapshot.hasError && !snapshot.hasData) {
      return const [SliverToBoxAdapter(child: JourneyFeedMessage.error())];
    }
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(_cardGutter, 8, _cardGutter, 0),
          sliver: SliverList.list(
            children: const [
              JourneyCardSkeleton(),
              SizedBox(height: 12),
              JourneyCardSkeleton(),
            ],
          ),
        ),
      ];
    }

    final entries = _entriesFor(
      snapshot.data ?? const <ActivityFeedItem>[],
      journeys,
      now,
    );
    if (entries.isEmpty) {
      return const [SliverToBoxAdapter(child: JourneyFeedMessage.empty())];
    }

    final theme = Theme.of(context);
    final headerExtent = 24 + MediaQuery.textScalerOf(context).scale(15) * 1.35;
    return [
      for (final section in groupProfileFeed(entries, now: now))
        SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _SectionHeaderDelegate(
                title: section.title,
                summary: section.summary,
                extent: headerExtent,
                background: AppSurfaces.pageBackground(context),
                divider: AppSurfaces.border(context),
                titleStyle: theme.textTheme.titleSmall?.copyWith(
                  color: AppSurfaces.textPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                summaryStyle: theme.textTheme.bodySmall?.copyWith(
                  color: AppSurfaces.textMuted(context),
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            _sectionBody(section),
          ],
        ),
    ];
  }

  Widget _sectionBody(ProfileFeedSection section) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(_cardGutter, 4, _cardGutter, 24),
      sliver: SliverList.separated(
        itemCount: section.entries.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final entry = section.entries[index];
          return JourneyCard(
            key: ValueKey<String>('profile-journey-${entry.activity.id}'),
            entry: entry,
            currentUserId: widget.currentUserId,
            commentService: widget.commentService,
            kudosService: widget.kudosService,
            onOpen: () => _openActivity(context, entry),
            onMenu: () => _showJourneyOptions(context, entry),
            onCommentTap: () => _openComments(context, entry),
            onShareTap: () => JourneyShareSheet.shareFromActivity(
              context,
              entry.displayActivity,
              currentUserId: widget.currentUserId,
            ),
          );
        },
      ),
    );
  }

  Future<void> _showJourneyOptions(
    BuildContext context,
    ProfileJourneyEntry entry,
  ) async {
    final theme = Theme.of(context);
    final activity = entry.displayActivity;
    final isOwner = widget.currentUserId == activity.ownerId;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit or rename'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  // Seeded with the title the card shows, so saving without
                  // changes keeps what the traveller saw.
                  showEditActivityDialog(context: context, activity: activity);
                },
              ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('View activity'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openActivity(context, entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Share activity'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                JourneyShareSheet.shareFromActivity(
                  context,
                  activity,
                  currentUserId: widget.currentUserId,
                );
              },
            ),
            if (isOwner)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Delete activity',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  confirmDeleteActivity(
                    context: context,
                    activity: activity,
                    onDeleted: () {
                      if (context.mounted) {
                        AppToast.success(context, 'Activity deleted.');
                      }
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openActivity(BuildContext context, ProfileJourneyEntry entry) {
    Navigator.of(context).push(
      appHorizontalPageRoute<void>(
        builder: (_) => ActivityDetailScreen(
          activity: entry.displayActivity,
          showEngagementActions: true,
          showShare: true,
          currentUserId: widget.currentUserId,
          commentService: widget.commentService,
          commentLikeService: widget.commentLikeService,
          kudosService: widget.kudosService,
        ),
      ),
    );
  }

  void _openComments(BuildContext context, ProfileJourneyEntry entry) {
    final activity = entry.activity;
    Navigator.of(context).push(
      appHorizontalPageRoute<void>(
        builder: (_) => CommentsScreen(
          activityId: activity.id,
          activityOwnerId: activity.ownerId,
          commentService: widget.commentService,
          commentLikeService: widget.commentLikeService,
          title: widget.currentUserId == activity.ownerId
              ? 'Discussion'
              : 'Comments',
        ),
      ),
    );
  }

  void _openEditProfile(BuildContext context) {
    Navigator.of(context).push(
      appHorizontalPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: AppSurfaces.pageBackground(context),
          appBar: AppBar(title: const Text('Edit Profile')),
          body: const SettingsScreen(showPageHeader: false),
        ),
      ),
    );
  }

  void _openGallery(BuildContext context, String uid) {
    Navigator.of(context).push(
      appHorizontalPageRoute<void>(
        builder: (_) =>
            ActivityMediaGalleryScreen(profileId: uid, currentUserId: uid),
      ),
    );
  }

  void _openConnections(BuildContext context, FollowConnectionsMode mode) {
    final selectedUserId = widget.currentUserId;
    if (selectedUserId == null) return;
    Navigator.of(context).push(
      appHorizontalPageRoute<void>(
        builder: (_) => FollowConnectionsScreen(
          selectedUserId: selectedUserId,
          mode: mode,
          followService: widget.followService,
          friendshipService: widget.friendshipService,
        ),
      ),
    );
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SectionHeaderDelegate({
    required this.title,
    required this.summary,
    required this.extent,
    required this.background,
    required this.divider,
    required this.titleStyle,
    required this.summaryStyle,
  });

  final String title;
  final String summary;
  final double extent;
  final Color background;
  final Color divider;
  final TextStyle? titleStyle;
  final TextStyle? summaryStyle;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Persistent headers are laid out with loose constraints, so the header
    // has to fill its declared extent itself or the sliver's geometry breaks.
    return Semantics(
      header: true,
      child: Container(
        height: extent,
        decoration: BoxDecoration(
          color: background,
          border: overlapsContent
              ? Border(bottom: BorderSide(color: divider))
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _textGutter),
          child: Row(
            children: [
              // Shares the row with the summary, so very large text truncates
              // rather than pushing either off the edge.
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: summaryStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.summary != summary ||
        oldDelegate.extent != extent ||
        oldDelegate.background != background ||
        oldDelegate.divider != divider ||
        oldDelegate.titleStyle != titleStyle ||
        oldDelegate.summaryStyle != summaryStyle;
  }
}
