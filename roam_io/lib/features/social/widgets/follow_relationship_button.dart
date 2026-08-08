/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Shared public-profile Follow / Following control driven by Firestore
 *   follows/{followerId_followeeId}. Both states render as stadium buttons in
 *   the same slot (filled Follow, outlined Following). Tap Following to
 *   unfollow immediately and silently. Follow Back mode is used on the
 *   Notifications inbox. UI derives from watchIsFollowing, not local-only
 *   optimistic state.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_surfaces.dart';
import '../data/follow_service.dart';

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
  });

  final String followerId;
  final String followeeId;
  final FollowService followService;
  final FollowRelationshipLabelMode labelMode;
  final bool compact;
  final bool expandWidth;

  @override
  State<FollowRelationshipButton> createState() =>
      _FollowRelationshipButtonState();
}

class _FollowRelationshipButtonState extends State<FollowRelationshipButton> {
  late Stream<bool> _isFollowingStream;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _isFollowingStream = widget.followService.watchIsFollowing(
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
      _isFollowingStream = widget.followService.watchIsFollowing(
        followerId: widget.followerId,
        followeeId: widget.followeeId,
      );
    }
  }

  Future<void> _toggle(bool isFollowing) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (isFollowing) {
        await widget.followService.unfollow(
          followerId: widget.followerId,
          followeeId: widget.followeeId,
        );
      } else {
        await widget.followService.follow(
          followerId: widget.followerId,
          followeeId: widget.followeeId,
        );
      }
    } catch (error) {
      final code = error is FirebaseException ? error.code : 'unknown';
      debugPrint(
        '[FollowRelationshipButton] followerId=${widget.followerId} '
        'followeeId=${widget.followeeId} '
        'op=${isFollowing ? 'unfollow' : 'follow'} '
        'code=$code error=$error',
      );
      if (mounted) {
        AppToast.error(
          context,
          isFollowing
              ? 'Could not unfollow right now.'
              : 'Could not follow right now.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _idleLabel(bool isFollowing) {
    if (isFollowing) return 'Following';
    return switch (widget.labelMode) {
      FollowRelationshipLabelMode.follow => 'Follow',
      FollowRelationshipLabelMode.followBack => 'Follow Back',
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _isFollowingStream,
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;
        final waiting =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        final onPressed =
            _busy || waiting ? null : () => _toggle(isFollowing);
        final label = Text(_idleLabel(isFollowing));

        // Outlined Following stays a real button (cream softCard fill looked
        // like plain centred text on the cream profile background).
        final Widget button = isFollowing
            ? OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  visualDensity: widget.compact
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                  padding: widget.compact
                      ? const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        )
                      : null,
                  foregroundColor: AppSurfaces.textPrimary(context),
                  backgroundColor: AppSurfaces.card(context),
                  side: BorderSide(color: AppSurfaces.border(context)),
                ),
                child: label,
              )
            : FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  visualDensity: widget.compact
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                  padding: widget.compact
                      ? const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        )
                      : null,
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
