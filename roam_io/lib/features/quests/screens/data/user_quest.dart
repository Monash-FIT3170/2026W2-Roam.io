/*
 * Description:
 *   Represents a user's progress through a quest.
 *   Tracks when the quest was started, submitted, completed or rejected.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';

class UserQuest {
  const UserQuest({
    required this.id,
    required this.userId,
    required this.questId,
    required this.status,
    required this.startedAt,
    this.submittedAt,
    this.completedAt,
    this.rejectionReason,
  });

  final String id;
  final String userId;
  final String questId;
  final QuestStatus status;

  final DateTime startedAt;
  final DateTime? submittedAt;
  final DateTime? completedAt;

  final String? rejectionReason;

  factory UserQuest.fromFirestore({
    required String userId,
    required DocumentSnapshot<Map<String, dynamic>> document,
  }) {
    final data = document.data();

    if (data == null) {
      throw StateError('User quest ${document.id} contains no data');
    }

    return UserQuest(
      id: document.id,
      userId: userId,
      questId: data['questId'] as String? ?? document.id,
      status: _parseStatus(data['status']),
      startedAt:
          _parseDate(data['startedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      submittedAt: _parseDate(data['submittedAt']),
      completedAt: _parseDate(data['completedAt']),
      rejectionReason: data['rejectionReason'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questId': questId,
      'status': status.name,
      'startedAt': Timestamp.fromDate(startedAt),
      'submittedAt': submittedAt == null
          ? null
          : Timestamp.fromDate(submittedAt!),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'rejectionReason': rejectionReason,
    };
  }

  UserQuest copyWith({
    QuestStatus? status,
    DateTime? submittedAt,
    DateTime? completedAt,
    String? rejectionReason,
  }) {
    return UserQuest(
      id: id,
      userId: userId,
      questId: questId,
      status: status ?? this.status,
      startedAt: startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      completedAt: completedAt ?? this.completedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  static QuestStatus _parseStatus(dynamic value) {
    return QuestStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => QuestStatus.active,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
