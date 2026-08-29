import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roam_io/features/quests/screens/data/user_quest.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';

void main() {
  group('UserQuest', () {
    test('constructs active quest progress', () {
      final startedAt = DateTime(2026, 8, 20);

      final quest = UserQuest(
        id: 'quest-1',
        userId: 'user-1',
        questId: 'quest-1',
        status: QuestStatus.active,
        startedAt: startedAt,
      );

      expect(quest.id, 'quest-1');

      expect(quest.userId, 'user-1');

      expect(quest.questId, 'quest-1');

      expect(quest.status, QuestStatus.active);

      expect(quest.startedAt, startedAt);
    });

    test('toMap stores quest progress fields', () {
      final startedAt = DateTime(2026, 8, 20);

      final quest = UserQuest(
        id: 'quest-1',
        userId: 'user-1',
        questId: 'quest-1',
        status: QuestStatus.active,
        startedAt: startedAt,
      );

      final map = quest.toMap();

      expect(map['questId'], 'quest-1');

      expect(map['status'], 'active');

      expect(map['startedAt'], isNotNull);
    });

    test('copyWith changes status', () {
      final quest = UserQuest(
        id: 'quest-1',
        userId: 'user-1',
        questId: 'quest-1',
        status: QuestStatus.active,
        startedAt: DateTime(2026, 8, 20),
      );

      final completed = quest.copyWith(
        status: QuestStatus.completed,
        completedAt: DateTime(2026, 8, 21),
      );

      expect(completed.status, QuestStatus.completed);

      expect(completed.completedAt, DateTime(2026, 8, 21));

      expect(completed.userId, quest.userId);

      expect(completed.questId, quest.questId);
    });

    test('fromFirestore reads active progress', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('quests')
          .doc('quest-1')
          .set({
            'userId': 'user-1',
            'questId': 'quest-1',
            'status': 'active',
            'startedAt': DateTime(2026, 8, 20),
          });

      final document = await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('quests')
          .doc('quest-1')
          .get();

      final progress = UserQuest.fromFirestore(
        userId: 'user-1',
        document: document,
      );

      expect(progress.id, 'quest-1');

      expect(progress.userId, 'user-1');

      expect(progress.questId, 'quest-1');

      expect(progress.status, QuestStatus.active);
    });

    test('fromFirestore reads submitted progress', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('quests')
          .doc('quest-1')
          .set({
            'userId': 'user-1',
            'questId': 'quest-1',
            'status': 'submitted',
            'startedAt': DateTime(2026, 8, 20),
            'submittedAt': DateTime(2026, 8, 21),
          });

      final document = await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('quests')
          .doc('quest-1')
          .get();

      final progress = UserQuest.fromFirestore(
        userId: 'user-1',
        document: document,
      );

      expect(progress.status, QuestStatus.submitted);

      expect(progress.submittedAt, isNotNull);
    });

    test('fromFirestore reads completed progress', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('quests')
          .doc('quest-1')
          .set({
            'userId': 'user-1',
            'questId': 'quest-1',
            'status': 'completed',
            'startedAt': DateTime(2026, 8, 20),
            'completedAt': DateTime(2026, 8, 21),
          });

      final document = await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('quests')
          .doc('quest-1')
          .get();

      final progress = UserQuest.fromFirestore(
        userId: 'user-1',
        document: document,
      );

      expect(progress.status, QuestStatus.completed);

      expect(progress.completedAt, isNotNull);
    });

    test('fromFirestore reads rejection reason', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('quests')
          .doc('quest-1')
          .set({
            'userId': 'user-1',
            'questId': 'quest-1',
            'status': 'rejected',
            'startedAt': DateTime(2026, 8, 20),
            'rejectionReason': 'The submitted photo could not be verified.',
          });

      final document = await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('quests')
          .doc('quest-1')
          .get();

      final progress = UserQuest.fromFirestore(
        userId: 'user-1',
        document: document,
      );

      expect(progress.status, QuestStatus.rejected);

      expect(
        progress.rejectionReason,
        'The submitted photo could not be verified.',
      );
    });
  });
}
