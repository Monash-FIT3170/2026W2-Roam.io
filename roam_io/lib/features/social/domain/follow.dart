/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   One-way social follow relationship. Private-account request acceptance can
 *   mark the follow source so notification writers avoid duplicate target
 *   notifications.
 */

/// One-way public relationship where [followerId] follows [followeeId].
class Follow {
  const Follow({
    required this.id,
    required this.followerId,
    required this.followeeId,
    required this.createdAt,
    this.source,
    this.acceptedRequestId,
    this.acceptedRequestCreatedAt,
  });

  final String id;
  final String followerId;
  final String followeeId;
  final DateTime createdAt;
  final String? source;
  final String? acceptedRequestId;
  final DateTime? acceptedRequestCreatedAt;

  factory Follow.fromMap(String id, Map<String, dynamic> map) {
    return Follow(
      id: id,
      followerId: (map['followerId'] ?? '') as String,
      followeeId: (map['followeeId'] ?? '') as String,
      createdAt:
          DateTime.tryParse((map['createdAt'] ?? '') as String) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      source: map['source'] as String?,
      acceptedRequestId: map['acceptedRequestId'] as String?,
      acceptedRequestCreatedAt: map['acceptedRequestCreatedAt'] is String
          ? DateTime.tryParse(map['acceptedRequestCreatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'followerId': followerId,
      'followeeId': followeeId,
      'createdAt': createdAt.toIso8601String(),
      if (source != null) 'source': source,
      if (acceptedRequestId != null) 'acceptedRequestId': acceptedRequestId,
      if (acceptedRequestCreatedAt != null)
        'acceptedRequestCreatedAt': acceptedRequestCreatedAt!.toIso8601String(),
    };
  }
}
