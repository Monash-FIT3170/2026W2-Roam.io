/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   One-way private-account follow request from requesterId to targetId.
 */

/// Lifecycle state for a private-account follow request.
enum FollowRequestStatus {
  pending;

  String get wireValue => name;

  static FollowRequestStatus fromWireValue(String? value) {
    return switch (value) {
      'pending' => FollowRequestStatus.pending,
      _ => FollowRequestStatus.pending,
    };
  }
}

/// Persistent request stored at follow_requests/{requesterId_targetId}.
class FollowRequest {
  const FollowRequest({
    required this.id,
    required this.requesterId,
    required this.targetId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String requesterId;
  final String targetId;
  final FollowRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPending => status == FollowRequestStatus.pending;

  factory FollowRequest.fromMap(String id, Map<String, dynamic> map) {
    return FollowRequest(
      id: id,
      requesterId: (map['requesterId'] ?? '') as String,
      targetId: (map['targetId'] ?? '') as String,
      status: FollowRequestStatus.fromWireValue(map['status'] as String?),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'requesterId': requesterId,
      'targetId': targetId,
      'status': status.wireValue,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static DateTime _parseDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
