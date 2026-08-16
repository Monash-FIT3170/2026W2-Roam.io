/*
 * Description:
 *   Coordinates quest loading, filtering, starting, verification and completion.
 *   Keeps quest UI state separate from Firestore and verification logic.
 */

import 'package:flutter/foundation.dart';
import 'package:roam_io/features/quests/screens/data/quest.dart';
import 'package:roam_io/features/quests/screens/data/user_quest.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';
import 'package:roam_io/features/quests/screens/quest_service.dart';
import 'package:roam_io/features/quests/screens/quest_verification_service.dart';


class QuestController extends ChangeNotifier {
  QuestController({
    QuestService? questService,
    QuestVerificationService? verificationService,
  }) : _questService = questService ?? QuestService(),
       _verificationService =
           verificationService ?? QuestVerificationService();

  final QuestService _questService;
  final QuestVerificationService _verificationService;

  List<Quest> _quests = <Quest>[];
  List<UserQuest> _userQuests = <UserQuest>[];

  bool isLoading = false;
  bool isStartingQuest = false;
  bool isCompletingQuest = false;

  String? errorMessage;
  String? completionMessage;

  QuestCategory? selectedCategory;

  List<Quest> get quests {
    final category = selectedCategory;

    if (category == null) {
      return List<Quest>.unmodifiable(_quests);
    }

    return List<Quest>.unmodifiable(
      _quests.where((quest) => quest.category == category),
    );
  }

  List<UserQuest> get userQuests {
    return List<UserQuest>.unmodifiable(_userQuests);
  }

  List<UserQuest> get activeQuests {
    return List<UserQuest>.unmodifiable(
      _userQuests.where(
        (quest) =>
            quest.status == QuestStatus.active ||
            quest.status == QuestStatus.submitted,
      ),
    );
  }

  List<UserQuest> get completedQuests {
    return List<UserQuest>.unmodifiable(
      _userQuests.where(
        (quest) => quest.status == QuestStatus.completed,
      ),
    );
  }

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
      final availableQuests = regionId == null
          ? await _questService.getAvailableQuests()
          : await _questService.getQuestsForRegion(regionId);

      final userQuestProgress = await _questService.getUserQuests(userId);

      _quests = availableQuests;
      _userQuests = userQuestProgress;
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
    final existingProgress = progressForQuest(quest.id);

    if (existingProgress != null) {
      return true;
    }

    isStartingQuest = true;
    errorMessage = null;
    completionMessage = null;
    notifyListeners();

    try {
      final userQuest = await _questService.startQuest(
        userId: userId,
        questId: quest.id,
      );

      _replaceUserQuest(userQuest);

      return true;
    } catch (error) {
      debugPrint('[QuestController] Failed starting quest: $error');
      errorMessage = 'Could not start quest.';
      return false;
    } finally {
      isStartingQuest = false;
      notifyListeners();
    }
  }

  Future<bool> completeQuest({
    required String userId,
    required Quest quest,
    String? photoUrl,
  }) async {
    final progress = progressForQuest(quest.id);

    if (progress == null) {
      errorMessage = 'Start this quest before completing it.';
      notifyListeners();
      return false;
    }

    if (progress.status == QuestStatus.completed) {
      completionMessage = 'Quest already completed.';
      notifyListeners();
      return true;
    }

    isCompletingQuest = true;
    errorMessage = null;
    completionMessage = null;
    notifyListeners();

    try {
      final submission =
          await _verificationService.createSubmissionFromCurrentLocation(
            quest: quest,
            photoUrl: photoUrl,
          );

      final verification = await _verificationService.verify(
        quest: quest,
        submission: submission,
      );

      completionMessage = verification.message;

      if (!verification.isVerified) {
        return false;
      }

      await _questService.completeQuest(
        userId: userId,
        quest: quest,
      );

      final completedQuest = progress.copyWith(
        status: QuestStatus.completed,
        completedAt: DateTime.now(),
      );

      _replaceUserQuest(completedQuest);

      completionMessage = 'Quest completed! +${quest.rewardXp} XP';

      return true;
    } catch (error) {
      debugPrint('[QuestController] Failed completing quest: $error');

      errorMessage = 'Could not complete quest.';
      return false;
    } finally {
      isCompletingQuest = false;
      notifyListeners();
    }
  }

  void selectCategory(QuestCategory? category) {
    selectedCategory = category;
    notifyListeners();
  }

  void clearMessages() {
    errorMessage = null;
    completionMessage = null;
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
    final progress = progressForQuest(questId);

    return progress != null &&
        progress.status != QuestStatus.available &&
        progress.status != QuestStatus.expired;
  }

  bool isQuestCompleted(String questId) {
    return progressForQuest(questId)?.status == QuestStatus.completed;
  }

  void _replaceUserQuest(UserQuest updatedQuest) {
    final index = _userQuests.indexWhere(
      (quest) => quest.questId == updatedQuest.questId,
    );

    if (index == -1) {
      _userQuests.add(updatedQuest);
      return;
    }

    _userQuests[index] = updatedQuest;
  }
}