/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Home destination showing persisted own/followed activities and a temporary
 *   real Firestore test-activity creator.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_surfaces.dart';
import '../../activity_feed/data/activity_creation_service.dart';
import '../../activity_feed/data/activity_feed_service.dart';
import '../../activity_feed/data/comment_like_service.dart';
import '../../activity_feed/data/comment_service.dart';
import '../../activity_feed/data/kudos_service.dart';
import '../../activity_feed/models/activity_feed_item.dart';
import '../../activity_feed/screens/activity_detail_screen.dart';
import '../../activity_feed/screens/comments_screen.dart';
import '../../activity_feed/widgets/activity_feed_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/domain/profile_model.dart';
import '../../social/data/follow_service.dart';

/// Top-level Home tab for the friend activity feed foundation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.commentService,
    this.commentLikeService,
    this.kudosService,
    this.activityFeedService,
    this.activityCreationService,
    this.followService,
  });

  /// Injected for tests; production receives a shared instance from [MainShellScreen].
  final CommentService? commentService;
  final CommentLikeService? commentLikeService;
  final KudosService? kudosService;
  final ActivityFeedService? activityFeedService;
  final ActivityCreationService? activityCreationService;
  final FollowService? followService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ActivityCreationService _activityCreationService;
  Stream<List<ActivityFeedItem>>? _realActivitiesStream;
  String? _realActivitiesStreamUserId;
  ActivityFeedService? _realActivitiesStreamActivityService;
  FollowService? _realActivitiesStreamFollowService;
  var _isCreatingTestActivity = false;

  @override
  void initState() {
    super.initState();
    _activityCreationService =
        widget.activityCreationService ?? ActivityCreationService();
  }

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
    final profile = _currentProfile(context);
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
              trailing: IconButton.filledTonal(
                tooltip: 'Test Activity',
                visualDensity: VisualDensity.compact,
                onPressed: currentUserId == null || _isCreatingTestActivity
                    ? null
                    : () => _createTestActivity(currentUserId!, profile),
                icon: _isCreatingTestActivity
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
              ),
            ),
            Expanded(
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
                    return const _HomeEmptyState(message: 'No activities yet');
                  }
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, bottomClearance),
                    itemCount: activities.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      return _HomeActivityCard(
                        activity: activities[index],
                        currentUserId: currentUserId,
                        commentService: comments,
                        commentLikeService: widget.commentLikeService,
                        kudosService: widget.kudosService,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  ProfileModel? _currentProfile(BuildContext context) {
    try {
      return context.watch<AuthProvider>().currentProfile;
    } on ProviderNotFoundException {
      return null;
    }
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

  Future<void> _createTestActivity(
    String currentUserId,
    ProfileModel? profile,
  ) async {
    setState(() {
      _isCreatingTestActivity = true;
    });
    try {
      await _activityCreationService.createTestActivityForUser(
        userId: currentUserId,
        fallbackProfile: profile,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[HomeScreen] create test activity failed $error\n$stackTrace',
      );
      if (mounted) {
        AppToast.error(context, 'Could not create test activity.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingTestActivity = false;
        });
      }
    }
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
        child: Text(
          message,
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
  });

  final ActivityFeedItem activity;
  final String? currentUserId;
  final CommentService? commentService;
  final CommentLikeService? commentLikeService;
  final KudosService? kudosService;

  @override
  Widget build(BuildContext context) {
    return ActivityFeedCard.fromItem(
      activity,
      commentService: commentService,
      kudosService: kudosService,
      currentUserId: currentUserId,
      showShare: false,
      onOverflowTap: () {
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
            ),
          ),
        );
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
}
