/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Describes the current friendship/request state between two users.
 */

import 'friend_request.dart';

/// Relationship state shown in user search rows.
enum FriendRelationshipStatus { none, requestSent, incomingRequest, friends }

/// Current state between the signed-in user and another user.
class FriendRelationship {
  const FriendRelationship({required this.status, this.request});

  const FriendRelationship.none()
    : status = FriendRelationshipStatus.none,
      request = null;

  final FriendRelationshipStatus status;
  final FriendRequest? request;
}

/// Result of requesting friendship with another user.
enum SendFriendRequestResult {
  sent,
  alreadySent,
  incomingRequest,
  alreadyFriends,
  selfRequest,
}
