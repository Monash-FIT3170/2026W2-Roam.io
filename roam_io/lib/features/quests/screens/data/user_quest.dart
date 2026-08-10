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
}