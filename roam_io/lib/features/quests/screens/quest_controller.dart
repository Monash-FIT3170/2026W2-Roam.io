/*
 * Description:
 *   Coordinates quest loading, filtering and user quest progress.
 *   Keeps quest UI state separate from Firestore persistence.
 */

import 'package:flutter/foundation.dart';
import 'package:roam_io/features/quests/screens/data/quest.dart';
import 'package:roam_io/features/quests/screens/data/user_quest.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';
import 'package:roam_io/features/quests/screens/quest_service.dart';


class QuestController extends ChangeNotifier {
  QuestController({
    QuestService? questService,
  }) : _questService = questService ?? QuestService();

  final QuestService _questService;

  List<Quest> _quests = <Quest>[];
  List<UserQuest> _userQuests = <UserQuest>[];

  bool isLoading = false;
  bool isStartingQuest = false;

  String? errorMessage;

  QuestCategory? selectedCategory;

  List<Quest> get quests {
    final category = selectedCategory;

    if (category == null) {
      return List.unmodifiable(_quests);
    }

    return List.unmodifiable(
      _quests.where((quest) => quest.category == category),
    );
  }

  List<UserQuest> get userQuests => List.unmodifiable(_userQuests);

  List<UserQuest> get activeQuests => List.unmodifiable(
        _userQuests.where(
          (quest) =>
              quest.status == QuestStatus.active ||
              quest.status == QuestStatus.submitted,
        ),
      );

  List<UserQuest> get completedQuests => List.unmodifiable(
        _userQuests.where(
          (quest) => quest.status == QuestStatus.completed,
        ),
      );

  Future<void> initialise({
    required String userId,
  }) async {
    await loadQuests(userId: userId);
  }

  Future<void> loadQuests({
    required String userId,
    String? regionId,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        regionId == null
            ? _questService.getAvailableQuests()
            : _questService.getQuestsForRegion(regionId),
        _questService.getUserQuests(userId),
      ]);

      _quests = results[0] as List<Quest>;
      _userQuests = results[1] as List<UserQuest>;
    } catch (error) {
      debugPrint('[QuestController] Failed loading quests: $error');
      errorMessage = 'Could not load quests.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startQuest({
    required String userId,
    required Quest quest,
  }) async {
    if (isQuestStarted(quest.id)) {
      return true;
    }

    isStartingQuest = true;
    errorMessage = null;
    notifyListeners();

    try {
      final userQuest = await _questService.startQuest(
        userId: userId,
        questId: quest.id,
      );

      _userQuests.removeWhere(
        (existing) => existing.questId == quest.id,
      );

      _userQuests.add(userQuest);

      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('[QuestController] Failed starting quest: $error');
      errorMessage = 'Could not start quest.';
      notifyListeners();
      return false;
    } finally {
      isStartingQuest = false;
      notifyListeners();
    }
  }

  void selectCategory(QuestCategory? category) {
    selectedCategory = category;
    notifyListeners();
  }

  UserQuest? progressForQuest(String questId) {
    for (final userQuest in _userQuests) {
      if (userQuest.questId == questId) {
        return userQuest;
      }
    }

    return null;
  }

  bool isQuestStarted(String questId) {
    return progressForQuest(questId) != null;
  }

  bool isQuestCompleted(String questId) {
    return progressForQuest(questId)?.status == QuestStatus.completed;
  }
}