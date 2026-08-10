/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Social notifications list for public follows, private follow requests, and
 *   request acceptance. Opening marks unread notifications read. Private
 *   request rows are the single incoming request management surface. Removing
 *   a private follower confirms first.
 */

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../activity_feed/data/activity_feed_service.dart';
import '../../activity_feed/data/comment_like_service.dart';
import '../../activity_feed/data/comment_service.dart';
import '../../activity_feed/data/kudos_service.dart';
import '../../activity_feed/models/activity_comment.dart';
import '../../activity_feed/models/activity_feed_item.dart';
import '../../activity_feed/screens/activity_detail_screen.dart';
import '../../activity_feed/screens/comments_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/follow_request_service.dart';
import '../data/follow_service.dart';
import '../data/friendship_service.dart';
import '../data/social_notification_service.dart';
import '../domain/follow_request.dart';
import '../domain/public_profile.dart';
import '../domain/social_notification.dart';
import '../utils/relative_time.dart';
import '../widgets/follow_relationship_button.dart';
import '../widgets/private_follow_confirm.dart';
import '../widgets/social_avatar.dart';
import 'other_user_profile_screen.dart';

/// Dedicated Notifications screen opened from the You bell.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    SocialNotificationService? notificationService,
    FollowService? followService,
    FollowRequestService? followRequestService,
    FriendshipService? friendshipService,
    ActivityFeedService? activityFeedService,
    CommentService? commentService,
    CommentLikeService? commentLikeService,
    KudosService? kudosService,
  }) : _notificationService = notificationService,
       _followService = followService,
       _followRequestService = followRequestService,
       _friendshipService = friendshipService,
       _activityFeedService = activityFeedService,
       _commentService = commentService,
       _commentLikeService = commentLikeService,
       _kudosService = kudosService;

  final SocialNotificationService? _notificationService;
  final FollowService? _followService;
  final FollowRequestService? _followRequestService;
  final FriendshipService? _friendshipService;
  final ActivityFeedService? _activityFeedService;
  final CommentService? _commentService;
  final CommentLikeService? _commentLikeService;
  final KudosService? _kudosService;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final SocialNotificationService _notificationService;
  late final FollowService _followService;
  late final FollowRequestService _followRequestService;
  late final FriendshipService _friendshipService;
  late final ActivityFeedService _activityFeedService;
  late final CommentService _commentService;
  late final CommentLikeService? _commentLikeService;
  late final KudosService? _kudosService;
  var _markedRead = false;

  @override
  void initState() {
    super.initState();
    _notificationService =
        widget._notificationService ?? SocialNotificationService();
    _followService = widget._followService ?? FollowService();
    _followRequestService =
        widget._followRequestService ??
        (Firebase.apps.isNotEmpty
            ? FollowRequestService()
            : _EmptyFollowRequestService());
    _friendshipService = widget._friendshipService ?? FriendshipService();
    final hasFirebase = Firebase.apps.isNotEmpty;
    _activityFeedService =
        widget._activityFeedService ??
        (hasFirebase ? ActivityFeedService() : _EmptyActivityFeedService());
    _commentService =
        widget._commentService ??
        (hasFirebase ? CommentService() : _EmptyCommentService());
    _commentLikeService =
        widget._commentLikeService ??
        (hasFirebase ? CommentLikeService() : null);
    _kudosService =
        widget._kudosService ?? (hasFirebase ? KudosService() : null);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markReadIfNeeded();
    });
  }

  Future<void> _markReadIfNeeded() async {
    if (_markedRead) return;
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    _markedRead = true;
    try {
      await _notificationService.markAllRead(uid);
    } catch (error) {
      debugPrint('[NotificationsScreen] markAllRead failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().currentUser?.uid;

    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      appBar: AppBar(title: const Text('Notifications')),
      body: uid == null
          ? const Center(child: Text('Sign in to view notifications.'))
          : StreamBuilder<List<SocialNotification>>(
              stream: _notificationService.watchRecent(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(
                    child: Text(
                      'Loading…',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppSurfaces.textMuted(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }
                final items = snapshot.data ?? const <SocialNotification>[];
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No notifications yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppSurfaces.textMuted(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _FollowNotificationRow(
                      notification: item,
                      currentUserId: uid,
                      followService: _followService,
                      followRequestService: _followRequestService,
                      friendshipService: _friendshipService,
                      activityFeedService: _activityFeedService,
                      commentService: _commentService,
                      commentLikeService: _commentLikeService,
                      kudosService: _kudosService,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _FollowNotificationRow extends StatelessWidget {
  const _FollowNotificationRow({
    required this.notification,
    required this.currentUserId,
    required this.followService,
    required this.followRequestService,
    required this.friendshipService,
    required this.activityFeedService,
    required this.commentService,
    required this.commentLikeService,
    required this.kudosService,
  });

  final SocialNotification notification;
  final String currentUserId;
  final FollowService followService;
  final FollowRequestService followRequestService;
  final FriendshipService friendshipService;
  final ActivityFeedService activityFeedService;
  final CommentService commentService;
  final CommentLikeService? commentLikeService;
  final KudosService? kudosService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PublicProfile?>(
      stream: friendshipService.watchPublicProfile(notification.actorId),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final name = profile?.displayName ?? profile?.username ?? 'Someone';
        final photoUrl = profile?.photoUrl;
        final relative = formatRelativeTimestamp(notification.createdAt);
        final message = switch (notification.type) {
          SocialNotificationType.follow => ' followed you · $relative',
          SocialNotificationType.followRequest =>
            ' requested to follow you · $relative',
          SocialNotificationType.followRequestAccepted =>
            ' accepted your follow request · $relative',
          SocialNotificationType.activityKudos =>
            ' gave Kudos to your activity · $relative',
          SocialNotificationType.activityComment =>
            notification.isActivityReplyOnOwnedActivity
                ? ' replied to a comment on your activity · $relative'
                : ' commented on your activity · $relative',
          SocialNotificationType.commentReply =>
            ' replied to your comment · $relative',
          SocialNotificationType.commentLike =>
            ' liked your comment · $relative',
        };

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppSurfaces.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppSurfaces.border(context)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (notification.isActivityInteraction &&
                        notification.activityId != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _ActivityNotificationDestination(
                            notification: notification,
                            activityFeedService: activityFeedService,
                            commentService: commentService,
                            commentLikeService: commentLikeService,
                            kudosService: kudosService,
                            currentUserId: currentUserId,
                          ),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => OtherUserProfileScreen(
                            selectedUserId: notification.actorId,
                            friendshipService: friendshipService,
                            followService: followService,
                          ),
                        ),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      SocialAvatar(
                        displayName: name,
                        photoUrl: photoUrl,
                        radius: 20,
                        borderWidth: 1.5,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: name,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppSurfaces.textPrimary(context),
                                    ),
                              ),
                              TextSpan(
                                text: message,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppSurfaces.textMuted(context),
                                    ),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (notification.isFollow)
                FollowRelationshipButton(
                  followerId: currentUserId,
                  followeeId: notification.actorId,
                  followService: followService,
                  followeeProfile: profile,
                  labelMode: FollowRelationshipLabelMode.followBack,
                  compact: true,
                ),
              if (notification.isFollowRequest)
                _FollowRequestActions(
                  requesterId: notification.actorId,
                  currentUserId: currentUserId,
                  followRequestService: followRequestService,
                ),
              if (notification.isFollow)
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: AppSurfaces.textMuted(context),
                  ),
                  onSelected: (value) async {
                    if (value != 'remove') return;
                    if (profile?.isPrivateAccount ?? false) {
                      final confirmed = await confirmRemovePrivateFollower(
                        context,
                        username: profile?.username,
                      );
                      if (!confirmed) return;
                    }
                    try {
                      await followService.removeFollower(
                        followerId: notification.actorId,
                        followeeId: currentUserId,
                      );
                    } catch (error) {
                      debugPrint(
                        '[NotificationsScreen] removeFollower failed: $error',
                      );
                      if (context.mounted) {
                        AppToast.error(context, 'Could not remove follower.');
                      }
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'remove',
                      child: Text('Remove follower'),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityNotificationDestination extends StatelessWidget {
  const _ActivityNotificationDestination({
    required this.notification,
    required this.activityFeedService,
    required this.commentService,
    required this.commentLikeService,
    required this.kudosService,
    required this.currentUserId,
  });

  final SocialNotification notification;
  final ActivityFeedService activityFeedService;
  final CommentService commentService;
  final CommentLikeService? commentLikeService;
  final KudosService? kudosService;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final activityId = notification.activityId!;
    return StreamBuilder(
      stream: activityFeedService.watchActivity(activityId),
      builder: (context, snapshot) {
        final activity = snapshot.data;
        if (activity == null &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (notification.type == SocialNotificationType.activityKudos &&
            activity != null) {
          return ActivityDetailScreen(
            activity: activity,
            showEngagementActions: true,
            currentUserId: currentUserId,
            commentService: commentService,
            commentLikeService: commentLikeService,
            kudosService: kudosService,
          );
        }
        return CommentsScreen(
          activityId: activityId,
          activityOwnerId: activity?.ownerId ?? notification.recipientId,
          commentService: commentService,
          commentLikeService: commentLikeService,
        );
      },
    );
  }
}

class _FollowRequestActions extends StatefulWidget {
  const _FollowRequestActions({
    required this.requesterId,
    required this.currentUserId,
    required this.followRequestService,
  });

  final String requesterId;
  final String currentUserId;
  final FollowRequestService followRequestService;

  @override
  State<_FollowRequestActions> createState() => _FollowRequestActionsState();
}

class _FollowRequestActionsState extends State<_FollowRequestActions> {
  var _busy = false;

  String get _requestId => FollowRequestService.requestIdFor(
    widget.requesterId,
    widget.currentUserId,
  );

  Future<void> _accept(FollowRequest request) async {
    await _run(() {
      return widget.followRequestService.acceptFollowRequest(
        requestId: request.id,
        currentUserId: widget.currentUserId,
      );
    });
  }

  Future<void> _decline(FollowRequest request) async {
    await _run(() {
      return widget.followRequestService.declineFollowRequest(
        requestId: request.id,
        currentUserId: widget.currentUserId,
      );
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      debugPrint('[NotificationsScreen] follow request action failed: $error');
      if (mounted) {
        AppToast.error(context, 'Could not update follow request.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FollowRequest?>(
      stream: widget.followRequestService.watchPendingBetween(
        requesterId: widget.requesterId,
        targetId: widget.currentUserId,
      ),
      builder: (context, snapshot) {
        final request = snapshot.data;
        final isActionable =
            request != null &&
            request.id == _requestId &&
            request.requesterId == widget.requesterId &&
            request.targetId == widget.currentUserId &&
            request.isPending;
        if (!isActionable) return const SizedBox.shrink();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: _busy ? null : () => _decline(request),
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                foregroundColor: AppSurfaces.textPrimary(context),
                backgroundColor: AppColors.cream,
                side: BorderSide(color: AppSurfaces.border(context)),
              ),
              child: const Text('Decline'),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: _busy ? null : () => _accept(request),
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyFollowRequestService implements FollowRequestService {
  @override
  Stream<FollowRequest?> watchPendingBetween({
    required String requesterId,
    required String targetId,
  }) {
    return Stream<FollowRequest?>.value(null);
  }

  @override
  Future<void> acceptFollowRequest({
    required String requestId,
    required String currentUserId,
  }) {
    return Future<void>.value();
  }

  @override
  Future<void> declineFollowRequest({
    required String requestId,
    required String currentUserId,
  }) {
    return Future<void>.value();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyActivityFeedService implements ActivityFeedService {
  @override
  Stream<ActivityFeedItem?> watchActivity(String activityId) {
    return Stream<ActivityFeedItem?>.value(null);
  }

  @override
  Stream<List<ActivityFeedItem>> watchPublicActivitiesForProfile(
    String profileId,
  ) {
    return Stream<List<ActivityFeedItem>>.value(const <ActivityFeedItem>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyCommentService implements CommentService {
  @override
  Stream<List<ActivityComment>> watchComments(String activityId) {
    return Stream<List<ActivityComment>>.value(const <ActivityComment>[]);
  }

  @override
  Stream<int> watchCommentCount(String activityId) {
    return Stream<int>.value(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
