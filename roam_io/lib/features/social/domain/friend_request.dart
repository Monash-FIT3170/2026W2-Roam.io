/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Defines friend-request domain state persisted in Firestore.
 */

/// Lifecycle states for a friend request.
enum FriendRequestStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined');

  const FriendRequestStatus(this.wireValue);

  final String wireValue;

  static FriendRequestStatus fromWireValue(String value) {
    return FriendRequestStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => FriendRequestStatus.pending,
    );
  }
}

/// Pending/handled request between two users.
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.pairKey,
    required this.senderId,
    required this.recipientId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String pairKey;
  final String senderId;
  final String recipientId;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FriendRequest.fromMap(String id, Map<String, dynamic> map) {
    return FriendRequest(
      id: id,
      pairKey: (map['pairKey'] ?? '') as String,
      senderId: (map['senderId'] ?? '') as String,
      recipientId: (map['recipientId'] ?? '') as String,
      status: FriendRequestStatus.fromWireValue(
        (map['status'] ?? '') as String,
      ),
      createdAt:
          DateTime.tryParse((map['createdAt'] ?? '') as String) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((map['updatedAt'] ?? '') as String) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'pairKey': pairKey,
      'senderId': senderId,
      'recipientId': recipientId,
      'status': status.wireValue,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
