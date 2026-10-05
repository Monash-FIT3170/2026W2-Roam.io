/*
 * Description:
 *   Coordinates quest loading, filtering, starting, verification and
 *   completion.
 */

import 'package:flutter/foundation.dart';

import 'data/quest.dart';
import 'data/user_quest.dart';
import 'quest_enums.dart';
import 'quest_service.dart';
import 'quest_verification_service.dart';

class QuestController extends ChangeNotifier {
  QuestController({
    QuestService? questService,
    QuestVerificationService? verificationService,
  }) : _questService = questService ?? QuestService(),
       _verificationService = verificationService ?? QuestVerificationService();

  final QuestService _questService;
  final QuestVerificationService _verificationService;

  List<Quest> _quests = <Quest>[];
  List<UserQuest> _userQuests = <UserQuest>[];

  bool isLoading = false;
  bool isStartingQuest = false;
  bool isCompletingQuest = false;

  String? errorMessage;
  String? loadErrorMessage;
  String? completionMessage;

  /// null = no latest verification attempt.
  bool? lastVerificationPassed;

  QuestCategory? selectedCategory;
  QuestStatusFilter selectedStatus = QuestStatusFilter.all;

  QuestStatus statusForQuest(Quest quest) {
    final status = progressForQuest(quest.id)?.status;
    // Completion and submitted evidence remain meaningful after availability ends.
    if (status == QuestStatus.completed || status == QuestStatus.submitted) {
      return status!;
    }
    if (!quest.isAvailableAt(DateTime.now())) return QuestStatus.expired;
    return status ?? QuestStatus.available;
  }

  Iterable<Quest> get _categoryQuests => _quests.where(
    (quest) => selectedCategory == null || quest.category == selectedCategory,
  );

  int countForStatus(QuestStatusFilter filter) => _categoryQuests
      .where((quest) => filter.includes(statusForQuest(quest)))
      .length;

  bool get hasQuests => _quests.isNotEmpty;

  void selectStatus(QuestStatusFilter status) {
    selectedStatus = status;
    notifyListeners();
  }

  void resetFilters() {
    selectedCategory = null;
    selectedStatus = QuestStatusFilter.all;
    notifyListeners();
  }

  List<Quest> get quests {
    return List<Quest>.unmodifiable(
      _categoryQuests.where(
        (quest) => selectedStatus.includes(statusForQuest(quest)),
      ),
    );
  }

  List<UserQuest> get userQuests => List<UserQuest>.unmodifiable(_userQuests);

  List<UserQuest> get activeQuests => List<UserQuest>.unmodifiable(
    _userQuests.where(
      (quest) =>
          quest.status == QuestStatus.active ||
          quest.status == QuestStatus.submitted,
    ),
  );

  List<UserQuest> get completedQuests => List<UserQuest>.unmodifiable(
    _userQuests.where((quest) => quest.status == QuestStatus.completed),
  );

  Future<void> initialise({String? userId}) {
    return loadQuests(userId: userId);
  }

  Future<void> loadQuests({String? userId, String? regionId}) async {
    isLoading = true;
    errorMessage = null;
    loadErrorMessage = null;

    notifyListeners();

    try {
      final available = regionId == null
          ? await _questService.getAvailableQuests()
          : await _questService.getQuestsForRegion(regionId);
      final progress = userId == null
          ? <UserQuest>[]
          : await _questService.getUserQuests(userId);
      final byId = {for (final quest in available) quest.id: quest};
      final missingIds = progress
          .map((entry) => entry.questId)
          .where((id) => !byId.containsKey(id))
          .toSet()
          .toList();
      // Bounded reads restore historical definitions without querying inactive
      // quests belonging to everyone. Deleted definitions are safely omitted.
      for (var offset = 0; offset < missingIds.length; offset += 10) {
        final history = await Future.wait(
          missingIds.skip(offset).take(10).map(_questService.getQuestById),
        );
        for (final quest in history.whereType<Quest>()) {
          if (regionId == null || quest.regionId == regionId) {
            byId[quest.id] = quest;
          }
        }
      }
      _quests = byId.values.toList()
        ..sort((a, b) => b.rewardXp.compareTo(a.rewardXp));
      _userQuests = progress;
    } catch (error, stackTrace) {
      debugPrint('[QuestController] Failed loading quests: $error');

      debugPrintStack(stackTrace: stackTrace);

      errorMessage = 'Could not load quests.';
      loadErrorMessage = 'Could not load quests and their progress. Try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startQuest({
    required String userId,
    required Quest quest,
  }) async {
    final existing = progressForQuest(quest.id);

    if (existing != null) {
      return true;
    }

    isStartingQuest = true;
    clearMessages(notify: false);

    notifyListeners();

    try {
      final progress = await _questService.startQuest(
        userId: userId,
        questId: quest.id,
      );

      _replaceUserQuest(progress);

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
    Uint8List? photoBytes,
    String photoMimeType = 'image/jpeg',
  }) async {
    final progress = progressForQuest(quest.id);

    if (progress == null) {
      errorMessage = 'Start this quest before completing it.';
      lastVerificationPassed = false;
      notifyListeners();
      return false;
    }

    if (progress.status == QuestStatus.completed) {
      completionMessage = 'Quest already completed.';
      lastVerificationPassed = true;
      notifyListeners();
      return true;
    }

    isCompletingQuest = true;
    clearMessages(notify: false);

    notifyListeners();

    try {
      final submission = await _verificationService.createSubmission(
        quest: quest,
      );

      final verification = await _verificationService.verify(
        quest: quest,
        submission: submission,
        photoBytes: photoBytes,
        photoMimeType: photoMimeType,
      );

      lastVerificationPassed = verification.isVerified;

      completionMessage = verification.message;

      if (!verification.isVerified) {
        return false;
      }

      await _questService.completeQuest(userId: userId, quest: quest);

      final completedQuest = progress.copyWith(
        status: QuestStatus.completed,
        completedAt: DateTime.now(),
      );

      _replaceUserQuest(completedQuest);

      completionMessage = 'Quest completed! +${quest.rewardXp} XP';

      lastVerificationPassed = true;

      return true;
    } catch (error, stackTrace) {
      debugPrint('[QuestController] Failed completing quest: $error');

      debugPrintStack(stackTrace: stackTrace);

      errorMessage = 'Could not complete quest. Try again.';

      lastVerificationPassed = false;

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

  void clearMessages({bool notify = true}) {
    errorMessage = null;
    completionMessage = null;
    lastVerificationPassed = null;

    if (notify) {
      notifyListeners();
    }
  }

  UserQuest? progressForQuest(String questId) {
    for (final quest in _userQuests) {
      if (quest.questId == questId) {
        return quest;
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
