/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Home destination showing persisted own/followed activities.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../activity_feed/data/activity_feed_service.dart';
import '../../activity_feed/data/activity_mutation_service.dart';
import '../../activity_feed/data/comment_like_service.dart';
import '../../activity_feed/data/comment_service.dart';
import '../../activity_feed/data/kudos_service.dart';
import '../../activity_feed/models/activity_feed_item.dart';
import '../../activity_feed/screens/activity_detail_screen.dart';
import '../../activity_feed/screens/comments_screen.dart';
import '../../activity_feed/widgets/activity_feed_card.dart';
import '../../activity_feed/widgets/activity_owner_actions.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/data/follow_service.dart';
import '../../social/widgets/private_follow_confirm.dart';
import '../../journeys/widgets/journey_share_sheet.dart';

/// Top-level Home tab for the friend activity feed foundation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.commentService,
    this.commentLikeService,
    this.kudosService,
    this.activityFeedService,
    this.followService,
    this.mutationService,
  });

  /// Injected for tests; production receives a shared instance from [MainShellScreen].
  final CommentService? commentService;
  final CommentLikeService? commentLikeService;
  final KudosService? kudosService;
  final ActivityFeedService? activityFeedService;
  final FollowService? followService;
  final ActivityMutationService? mutationService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Stream<List<ActivityFeedItem>>? _realActivitiesStream;
  String? _realActivitiesStreamUserId;
  ActivityFeedService? _realActivitiesStreamActivityService;
  FollowService? _realActivitiesStreamFollowService;

  @override
  Widget build(BuildContext context) {
    final bottomClearance =
        AppBottomNavBar.clearanceFromScreenBottom(context) + 12;
    final comments = widget.commentService;
    String? currentUserId;
    try {
      currentUserId = context.watch<AuthProvider>().currentUser?.uid;
    } on ProviderNotFoundException {
      currentUserId = null;
    }
    final realActivitiesStream = _homeActivitiesStream(currentUserId);

    return Container(
      color: AppSurfaces.pageBackground(context),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Home',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Roam.io',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 18,
                      height: 1.1,
                      color: AppColors.sage,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Image.asset(
                    'assets/logos/roam_io_logo_transparent.png',
                    height: 16,
                    width: 16,
                    color: AppColors.sage,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) {
                  const fadeHeight = 20.0;
                  final stop = (fadeHeight / rect.height).clamp(0.0, 1.0);
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [Colors.transparent, Colors.black],
                    stops: [0.0, stop],
                  ).createShader(rect);
                },
                child: StreamBuilder<List<ActivityFeedItem>>(
                  stream: realActivitiesStream,
                  builder: (context, snapshot) {
                    debugPrint(
                      '[HomeScreen] activity builder currentUserId=$currentUserId '
                      'connectionState=${snapshot.connectionState} '
                      'hasError=${snapshot.hasError} '
                      'hasData=${snapshot.hasData} '
                      'renderedCount=${snapshot.data?.length ?? 0} '
                      'titles=${_activityTitles(snapshot.data)}',
                    );
                    if (snapshot.hasError) {
                      debugPrint(
                        '[HomeScreen] activity stream failed ${snapshot.error}',
                      );
                      return const _HomeEmptyState(
                        message: 'Could not load activities. Try again.',
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final activities =
                        snapshot.data ?? const <ActivityFeedItem>[];
                    if (activities.isEmpty) {
                      return const _HomeEmptyState(
                        message: 'No activities yet',
                      );
                    }
                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(0, 6, 0, bottomClearance),
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        return _HomeActivityCard(
                          activity: activities[index],
                          currentUserId: currentUserId,
                          commentService: comments,
                          commentLikeService: widget.commentLikeService,
                          kudosService: widget.kudosService,
                          mutationService: widget.mutationService,
                          followService: widget.followService,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Stream<List<ActivityFeedItem>> _homeActivitiesStream(String? currentUserId) {
    final activityFeedService = widget.activityFeedService;
    final followService = widget.followService;
    if (currentUserId == null ||
        activityFeedService == null ||
        followService == null) {
      if (_realActivitiesStream != null ||
          _realActivitiesStreamUserId != null ||
          _realActivitiesStreamActivityService != null ||
          _realActivitiesStreamFollowService != null) {
        debugPrint(
          '[HomeScreen] activity stream cleared currentUserId=$currentUserId '
          'hasActivityFeedService=${activityFeedService != null} '
          'hasFollowService=${followService != null}',
        );
      }
      _realActivitiesStream = Stream<List<ActivityFeedItem>>.value(
        const <ActivityFeedItem>[],
      );
      _realActivitiesStreamUserId = null;
      _realActivitiesStreamActivityService = null;
      _realActivitiesStreamFollowService = null;
      return _realActivitiesStream!;
    }

    final hasCachedStream =
        _realActivitiesStream != null &&
        _realActivitiesStreamUserId == currentUserId &&
        identical(_realActivitiesStreamActivityService, activityFeedService) &&
        identical(_realActivitiesStreamFollowService, followService);
    if (hasCachedStream) return _realActivitiesStream!;

    debugPrint(
      '[HomeScreen] activity stream created currentUserId=$currentUserId',
    );
    _realActivitiesStream = activityFeedService.watchHomeActivitiesForUser(
      userId: currentUserId,
      followedUserIds: followService.watchFollowingIds(currentUserId),
    );
    _realActivitiesStreamUserId = currentUserId;
    _realActivitiesStreamActivityService = activityFeedService;
    _realActivitiesStreamFollowService = followService;
    return _realActivitiesStream!;
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_2_outlined,
              size: 40,
              color: AppSurfaces.textSubtle(context),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _activityTitles(List<ActivityFeedItem>? activities) {
  if (activities == null || activities.isEmpty) return '';
  return activities.map((activity) => activity.title).join('|');
}

class _HomeActivityCard extends StatelessWidget {
  const _HomeActivityCard({
    required this.activity,
    required this.currentUserId,
    required this.commentService,
    required this.commentLikeService,
    required this.kudosService,
    required this.mutationService,
    required this.followService,
  });

  final ActivityFeedItem activity;
  final String? currentUserId;
  final CommentService? commentService;
  final CommentLikeService? commentLikeService;
  final KudosService? kudosService;
  final ActivityMutationService? mutationService;
  final FollowService? followService;

  bool get _isOwner =>
      currentUserId != null && currentUserId == activity.ownerId;

  @override
  Widget build(BuildContext context) {
    return ActivityFeedCard.fromItem(
      activity,
      commentService: commentService,
      kudosService: kudosService,
      currentUserId: currentUserId,
      showShare: true,
      edgeToEdge: true,
      onShareTap: () {
        JourneyShareSheet.shareFromActivity(
          context,
          activity,
          currentUserId: currentUserId,
        );
      },
      onOverflowTap: () {
        if (_isOwner) {
          _showOwnerOptions(context);
        } else {
          _showNonOwnerOptions(context);
        }
      },
      onCommentTap: () {
        debugPrint(
          '[HomeScreen] open comments activityId=${activity.id} '
          'ownerId=${activity.ownerId}',
        );
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CommentsScreen(
              activityId: activity.id,
              activityOwnerId: activity.ownerId,
              commentService: commentService,
              commentLikeService: commentLikeService,
            ),
          ),
        );
      },
    );
  }

  void _openDetail(BuildContext context) {
    debugPrint(
      '[HomeScreen] open detail activityId=${activity.id} '
      'ownerId=${activity.ownerId}',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivityDetailScreen(
          activity: activity,
          showEngagementActions: true,
          currentUserId: currentUserId,
          commentService: commentService,
          commentLikeService: commentLikeService,
          kudosService: kudosService,
          mutationService: mutationService,
        ),
      ),
    );
  }

  Future<void> _showOwnerOptions(BuildContext context) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit activity'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showEditActivityDialog(
                  context: context,
                  activity: activity,
                  mutationService: mutationService,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('View activity'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openDetail(context);
              },
            ),
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
                  mutationService: mutationService,
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

  Future<void> _showNonOwnerOptions(BuildContext context) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('View activity'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openDetail(context);
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
                  currentUserId: currentUserId,
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Unfollow ${activity.displayName}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _unfollowOwner(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unfollowOwner(BuildContext context) async {
    final service = followService;
    final uid = currentUserId;
    final ownerId = activity.ownerId;
    if (service == null || uid == null) return;
    try {
      final state = await service
          .watchFollowState(followerId: uid, followeeId: ownerId)
          .first;
      if (state.isTargetPrivate) {
        if (!context.mounted) return;
        final confirmed = await confirmPrivateUnfollow(
          context,
          username: activity.username,
        );
        if (!confirmed || !context.mounted) return;
      }
      await service.unfollow(followerId: uid, followeeId: ownerId);
      if (context.mounted) {
        AppToast.success(context, 'Unfollowed ${activity.displayName}.');
      }
    } catch (error) {
      debugPrint('[HomeScreen] unfollow failed ownerId=$ownerId error=$error');
      if (context.mounted) {
        AppToast.error(context, 'Could not unfollow right now.');
      }
    }
  }
}
