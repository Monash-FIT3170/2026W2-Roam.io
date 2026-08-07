/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Defines the accepted friendship relationship used by social features.
 */

/// Accepted friendship between two users.
class Friendship {
  const Friendship({
    required this.pairKey,
    required this.memberIds,
    required this.createdAt,
    required this.acceptedRequestId,
  });

  final String pairKey;
  final List<String> memberIds;
  final DateTime createdAt;
  final String acceptedRequestId;

  factory Friendship.fromMap(String pairKey, Map<String, dynamic> map) {
    return Friendship(
      pairKey: pairKey,
      memberIds: List<String>.from(
        map['memberIds'] as List<dynamic>? ?? const [],
      ),
      createdAt:
          DateTime.tryParse((map['createdAt'] ?? '') as String) ??
          DateTime.now(),
      acceptedRequestId: (map['acceptedRequestId'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'pairKey': pairKey,
      'memberIds': memberIds,
      'createdAt': createdAt.toIso8601String(),
      'acceptedRequestId': acceptedRequestId,
    };
  }
}
