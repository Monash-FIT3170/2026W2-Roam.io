/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
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
import '../../../shared/widgets/app_page_transition.dart';
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
import '../widgets/social_button_styles.dart';
import '../widgets/social_layout.dart';
import '../widgets/social_message.dart';
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
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppSurfaces.pageBackground(context),
      ),
      body: uid == null
          ? const SocialMessage('Sign in to view notifications.')
          : StreamBuilder<List<SocialNotification>>(
              stream: _notificationService.watchRecent(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const _NotificationsSkeleton();
                }
                final items = snapshot.data ?? const <SocialNotification>[];
                if (items.isEmpty) {
                  return const SocialMessage('No notifications yet');
                }

                final groups = _groupNotifications(items);
                return SocialContentWidth(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      SocialLayout.gutter,
                      4,
                      SocialLayout.gutter,
                      24,
                    ),
                    children: [
                      for (final group in groups) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 18, bottom: 6),
                          child: Text(
                            group.label,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppSurfaces.textPrimary(context),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        for (
                          var index = 0;
                          index < group.items.length;
                          index++
                        ) ...[
                          _FollowNotificationRow(
                            notification: group.items[index],
                            currentUserId: uid,
                            followService: _followService,
                            followRequestService: _followRequestService,
                            friendshipService: _friendshipService,
                            activityFeedService: _activityFeedService,
                            commentService: _commentService,
                            commentLikeService: _commentLikeService,
                            kudosService: _kudosService,
                          ),
                          if (index != group.items.length - 1)
                            Divider(
                              height: 1,
                              // Aligns with the message text: dot + gap + avatar + gap.
                              indent: 64,
                              color: AppSurfaces.border(context),
                            ),
                        ],
                      ],
                    ],
                  ),
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
          SocialNotificationType.follow => ' followed you',
          SocialNotificationType.followRequest => ' requested to follow you',
          SocialNotificationType.followRequestAccepted =>
            ' accepted your follow request',
          SocialNotificationType.activityKudos =>
            ' gave Glaze to your activity',
          SocialNotificationType.activityComment =>
            notification.isActivityReplyOnOwnedActivity
                ? ' replied to a comment on your activity'
                : ' commented on your activity',
          SocialNotificationType.commentReply => ' replied to your comment',
          SocialNotificationType.commentLike => ' liked your comment',
        };

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: SocialLayout.rowGap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 8,
                child: notification.isRead
                    ? const SizedBox.shrink()
                    : Semantics(
                        label: 'Unread',
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppSurfaces.isDark(context)
                                ? AppColors.lightSage
                                : AppColors.sage,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    if (notification.isActivityInteraction &&
                        notification.activityId != null) {
                      Navigator.of(context).push(
                        appHorizontalPageRoute<void>(
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
                        appHorizontalPageRoute<void>(
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppSurfaces.textPrimary(
                                            context,
                                          ),
                                        ),
                                  ),
                                  TextSpan(
                                    text: message,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w400,
                                          color: AppSurfaces.textPrimary(
                                            context,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              relative,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppSurfaces.textMuted(context),
                                    fontWeight: FontWeight.w400,
                                  ),
                            ),
                          ],
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
                  activeBackgroundColor: AppColors.cream,
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

class _NotificationGroup {
  const _NotificationGroup(this.label, this.items);

  final String label;
  final List<SocialNotification> items;
}

List<_NotificationGroup> _groupNotifications(
  List<SocialNotification> notifications,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final grouped = <String, List<SocialNotification>>{};
  for (final notification in notifications) {
    final value = notification.createdAt.toLocal();
    final day = DateTime(value.year, value.month, value.day);
    final label = day == today
        ? 'Today'
        : day == yesterday
        ? 'Yesterday'
        : !day.isBefore(weekStart)
        ? 'Earlier this week'
        : 'Earlier';
    grouped.putIfAbsent(label, () => <SocialNotification>[]).add(notification);
  }
  return ['Today', 'Yesterday', 'Earlier this week', 'Earlier']
      .where((label) => grouped[label]?.isNotEmpty ?? false)
      .map((label) => _NotificationGroup(label, grouped[label]!))
      .toList(growable: false);
}

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    final fill = AppSurfaces.softCard(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        SocialLayout.gutter,
        24,
        SocialLayout.gutter,
        24,
      ),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, index) => Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            child: const SizedBox(width: 40, height: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: index.isEven ? 0.78 : 0.64,
                  child: Container(height: 11, color: fill),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: 0.28,
                  child: Container(height: 8, color: fill),
                ),
              ],
            ),
          ),
        ],
      ),
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
              style: SocialButtonStyles.secondary(
                context,
                compact: true,
                backgroundColor: AppColors.cream,
              ),
              child: const Text('Decline'),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: _busy ? null : () => _accept(request),
              style: SocialButtonStyles.primary(compact: true),
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
