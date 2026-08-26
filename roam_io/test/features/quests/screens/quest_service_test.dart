import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roam_io/features/quests/screens/data/quest.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';
import 'package:roam_io/features/quests/screens/quest_service.dart';

void main() {
  group('QuestService', () {
    test('loads active available quests', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await _seedQuest(firestore, id: 'quest-1');

      final quests = await service.getAvailableQuests();

      expect(quests, hasLength(1));
      expect(quests.single.id, 'quest-1');
    });

    test('does not load inactive quests', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await _seedQuest(firestore, id: 'inactive', isActive: false);

      final quests = await service.getAvailableQuests();

      expect(quests, isEmpty);
    });

    test('sorts available quests by XP descending', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await _seedQuest(firestore, id: 'low', rewardXp: 100);

      await _seedQuest(firestore, id: 'high', rewardXp: 500);

      await _seedQuest(firestore, id: 'medium', rewardXp: 250);

      final quests = await service.getAvailableQuests();

      expect(quests.map((quest) => quest.id).toList(), [
        'high',
        'medium',
        'low',
      ]);
    });

    test('does not return quest before availableFrom', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await _seedQuest(firestore, id: 'future', availableFrom: DateTime(2100));

      final quests = await service.getAvailableQuests();

      expect(quests, isEmpty);
    });

    test('does not return quest after availableUntil', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await _seedQuest(
        firestore,
        id: 'expired',
        availableUntil: DateTime(2000),
      );

      final quests = await service.getAvailableQuests();

      expect(quests, isEmpty);
    });

    test('loads quest by id', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await _seedQuest(firestore, id: 'museum', title: 'Museum Explorer');

      final quest = await service.getQuestById('museum');

      expect(quest, isNotNull);
      expect(quest!.id, 'museum');
      expect(quest.title, 'Museum Explorer');
    });

    test('returns null for missing quest', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      final quest = await service.getQuestById('missing');

      expect(quest, isNull);
    });

    test('loads only quests belonging to requested region', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await _seedQuest(firestore, id: 'melbourne', regionId: 'melbourne');

      await _seedQuest(firestore, id: 'dandenong', regionId: 'dandenong');

      final quests = await service.getQuestsForRegion('melbourne');

      expect(quests, hasLength(1));
      expect(quests.single.id, 'melbourne');
    });

    test('region query excludes inactive quests', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await _seedQuest(firestore, id: 'active', regionId: 'melbourne');

      await _seedQuest(
        firestore,
        id: 'inactive',
        regionId: 'melbourne',
        isActive: false,
      );

      final quests = await service.getQuestsForRegion('melbourne');

      expect(quests, hasLength(1));
      expect(quests.single.id, 'active');
    });

    test('region query excludes unavailable quests', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await _seedQuest(
        firestore,
        id: 'future',
        regionId: 'melbourne',
        availableFrom: DateTime(2100),
      );

      final quests = await service.getQuestsForRegion('melbourne');

      expect(quests, isEmpty);
    });

    test('starting quest stores active progress', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      final progress = await service.startQuest(
        userId: 'user-1',
        questId: 'quest-1',
      );

      expect(progress.userId, 'user-1');
      expect(progress.questId, 'quest-1');
      expect(progress.status, QuestStatus.active);
      expect(progress.startedAt, isNotNull);

      final document = await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('quests')
          .doc('quest-1')
          .get();

      expect(document.exists, isTrue);
      expect(document.data()?['status'], 'active');
    });

    test('starting same quest twice does not duplicate progress', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await service.startQuest(userId: 'user-1', questId: 'quest-1');

      await service.startQuest(userId: 'user-1', questId: 'quest-1');

      final snapshot = await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('quests')
          .get();

      expect(snapshot.docs, hasLength(1));
    });

    test('starting existing quest preserves existing progress', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await service.startQuest(userId: 'user-1', questId: 'quest-1');

      await service.updateQuestStatus(
        userId: 'user-1',
        questId: 'quest-1',
        status: QuestStatus.submitted,
      );

      final existing = await service.startQuest(
        userId: 'user-1',
        questId: 'quest-1',
      );

      expect(existing.status, QuestStatus.submitted);
    });

    test('returns null for missing user quest', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      final result = await service.getUserQuest(
        userId: 'user-1',
        questId: 'missing',
      );

      expect(result, isNull);
    });

    test('loads all user quests', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await service.startQuest(userId: 'user-1', questId: 'quest-1');

      await service.startQuest(userId: 'user-1', questId: 'quest-2');

      final quests = await service.getUserQuests('user-1');

      expect(quests, hasLength(2));

      expect(
        quests.map((quest) => quest.questId),
        containsAll(['quest-1', 'quest-2']),
      );
    });

    test('updates quest status to submitted', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await service.startQuest(userId: 'user-1', questId: 'quest-1');

      await service.updateQuestStatus(
        userId: 'user-1',
        questId: 'quest-1',
        status: QuestStatus.submitted,
      );

      final progress = await service.getUserQuest(
        userId: 'user-1',
        questId: 'quest-1',
      );

      expect(progress?.status, QuestStatus.submitted);

      expect(progress?.submittedAt, isNotNull);
    });

    test('updates quest status to completed', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await service.startQuest(userId: 'user-1', questId: 'quest-1');

      await service.updateQuestStatus(
        userId: 'user-1',
        questId: 'quest-1',
        status: QuestStatus.completed,
      );

      final progress = await service.getUserQuest(
        userId: 'user-1',
        questId: 'quest-1',
      );

      expect(progress?.status, QuestStatus.completed);

      expect(progress?.completedAt, isNotNull);
    });

    test('stores rejection reason', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await service.startQuest(userId: 'user-1', questId: 'quest-1');

      await service.updateQuestStatus(
        userId: 'user-1',
        questId: 'quest-1',
        status: QuestStatus.rejected,
        rejectionReason: 'Photo did not match.',
      );

      final progress = await service.getUserQuest(
        userId: 'user-1',
        questId: 'quest-1',
      );

      expect(progress?.status, QuestStatus.rejected);

      expect(progress?.rejectionReason, 'Photo did not match.');
    });

    test('completion requires quest to have been started', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      final quest = _quest(id: 'quest-1', rewardXp: 200);

      expect(
        () => service.completeQuest(userId: 'user-1', quest: quest),
        throwsA(isA<StateError>()),
      );
    });

    test('completion awards XP to existing profile', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await firestore.collection('profiles').doc('user-1').set({'xp': 100});

      final quest = _quest(id: 'quest-1', rewardXp: 300);

      await service.startQuest(userId: 'user-1', questId: quest.id);

      await service.completeQuest(userId: 'user-1', quest: quest);

      final profile = await firestore
          .collection('profiles')
          .doc('user-1')
          .get();

      expect(profile.data()?['xp'], 400);
    });

    test('completion creates XP when profile has no XP field', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await firestore.collection('profiles').doc('user-1').set({
        'username': 'traveller',
      });

      final quest = _quest(id: 'quest-1', rewardXp: 250);

      await service.startQuest(userId: 'user-1', questId: quest.id);

      await service.completeQuest(userId: 'user-1', quest: quest);

      final profile = await firestore
          .collection('profiles')
          .doc('user-1')
          .get();

      expect(profile.data()?['xp'], 250);
    });

    test('completion marks progress completed', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      final quest = _quest(id: 'quest-1', rewardXp: 100);

      await service.startQuest(userId: 'user-1', questId: quest.id);

      await service.completeQuest(userId: 'user-1', quest: quest);

      final progress = await service.getUserQuest(
        userId: 'user-1',
        questId: quest.id,
      );

      expect(progress?.status, QuestStatus.completed);

      expect(progress?.completedAt, isNotNull);
    });

    test('completed quest cannot award XP twice', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await firestore.collection('profiles').doc('user-1').set({'xp': 100});

      final quest = _quest(id: 'quest-1', rewardXp: 300);

      await service.startQuest(userId: 'user-1', questId: quest.id);

      await service.completeQuest(userId: 'user-1', quest: quest);

      await service.completeQuest(userId: 'user-1', quest: quest);

      final profile = await firestore
          .collection('profiles')
          .doc('user-1')
          .get();

      expect(profile.data()?['xp'], 400);
    });
  });
}

Future<void> _seedQuest(
  FakeFirebaseFirestore firestore, {
  required String id,
  String title = 'Test Quest',
  bool isActive = true,
  int rewardXp = 200,
  String? regionId,
  DateTime? availableFrom,
  DateTime? availableUntil,
}) {
  return firestore.collection('quests').doc(id).set({
    'title': title,
    'description': 'Complete this test quest.',
    'category': QuestCategory.adventure.name,
    'difficulty': QuestDifficulty.easy.name,
    'rewardXp': rewardXp,
    'verificationType': QuestVerificationType.gps.name,
    'isActive': isActive,
    'regionId': regionId,
    'latitude': -37.81,
    'longitude': 144.96,
    'verificationRadiusMetres': 200,
    'availableFrom': availableFrom == null
        ? null
        : Timestamp.fromDate(availableFrom),
    'availableUntil': availableUntil == null
        ? null
        : Timestamp.fromDate(availableUntil),
  });
}

Quest _quest({required String id, required int rewardXp}) {
  return Quest(
    id: id,
    title: 'Test Quest',
    description: 'Complete this test quest.',
    category: QuestCategory.adventure,
    difficulty: QuestDifficulty.easy,
    rewardXp: rewardXp,
    verificationType: QuestVerificationType.gps,
    isActive: true,
    latitude: -37.81,
    longitude: 144.96,
    verificationRadiusMetres: 200,
  );
}
