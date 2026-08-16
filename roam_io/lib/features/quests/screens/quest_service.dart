/*
 * Description:
 *   Handles Firestore reads and writes for quest definitions and
 *   user quest progress.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:roam_io/features/quests/screens/data/quest.dart';
import 'package:roam_io/features/quests/screens/data/user_quest.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';



class QuestService {
  QuestService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _questsCollection {
    return _firestore.collection('quests');
  }

  CollectionReference<Map<String, dynamic>> _userQuestsCollection(
    String userId,
  ) {
    return _firestore
        .collection('profiles')
        .doc(userId)
        .collection('quests');
  }

  Future<List<Quest>> getAvailableQuests() async {
    debugPrint('[QuestService] Loading available quests...');

    final snapshot = await _questsCollection
        .where('isActive', isEqualTo: true)
        .get();

    debugPrint(
      '[QuestService] Firestore returned ${snapshot.docs.length} quest docs',
    );

    final now = DateTime.now();

    final quests = snapshot.docs.map((document) {
      debugPrint(
        '[QuestService] Quest ${document.id}: ${document.data()}',
      );

      return Quest.fromFirestore(document);
    }).where((quest) {
      final available = quest.isAvailableAt(now);

      debugPrint(
        '[QuestService] ${quest.id} available=$available '
        'active=${quest.isActive} '
        'from=${quest.availableFrom} '
        'until=${quest.availableUntil}',
      );

      return available;
    }).toList();

    debugPrint(
      '[QuestService] Returning ${quests.length} available quests',
    );

    quests.sort((a, b) => b.rewardXp.compareTo(a.rewardXp));

    return quests;
}

  Future<List<Quest>> getQuestsForRegion(String regionId) async {
    final snapshot = await _questsCollection
        .where('isActive', isEqualTo: true)
        .where('regionId', isEqualTo: regionId)
        .get();

    final now = DateTime.now();

    return snapshot.docs
        .map(Quest.fromFirestore)
        .where((quest) => quest.isAvailableAt(now))
        .toList();
  }

  Future<Quest?> getQuestById(String questId) async {
    final document = await _questsCollection.doc(questId).get();

    if (!document.exists) {
      return null;
    }

    return Quest.fromFirestore(document);
  }

  Future<List<UserQuest>> getUserQuests(String userId) async {
    final snapshot = await _userQuestsCollection(userId).get();

    return snapshot.docs
        .map(
          (document) => UserQuest.fromFirestore(
            userId: userId,
            document: document,
          ),
        )
        .toList();
  }

  Future<UserQuest?> getUserQuest({
    required String userId,
    required String questId,
  }) async {
    final document = await _userQuestsCollection(userId).doc(questId).get();

    if (!document.exists) {
      return null;
    }

    return UserQuest.fromFirestore(
      userId: userId,
      document: document,
    );
  }

  Future<UserQuest> startQuest({
    required String userId,
    required String questId,
  }) async {
    final existing = await getUserQuest(
      userId: userId,
      questId: questId,
    );

    if (existing != null) {
      return existing;
    }

    final now = DateTime.now();

    final userQuest = UserQuest(
      id: questId,
      userId: userId,
      questId: questId,
      status: QuestStatus.active,
      startedAt: now,
    );

    await _userQuestsCollection(userId).doc(questId).set(
          userQuest.toMap(),
        );

    return userQuest;
  }

  Future<void> completeQuest({
  required String userId,
  required Quest quest,
}) async {
  final userQuestRef = _userQuestsCollection(userId).doc(quest.id);
  final profileRef = _firestore.collection('profiles').doc(userId);

  await _firestore.runTransaction((transaction) async {
    final userQuestSnapshot = await transaction.get(userQuestRef);
    final profileSnapshot = await transaction.get(profileRef);

    if (!userQuestSnapshot.exists) {
      throw StateError('Quest must be started before completion.');
    }

    final userQuestData = userQuestSnapshot.data();

    if (userQuestData?['status'] == QuestStatus.completed.name) {
      return;
    }

    final profileData = profileSnapshot.data();
    final currentXp = (profileData?['xp'] as num?)?.toInt() ?? 0;

    transaction.update(
      userQuestRef,
      {
        'status': QuestStatus.completed.name,
        'completedAt': FieldValue.serverTimestamp(),
      },
    );

    transaction.set(
      profileRef,
      {
        'xp': currentXp + quest.rewardXp,
      },
      SetOptions(merge: true),
    );
  });
}

  Future<void> updateQuestStatus({
    required String userId,
    required String questId,
    required QuestStatus status,
    String? rejectionReason,
  }) async {
    final updates = <String, dynamic>{
      'status': status.name,
    };

    if (status == QuestStatus.submitted) {
      updates['submittedAt'] = FieldValue.serverTimestamp();
    }

    if (status == QuestStatus.completed) {
      updates['completedAt'] = FieldValue.serverTimestamp();
    }

    if (rejectionReason != null) {
      updates['rejectionReason'] = rejectionReason;
    }

    await _userQuestsCollection(userId).doc(questId).update(updates);
  }
}