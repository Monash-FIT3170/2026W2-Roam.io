import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roam_io/features/quests/screens/data/quest.dart';
import 'package:roam_io/features/quests/screens/data/user_quest.dart';
import 'package:roam_io/features/quests/screens/quest_controller.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';
import 'package:roam_io/features/quests/screens/quest_service.dart';
import 'package:roam_io/features/quests/screens/quest_submission.dart';
import 'package:roam_io/features/quests/screens/quest_verification.dart';
import 'package:roam_io/features/quests/screens/quest_verification_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  group('QuestController', () {
    test(
      'status and category filters compose with consistent counts',
      () async {
        final db = FakeFirebaseFirestore();
        for (final status in QuestStatus.values) {
          await _seedQuest(db, id: status.name, category: QuestCategory.nature);
          if (status != QuestStatus.available) {
            await db
                .collection('profiles')
                .doc('user-1')
                .collection('quests')
                .doc(status.name)
                .set(
                  UserQuest(
                    id: status.name,
                    userId: 'user-1',
                    questId: status.name,
                    status: status,
                    startedAt: DateTime(2026),
                  ).toMap(),
                );
          }
        }
        await _seedQuest(db, id: 'other-category');
        final controller = _controller(db);
        addTearDown(controller.dispose);
        await controller.initialise(userId: 'user-1');
        controller.selectCategory(QuestCategory.nature);
        expect(controller.countForStatus(QuestStatusFilter.all), 6);
        expect(controller.countForStatus(QuestStatusFilter.available), 1);
        expect(controller.countForStatus(QuestStatusFilter.active), 2);
        expect(controller.countForStatus(QuestStatusFilter.completed), 1);
        controller.selectStatus(QuestStatusFilter.active);
        expect(
          controller.quests.map((q) => q.id),
          containsAll(['active', 'submitted']),
        );
        expect(controller.quests, hasLength(2));
        await controller.loadQuests(userId: 'user-1');
        expect(controller.selectedStatus, QuestStatusFilter.active);
        expect(controller.selectedCategory, QuestCategory.nature);
        controller.selectStatus(QuestStatusFilter.completed);
        expect(controller.quests.single.id, 'completed');
        controller.selectStatus(QuestStatusFilter.available);
        expect(controller.quests.single.id, 'available');
        controller.resetFilters();
        expect(controller.quests, hasLength(7));
      },
    );

    test('expired quests cannot be started or completed', () async {
      final db = FakeFirebaseFirestore();
      await _seedQuest(db, id: 'retired', isActive: false);
      final controller = _controller(db);
      final quest = (await QuestService(
        firestore: db,
      ).getQuestById('retired'))!;
      expect(
        await controller.startQuest(userId: 'user-1', quest: quest),
        isFalse,
      );
      expect(
        (await db.doc('profiles/user-1/quests/retired').get()).exists,
        isFalse,
      );
      await db.doc('profiles/user-1/quests/retired').set({
        'questId': 'retired',
        'status': 'active',
      });
      await controller.initialise(userId: 'user-1');
      expect(
        await controller.completeQuest(userId: 'user-1', quest: quest),
        isFalse,
      );
      expect(controller.errorMessage, contains('no longer available'));
      expect(
        (await db.doc('profiles/user-1/quests/retired').get())
            .data()!['status'],
        'active',
      );
    });

    test('restores completed history after a definition is retired', () async {
      final db = FakeFirebaseFirestore();
      await _seedQuest(db, id: 'retired', isActive: false);
      await _seedQuest(db, id: 'expired-active', isActive: false);
      for (final id in ['retired', 'expired-active', 'deleted']) {
        await db
            .collection('profiles')
            .doc('user-1')
            .collection('quests')
            .doc(id)
            .set(
              UserQuest(
                id: id,
                userId: 'user-1',
                questId: id,
                status: id == 'expired-active'
                    ? QuestStatus.active
                    : QuestStatus.completed,
                startedAt: DateTime(2026),
              ).toMap(),
            );
      }
      final controller = _controller(db);
      addTearDown(controller.dispose);
      await controller.initialise(userId: 'user-1');
      expect(controller.quests, hasLength(2));
      expect(
        controller.statusForQuest(
          controller.quests.firstWhere((q) => q.id == 'expired-active'),
        ),
        QuestStatus.expired,
      );
      controller.selectStatus(QuestStatusFilter.completed);
      expect(controller.quests.single.id, 'retired');
      expect(controller.countForStatus(QuestStatusFilter.completed), 1);
      await controller.loadQuests();
      expect(controller.quests, isEmpty);
      expect(controller.userQuests, isEmpty);
    });

    test(
      'progress read failures are not treated as available quests',
      () async {
        final controller = QuestController(
          questService: _FailingProgressService(),
          verificationService: _FakeQuestVerificationService(),
        );
        addTearDown(controller.dispose);
        await controller.initialise(userId: 'user-1');
        expect(controller.loadErrorMessage, isNotNull);
        expect(controller.quests, isEmpty);
        expect(controller.isLoading, isFalse);
      },
    );

    test('initialise loads active global quests', () async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(
        firestore,
        id: 'quest-1',
        category: QuestCategory.adventure,
      );

      await _seedQuest(
        firestore,
        id: 'quest-2',
        category: QuestCategory.nature,
      );

      final controller = _controller(firestore);

      await controller.initialise();

      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.quests, hasLength(2));

      expect(
        controller.quests.map((quest) => quest.id),
        containsAll(<String>['quest-1', 'quest-2']),
      );
    });

    test('initialise ignores inactive quests', () async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(firestore, id: 'active', isActive: true);

      await _seedQuest(firestore, id: 'inactive', isActive: false);

      final controller = _controller(firestore);

      await controller.initialise();

      expect(controller.quests, hasLength(1));
      expect(controller.quests.single.id, 'active');
    });

    test('selectCategory filters loaded quests', () async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(
        firestore,
        id: 'adventure',
        category: QuestCategory.adventure,
      );

      await _seedQuest(firestore, id: 'nature', category: QuestCategory.nature);

      await _seedQuest(
        firestore,
        id: 'another-nature',
        category: QuestCategory.nature,
      );

      final controller = _controller(firestore);

      await controller.initialise();

      expect(controller.quests, hasLength(3));

      controller.selectCategory(QuestCategory.nature);

      expect(controller.selectedCategory, QuestCategory.nature);
      expect(controller.quests, hasLength(2));
      expect(
        controller.quests.every(
          (quest) => quest.category == QuestCategory.nature,
        ),
        isTrue,
      );
    });

    test('selectCategory null restores all quests', () async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(
        firestore,
        id: 'quest-1',
        category: QuestCategory.adventure,
      );

      await _seedQuest(firestore, id: 'quest-2', category: QuestCategory.food);

      final controller = _controller(firestore);

      await controller.initialise();

      controller.selectCategory(QuestCategory.food);
      expect(controller.quests, hasLength(1));

      controller.selectCategory(null);

      expect(controller.selectedCategory, isNull);
      expect(controller.quests, hasLength(2));
    });

    test('startQuest creates active user progress', () async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(firestore, id: 'quest-1');

      final controller = _controller(firestore);

      await controller.initialise(userId: 'user-1');

      final quest = controller.quests.single;

      final success = await controller.startQuest(
        userId: 'user-1',
        quest: quest,
      );

      expect(success, isTrue);
      expect(controller.isStartingQuest, isFalse);
      expect(controller.errorMessage, isNull);

      final progress = controller.progressForQuest('quest-1');

      expect(progress, isNotNull);
      expect(progress!.questId, 'quest-1');
      expect(progress.status, QuestStatus.active);

      expect(controller.isQuestStarted('quest-1'), isTrue);
      expect(controller.isQuestCompleted('quest-1'), isFalse);
      expect(controller.activeQuests, hasLength(1));
      expect(controller.completedQuests, isEmpty);
    });

    test('starting same quest twice does not duplicate progress', () async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(firestore, id: 'quest-1');

      final controller = _controller(firestore);

      await controller.initialise(userId: 'user-1');

      final quest = controller.quests.single;

      expect(
        await controller.startQuest(userId: 'user-1', quest: quest),
        isTrue,
      );

      expect(
        await controller.startQuest(userId: 'user-1', quest: quest),
        isTrue,
      );

      expect(controller.userQuests, hasLength(1));

      final stored = await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('quests')
          .get();

      expect(stored.docs, hasLength(1));
    });

    test('completeQuest fails when quest has not been started', () async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(firestore, id: 'quest-1');

      final controller = _controller(firestore);

      await controller.initialise();

      final success = await controller.completeQuest(
        userId: 'user-1',
        quest: controller.quests.single,
      );

      expect(success, isFalse);
      expect(controller.lastVerificationPassed, isFalse);
      expect(controller.errorMessage, 'Start this quest before completing it.');
    });

    test('failed verification keeps quest active', () async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(firestore, id: 'quest-1');

      await firestore.collection('profiles').doc('user-1').set({'xp': 100});

      final verifier = _FakeQuestVerificationService(
        result: const QuestVerificationResult(
          isVerified: false,
          message: 'Move closer to the quest location.',
        ),
      );

      final controller = _controller(firestore, verificationService: verifier);

      await controller.initialise(userId: 'user-1');

      final quest = controller.quests.single;

      await controller.startQuest(userId: 'user-1', quest: quest);

      final success = await controller.completeQuest(
        userId: 'user-1',
        quest: quest,
      );

      expect(success, isFalse);
      expect(controller.lastVerificationPassed, isFalse);
      expect(
        controller.completionMessage,
        'Move closer to the quest location.',
      );

      expect(controller.progressForQuest(quest.id)?.status, QuestStatus.active);

      expect(controller.completedQuests, isEmpty);
      expect(controller.activeQuests, hasLength(1));

      final profile = await firestore
          .collection('profiles')
          .doc('user-1')
          .get();

      expect(profile.data()?['xp'], 100);
    });

    test('successful verification completes quest and awards XP', () async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(firestore, id: 'quest-1', rewardXp: 300);

      await firestore.collection('profiles').doc('user-1').set({'xp': 100});

      final verifier = _FakeQuestVerificationService(
        result: const QuestVerificationResult(
          isVerified: true,
          message: 'Location verified.',
        ),
      );

      final controller = _controller(firestore, verificationService: verifier);

      await controller.initialise(userId: 'user-1');

      final quest = controller.quests.single;

      await controller.startQuest(userId: 'user-1', quest: quest);

      final success = await controller.completeQuest(
        userId: 'user-1',
        quest: quest,
      );

      expect(success, isTrue);
      expect(controller.lastVerificationPassed, isTrue);
      expect(controller.completionMessage, 'Quest completed! +300 XP');

      expect(
        controller.progressForQuest(quest.id)?.status,
        QuestStatus.completed,
      );

      expect(controller.isQuestCompleted(quest.id), isTrue);
      expect(controller.completedQuests, hasLength(1));
      expect(controller.activeQuests, isEmpty);

      final profile = await firestore
          .collection('profiles')
          .doc('user-1')
          .get();

      expect(profile.data()?['xp'], 400);
    });

    test(
      'already completed quest returns true without awarding XP again',
      () async {
        final firestore = FakeFirebaseFirestore();

        await _seedQuest(firestore, id: 'quest-1', rewardXp: 250);

        await firestore.collection('profiles').doc('user-1').set({'xp': 50});

        final verifier = _FakeQuestVerificationService(
          result: const QuestVerificationResult(
            isVerified: true,
            message: 'Verified.',
          ),
        );

        final controller = _controller(
          firestore,
          verificationService: verifier,
        );

        await controller.initialise(userId: 'user-1');

        final quest = controller.quests.single;

        await controller.startQuest(userId: 'user-1', quest: quest);

        expect(
          await controller.completeQuest(userId: 'user-1', quest: quest),
          isTrue,
        );

        expect(
          await controller.completeQuest(userId: 'user-1', quest: quest),
          isTrue,
        );

        expect(controller.completionMessage, 'Quest already completed.');

        final profile = await firestore
            .collection('profiles')
            .doc('user-1')
            .get();

        expect(profile.data()?['xp'], 300);
      },
    );

    test('initialise loads existing user quest progress', () async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(firestore, id: 'quest-1');

      final service = QuestService(firestore: firestore);

      await service.startQuest(userId: 'user-1', questId: 'quest-1');

      final controller = QuestController(
        questService: service,
        verificationService: _FakeQuestVerificationService(),
      );

      await controller.initialise(userId: 'user-1');

      expect(controller.userQuests, hasLength(1));
      expect(controller.isQuestStarted('quest-1'), isTrue);
      expect(
        controller.progressForQuest('quest-1')?.status,
        QuestStatus.active,
      );
    });

    test('progressForQuest returns null for unknown quest', () {
      final firestore = FakeFirebaseFirestore();

      final controller = _controller(firestore);

      expect(controller.progressForQuest('missing'), isNull);

      expect(controller.isQuestStarted('missing'), isFalse);

      expect(controller.isQuestCompleted('missing'), isFalse);
    });

    test('clearMessages clears error and verification state', () async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(firestore, id: 'quest-1');

      final controller = _controller(firestore);

      await controller.initialise();

      await controller.completeQuest(
        userId: 'user-1',
        quest: controller.quests.single,
      );

      expect(controller.errorMessage, isNotNull);
      expect(controller.lastVerificationPassed, isFalse);

      controller.clearMessages();

      expect(controller.errorMessage, isNull);
      expect(controller.completionMessage, isNull);
      expect(controller.lastVerificationPassed, isNull);
    });
  });
}

QuestController _controller(
  FakeFirebaseFirestore firestore, {
  QuestVerificationService? verificationService,
}) {
  return QuestController(
    questService: QuestService(firestore: firestore),
    verificationService: verificationService ?? _FakeQuestVerificationService(),
  );
}

Future<void> _seedQuest(
  FakeFirebaseFirestore firestore, {
  required String id,
  QuestCategory category = QuestCategory.adventure,
  bool isActive = true,
  int rewardXp = 200,
}) {
  return firestore.collection('quests').doc(id).set({
    'title': 'Quest $id',
    'description': 'Complete quest $id.',
    'category': category.name,
    'difficulty': QuestDifficulty.easy.name,
    'rewardXp': rewardXp,
    'verificationType': QuestVerificationType.gps.name,
    'isActive': isActive,
    'latitude': -37.8206,
    'longitude': 144.9585,
    'verificationRadiusMetres': 200,
  });
}

class _FakeQuestVerificationService extends QuestVerificationService {
  _FakeQuestVerificationService({
    this.result = const QuestVerificationResult(
      isVerified: true,
      message: 'Verified.',
    ),
  });

  final QuestVerificationResult result;

  @override
  Future<QuestSubmission> createSubmission({required Quest quest}) async {
    return QuestSubmission(
      questId: quest.id,
      latitude: quest.latitude,
      longitude: quest.longitude,
    );
  }

  @override
  Future<QuestVerificationResult> verify({
    required Quest quest,
    required QuestSubmission submission,
    Uint8List? photoBytes,
    String photoMimeType = 'image/jpeg',
  }) async {
    return result;
  }
}

class _FailingProgressService extends QuestService {
  @override
  Future<List<Quest>> getAvailableQuests() async => [];

  @override
  Future<List<UserQuest>> getUserQuests(String userId) async {
    throw StateError('Progress unavailable');
  }
}
