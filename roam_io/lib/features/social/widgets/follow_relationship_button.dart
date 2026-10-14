/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 29 August 2026 — Sanjevan Rajasegar
 * Description:
 *   Shared Follow / Requested / Following control driven by derived Firestore
 *   relationship state. Follow is sage; Following and Requested default to
 *   sand with per-surface overrides in light mode and use the elevated dark
 *   surface in dark mode (see SocialButtonStyles).
 *   Unfollowing a private account confirms via shared dialog. Public targets
 *   follow immediately; private targets create cancellable requests.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/app_toast.dart';
import '../data/follow_service.dart';
import '../domain/follow_relationship_state.dart';
import '../domain/public_profile.dart';
import 'private_follow_confirm.dart';
import 'social_button_styles.dart';

/// Label modes for the public Follow relationship button.
enum FollowRelationshipLabelMode {
  /// Shows "Follow" when not following.
  follow,

  /// Shows "Follow Back" when not following (Notifications inbox).
  followBack,
}

/// Firestore-backed Follow / Following (or Follow Back) action button.
class FollowRelationshipButton extends StatefulWidget {
  const FollowRelationshipButton({
    super.key,
    required this.followerId,
    required this.followeeId,
    required this.followService,
    this.labelMode = FollowRelationshipLabelMode.follow,
    this.compact = false,
    this.expandWidth = false,
    this.followeeProfile,
    this.activeBackgroundColor,
  });

  final String followerId;
  final String followeeId;
  final FollowService followService;
  final FollowRelationshipLabelMode labelMode;
  final bool compact;
  final bool expandWidth;
  final PublicProfile? followeeProfile;

  /// Light-mode background for Following / Requested states.
  ///
  /// Profile and search surfaces default to sand; dense list rows can override
  /// to cream. Dark mode always uses the elevated dark surface.
  final Color? activeBackgroundColor;

  @override
  State<FollowRelationshipButton> createState() =>
      _FollowRelationshipButtonState();
}

class _FollowRelationshipButtonState extends State<FollowRelationshipButton> {
  late Stream<FollowRelationshipState> _stateStream;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _stateStream = widget.followService.watchFollowState(
      followerId: widget.followerId,
      followeeId: widget.followeeId,
    );
  }

  @override
  void didUpdateWidget(covariant FollowRelationshipButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.followerId != widget.followerId ||
        oldWidget.followeeId != widget.followeeId ||
        oldWidget.followService != widget.followService) {
      _stateStream = widget.followService.watchFollowState(
        followerId: widget.followerId,
        followeeId: widget.followeeId,
      );
    }
  }

  Future<void> _toggle(FollowRelationshipState state) async {
    if (_busy) return;
    final shouldUnfollow = state.status == FollowRelationshipStatus.following;
    final shouldCancel = state.status == FollowRelationshipStatus.requested;
    if (shouldUnfollow && state.isTargetPrivate) {
      final confirmed = await confirmPrivateUnfollow(
        context,
        username: widget.followeeProfile?.username,
      );
      if (!confirmed) return;
    }

    setState(() => _busy = true);
    try {
      if (shouldUnfollow) {
        await widget.followService.unfollow(
          followerId: widget.followerId,
          followeeId: widget.followeeId,
        );
      } else if (shouldCancel) {
        await widget.followService.cancelFollowRequest(
          requesterId: widget.followerId,
          targetId: widget.followeeId,
        );
      } else {
        await widget.followService.followOrRequest(
          followerId: widget.followerId,
          followeeId: widget.followeeId,
        );
      }
    } catch (error) {
      final code = error is FirebaseException ? error.code : 'unknown';
      debugPrint(
        '[FollowRelationshipButton] followerId=${widget.followerId} '
        'followeeId=${widget.followeeId} '
        'op=${shouldUnfollow
            ? 'unfollow'
            : shouldCancel
            ? 'cancel-request'
            : 'follow'} '
        'code=$code error=$error',
      );
      if (mounted) {
        AppToast.error(
          context,
          shouldUnfollow
              ? 'Could not unfollow right now.'
              : shouldCancel
              ? 'Could not cancel request right now.'
              : 'Could not follow right now.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _idleLabel(FollowRelationshipStatus status) {
    if (status == FollowRelationshipStatus.following) return 'Following';
    if (status == FollowRelationshipStatus.requested) return 'Requested';
    return switch (widget.labelMode) {
      FollowRelationshipLabelMode.follow => 'Follow',
      FollowRelationshipLabelMode.followBack => 'Follow Back',
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FollowRelationshipState>(
      stream: _stateStream,
      builder: (context, snapshot) {
        final state =
            snapshot.data ??
            const FollowRelationshipState(
              status: FollowRelationshipStatus.notFollowing,
              isTargetPrivate: false,
            );
        final waiting =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        final onPressed = _busy || waiting ? null : () => _toggle(state);
        final label = Text(_idleLabel(state.status));

        // Follow = sage filled; Following / Requested = sand outlined.
        final Widget button =
            state.status == FollowRelationshipStatus.notFollowing
            ? FilledButton(
                onPressed: onPressed,
                style: SocialButtonStyles.primary(compact: widget.compact),
                child: label,
              )
            : OutlinedButton(
                onPressed: onPressed,
                style: SocialButtonStyles.secondary(
                  context,
                  compact: widget.compact,
                  backgroundColor: widget.activeBackgroundColor,
                ),
                child: label,
              );

        if (widget.expandWidth) {
          return SizedBox(width: double.infinity, child: button);
        }
        return button;
      },
    );
  }
}
