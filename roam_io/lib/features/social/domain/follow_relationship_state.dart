/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Derived one-way social relationship state for a viewer and target profile.
 */

/// Resolved Follow button state for a viewer -> target pair.
enum FollowRelationshipStatus { notFollowing, requested, following }

/// Pair relationship plus target privacy used by shared Follow controls.
class FollowRelationshipState {
  const FollowRelationshipState({
    required this.status,
    required this.isTargetPrivate,
  });

  final FollowRelationshipStatus status;
  final bool isTargetPrivate;

  bool get isFollowing => status == FollowRelationshipStatus.following;
  bool get isRequested => status == FollowRelationshipStatus.requested;
}
