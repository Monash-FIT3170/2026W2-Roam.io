/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 9 August 2026
 * Description:
 *   Reactive Following / Followers list for a selected profile. Membership
 *   comes from selectedUserId follow relationships; each row's Follow /
 *   Following button reflects the authenticated user's relationship with the
 *   listed person. Own Followers rows also show a capsule Remove action
 *   (private accounts confirm before removal). Row body opens
 *   OtherUserProfileScreen.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/follow_service.dart';
import '../data/friendship_service.dart';
import '../domain/public_profile.dart';
import '../widgets/follow_relationship_button.dart';
import '../widgets/private_follow_confirm.dart';
import '../widgets/social_avatar.dart';
import 'other_user_profile_screen.dart';

/// Whether the screen lists people the selected user follows or their followers.
enum FollowConnectionsMode { following, followers }

/// Dedicated Following or Followers list for [selectedUserId].
class FollowConnectionsScreen extends StatefulWidget {
  const FollowConnectionsScreen({
    super.key,
    required this.selectedUserId,
    required this.mode,
    FollowService? followService,
    FriendshipService? friendshipService,
  }) : _followService = followService,
       _friendshipService = friendshipService;

  final String selectedUserId;
  final FollowConnectionsMode mode;
  final FollowService? _followService;
  final FriendshipService? _friendshipService;

  @override
  State<FollowConnectionsScreen> createState() =>
      _FollowConnectionsScreenState();
}

class _FollowConnectionsScreenState extends State<FollowConnectionsScreen> {
  late final FollowService _followService;
  late final FriendshipService _friendshipService;

  @override
  void initState() {
    super.initState();
    _followService = widget._followService ?? FollowService();
    _friendshipService = widget._friendshipService ?? FriendshipService();
  }

  String get _title => switch (widget.mode) {
    FollowConnectionsMode.following => 'Following',
    FollowConnectionsMode.followers => 'Followers',
  };

  Stream<List<String>> get _idsStream => switch (widget.mode) {
    FollowConnectionsMode.following => _followService.watchFollowingIds(
      widget.selectedUserId,
    ),
    FollowConnectionsMode.followers => _followService.watchFollowerIds(
      widget.selectedUserId,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final authUid = context.watch<AuthProvider>().currentUser?.uid;

    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      appBar: AppBar(title: Text(_title)),
      body: StreamBuilder<List<String>>(
        stream: _idsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final ids = snapshot.data ?? const <String>[];
          if (ids.isEmpty) {
            return Center(
              child: Text(
                widget.mode == FollowConnectionsMode.following
                    ? 'Not following anyone yet'
                    : 'No followers yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppSurfaces.textMuted(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          final isOwnFollowers =
              widget.mode == FollowConnectionsMode.followers &&
              authUid != null &&
              authUid == widget.selectedUserId;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            itemCount: ids.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final listedUserId = ids[index];
              return _ConnectionRow(
                listedUserId: listedUserId,
                authUid: authUid,
                showRemoveFollower: isOwnFollowers,
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

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({
    required this.listedUserId,
    required this.authUid,
    required this.showRemoveFollower,
    required this.followService,
    required this.friendshipService,
  });

  final String listedUserId;
  final String? authUid;
  final bool showRemoveFollower;
  final FollowService followService;
  final FriendshipService friendshipService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PublicProfile?>(
      stream: friendshipService.watchPublicProfile(listedUserId),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final displayName = profile?.displayName ?? 'Traveller';
        final username = profile?.username ?? listedUserId;
        final photoUrl = profile?.photoUrl;
        final showAction = authUid != null && authUid != listedUserId;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppSurfaces.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppSurfaces.border(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OtherUserProfileScreen(
                          selectedUserId: listedUserId,
                          friendshipService: friendshipService,
                          followService: followService,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      SocialAvatar(
                        displayName: displayName,
                        photoUrl: photoUrl,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppSurfaces.textPrimary(context),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@$username',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppSurfaces.textMuted(context),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (showAction) ...[
                const SizedBox(width: 10),
                if (showRemoveFollower) ...[
                  _RemoveFollowerButton(
                    followerId: listedUserId,
                    followeeId: authUid!,
                    followService: followService,
                    username: username,
                    isPrivateAccount: profile?.isPrivateAccount ?? false,
                  ),
                  const SizedBox(width: 8),
                ],
                FollowRelationshipButton(
                  followerId: authUid!,
                  followeeId: listedUserId,
                  followService: followService,
                  followeeProfile: profile,
                  compact: true,
                  activeBackgroundColor: AppColors.cream,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RemoveFollowerButton extends StatefulWidget {
  const _RemoveFollowerButton({
    required this.followerId,
    required this.followeeId,
    required this.followService,
    required this.username,
    required this.isPrivateAccount,
  });

  final String followerId;
  final String followeeId;
  final FollowService followService;
  final String username;
  final bool isPrivateAccount;

  @override
  State<_RemoveFollowerButton> createState() => _RemoveFollowerButtonState();
}

class _RemoveFollowerButtonState extends State<_RemoveFollowerButton> {
  var _busy = false;

  Future<void> _remove() async {
    if (_busy) return;
    if (widget.isPrivateAccount) {
      final confirmed = await confirmRemovePrivateFollower(
        context,
        username: widget.username,
      );
      if (!confirmed) return;
    }
    setState(() => _busy = true);
    try {
      await widget.followService.removeFollower(
        followerId: widget.followerId,
        followeeId: widget.followeeId,
      );
    } catch (error) {
      debugPrint('[FollowConnectionsScreen] removeFollower failed: $error');
      if (mounted) {
        AppToast.error(context, 'Could not remove follower.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: _busy ? null : _remove,
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        foregroundColor: AppSurfaces.textPrimary(context),
        backgroundColor: AppColors.cream,
        side: BorderSide(color: AppSurfaces.border(context)),
      ),
      child: const Text('Remove'),
    );
  }
}
