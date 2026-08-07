/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   One-way public social follow relationship, independent from friendship.
 */

/// One-way public relationship where [followerId] follows [followeeId].
class Follow {
  const Follow({
    required this.id,
    required this.followerId,
    required this.followeeId,
    required this.createdAt,
  });

  final String id;
  final String followerId;
  final String followeeId;
  final DateTime createdAt;

  factory Follow.fromMap(String id, Map<String, dynamic> map) {
    return Follow(
      id: id,
      followerId: (map['followerId'] ?? '') as String,
      followeeId: (map['followeeId'] ?? '') as String,
      createdAt:
          DateTime.tryParse((map['createdAt'] ?? '') as String) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'followerId': followerId,
      'followeeId': followeeId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
