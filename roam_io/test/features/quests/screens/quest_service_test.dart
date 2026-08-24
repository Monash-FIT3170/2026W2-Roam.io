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

      await _seedQuest(firestore, id: 'quest-1', isActive: true);

      final quests = await service.getAvailableQuests();

      expect(quests, hasLength(1));
      expect(quests.single.id, 'quest-1');
    });

    test('does not load inactive quests', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await _seedQuest(firestore, id: 'quest-1', isActive: false);

      final quests = await service.getAvailableQuests();

      expect(quests, isEmpty);
    });

    test('loads quest by id', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await _seedQuest(firestore, id: 'aquarium', isActive: true);

      final quest = await service.getQuestById('aquarium');

      expect(quest, isNotNull);
      expect(quest!.id, 'aquarium');
      expect(quest.title, 'Test Quest');
    });

    test('returns null for missing quest id', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      final quest = await service.getQuestById('missing');

      expect(quest, isNull);
    });

    test('loads quests for specified region', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await _seedQuest(
        firestore,
        id: 'melbourne',
        regionId: 'region-melbourne',
      );

      await _seedQuest(
        firestore,
        id: 'dandenong',
        regionId: 'region-dandenong',
      );

      final quests = await service.getQuestsForRegion('region-melbourne');

      expect(quests, hasLength(1));
      expect(quests.single.id, 'melbourne');
    });

    test('starting quest creates user progress document', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      final progress = await service.startQuest(
        userId: 'user-1',
        questId: 'quest-1',
      );

      expect(progress.userId, 'user-1');
      expect(progress.questId, 'quest-1');
      expect(progress.status, QuestStatus.active);

      final document = await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('quests')
          .doc('quest-1')
          .get();

      expect(document.exists, isTrue);
      expect(document.data()?['status'], 'active');
    });

    test('starting same quest twice returns existing progress', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      final first = await service.startQuest(
        userId: 'user-1',
        questId: 'quest-1',
      );

      final second = await service.startQuest(
        userId: 'user-1',
        questId: 'quest-1',
      );

      expect(second.questId, first.questId);

      final snapshot = await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('quests')
          .get();

      expect(snapshot.docs, hasLength(1));
    });

    test('loads user quest progress', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await service.startQuest(userId: 'user-1', questId: 'quest-1');

      await service.startQuest(userId: 'user-1', questId: 'quest-2');

      final quests = await service.getUserQuests('user-1');

      expect(quests, hasLength(2));
      expect(
        quests.every((quest) => quest.status == QuestStatus.active),
        isTrue,
      );
    });

    test('completing quest marks completed and awards XP', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuestService(firestore: firestore);

      await firestore.collection('profiles').doc('user-1').set({'xp': 100});

      final quest = _quest(id: 'quest-1', rewardXp: 300);

      await service.startQuest(userId: 'user-1', questId: quest.id);

      await service.completeQuest(userId: 'user-1', quest: quest);

      final progress = await service.getUserQuest(
        userId: 'user-1',
        questId: quest.id,
      );

      final profile = await firestore
          .collection('profiles')
          .doc('user-1')
          .get();

      expect(progress?.status, QuestStatus.completed);
      expect(profile.data()?['xp'], 400);
    });

    test('completed quest does not award XP twice', () async {
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
  bool isActive = true,
  String? regionId,
}) {
  return firestore.collection('quests').doc(id).set({
    'title': 'Test Quest',
    'description': 'Complete this test quest.',
    'category': 'adventure',
    'difficulty': 'easy',
    'rewardXp': 200,
    'verificationType': 'gps',
    'isActive': isActive,
    'regionId': regionId,
    'latitude': -37.81,
    'longitude': 144.96,
    'verificationRadiusMetres': 200,
  });
}

Quest _quest({required String id, required int rewardXp}) {
  return Quest(
    id: id,
    title: 'Test Quest',
    description: 'Test',
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
