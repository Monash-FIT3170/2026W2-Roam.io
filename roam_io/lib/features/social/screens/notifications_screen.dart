/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Instagram-style social notifications list for public-profile Follow events.
 *   Opening marks unread notifications read. Rows support Follow Back /
 *   Following (immediate unfollow) and Remove follower without deleting
 *   history.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/follow_service.dart';
import '../data/friendship_service.dart';
import '../data/social_notification_service.dart';
import '../domain/public_profile.dart';
import '../domain/social_notification.dart';
import '../utils/relative_time.dart';
import '../widgets/follow_relationship_button.dart';

/// Dedicated Notifications screen opened from the You bell.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    SocialNotificationService? notificationService,
    FollowService? followService,
    FriendshipService? friendshipService,
  }) : _notificationService = notificationService,
       _followService = followService,
       _friendshipService = friendshipService;

  final SocialNotificationService? _notificationService;
  final FollowService? _followService;
  final FriendshipService? _friendshipService;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final SocialNotificationService _notificationService;
  late final FollowService _followService;
  late final FriendshipService _friendshipService;
  var _markedRead = false;

  @override
  void initState() {
    super.initState();
    _notificationService =
        widget._notificationService ?? SocialNotificationService();
    _followService = widget._followService ?? FollowService();
    _friendshipService = widget._friendshipService ?? FriendshipService();

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
                      friendshipService: _friendshipService,
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
    required this.friendshipService,
  });

  final SocialNotification notification;
  final String currentUserId;
  final FollowService followService;
  final FriendshipService friendshipService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PublicProfile?>(
      stream: friendshipService.watchPublicProfile(notification.actorId),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final name = profile?.displayName ?? profile?.username ?? 'Someone';
        final photoUrl = profile?.photoUrl;
        final relative = formatRelativeTimestamp(notification.createdAt);

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
              _ActorAvatar(photoUrl: photoUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppSurfaces.textPrimary(context),
                        ),
                      ),
                      TextSpan(
                        text: ' followed you · $relative',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
              const SizedBox(width: 8),
              FollowRelationshipButton(
                followerId: currentUserId,
                followeeId: notification.actorId,
                followService: followService,
                labelMode: FollowRelationshipLabelMode.followBack,
                compact: true,
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: AppSurfaces.textMuted(context),
                ),
                onSelected: (value) async {
                  if (value != 'remove') return;
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

class _ActorAvatar extends StatelessWidget {
  const _ActorAvatar({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppSurfaces.softCard(context),
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.primary, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.person_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            )
          : Icon(
              Icons.person_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
    );
  }
}
