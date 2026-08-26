import 'package:roam_io/features/quests/screens/data/quest.dart';
import 'package:roam_io/features/quests/screens/data/user_quest.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';

abstract interface class QuestRepository {
  Future<List<Quest>> getAvailableQuests();

  Future<List<Quest>> getQuestsForRegion(String regionId);

  Future<Quest?> getQuestById(String questId);

  Future<List<UserQuest>> getUserQuests(String userId);

  Future<UserQuest> startQuest({
    required String userId,
    required String questId,
  });

  Future<void> updateQuestStatus({
    required String userId,
    required String questId,
    required QuestStatus status,
  });
}
