/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Activity-specific Kudos persistence under activities/{activityId}/kudos.
 *   Each user has at most one Kudos document per activity.
 *   Glaze is the current product-facing name; persistence keeps the stable
 *   Kudos collection/type names to avoid a risky migration.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../social/domain/social_notification.dart';

class ActivityGlazer {
  const ActivityGlazer({
    required this.userId,
    required this.displayName,
    this.username,
    this.photoUrl,
  });

  final String userId;
  final String displayName;
  final String? username;
  final String? photoUrl;
}

class KudosService {
  KudosService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _kudos(String activityId) {
    return _firestore
        .collection('activities')
        .doc(activityId)
        .collection('kudos');
  }

  Stream<bool> watchHasGivenKudos({
    required String activityId,
    required String userId,
  }) {
    debugPrint(
      '[KudosService] watchHasGivenKudos activityId=$activityId userId=$userId',
    );
    return _kudos(activityId).doc(userId).snapshots().map((doc) => doc.exists);
  }

  Stream<int> watchKudosCount(String activityId) {
    debugPrint('[KudosService] watchKudosCount activityId=$activityId');
    return _kudos(activityId).snapshots().map((snapshot) => snapshot.size);
  }

  Stream<List<ActivityGlazer>> watchGlazers(String activityId) {
    return _kudos(activityId).snapshots().asyncMap((snapshot) async {
      final seen = <String>{};
      final userIds = <String>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] is String
            ? data['userId'] as String
            : doc.id;
        if (userId.isEmpty || !seen.add(userId)) continue;
        userIds.add(userId);
      }

      final glazers = <ActivityGlazer>[];
      for (final userId in userIds) {
        try {
          final profile = await _firestore
              .collection('public_profiles')
              .doc(userId)
              .get();
          final data = profile.data();
          if (!profile.exists || data == null) continue;
          glazers.add(
            ActivityGlazer(
              userId: userId,
              displayName:
                  (data['displayName'] as String?)?.trim().isNotEmpty == true
                  ? data['displayName'] as String
                  : 'Roam.io user',
              username: data['username'] as String?,
              photoUrl: data['photoUrl'] as String?,
            ),
          );
        } catch (error) {
          debugPrint(
            '[KudosService] glazer profile skipped activityId=$activityId '
            'userId=$userId error=$error',
          );
        }
      }
      return glazers;
    });
  }

  Future<void> toggleKudos({
    required String activityId,
    required String activityOwnerId,
    required String userId,
  }) async {
    final ref = _kudos(activityId).doc(userId);
    final activityRef = _firestore.collection('activities').doc(activityId);
    DateTime? createdAt;
    String resolvedOwnerId = activityOwnerId;
    await _firestore.runTransaction<void>((transaction) async {
      final activityDoc = await transaction.get(activityRef);
      final existing = await transaction.get(ref);
      if (!activityDoc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message:
              'Cannot toggle Kudos because activities/$activityId is missing.',
        );
      }
      final data = activityDoc.data();
      final ownerId = data?['ownerId'];
      final profileId = data?['profileId'];
      if (ownerId is String && ownerId.isNotEmpty) {
        resolvedOwnerId = ownerId;
      } else if (profileId is String && profileId.isNotEmpty) {
        resolvedOwnerId = profileId;
      } else {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message:
              'Cannot toggle Kudos because activities/$activityId has no ownerId.',
        );
      }
      if (userId == resolvedOwnerId) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Activity owners cannot Glaze their own activity.',
        );
      }
      if (existing.exists) {
        debugPrint(
          '[KudosService] remove kudos activityId=$activityId '
          'ownerId=$resolvedOwnerId userId=$userId',
        );
        transaction.delete(ref);
        return;
      }
      final now = DateTime.now();
      createdAt = now;
      debugPrint(
        '[KudosService] give kudos activityId=$activityId '
        'ownerId=$resolvedOwnerId userId=$userId',
      );
      transaction.set(ref, <String, dynamic>{
        'activityId': activityId,
        'activityOwnerId': resolvedOwnerId,
        'userId': userId,
        'createdAt': now.toIso8601String(),
      });
    });

    final notificationCreatedAt = createdAt;
    if (notificationCreatedAt != null && userId != resolvedOwnerId) {
      await _tryCreateKudosNotification(
        activityId: activityId,
        recipientId: resolvedOwnerId,
        actorId: userId,
        createdAt: notificationCreatedAt,
      );
    }
  }

  Future<void> _tryCreateKudosNotification({
    required String activityId,
    required String recipientId,
    required String actorId,
    required DateTime createdAt,
  }) async {
    final notification = SocialNotification(
      id: SocialNotification.activityKudosNotificationIdFor(
        activityId: activityId,
        actorId: actorId,
      ),
      recipientId: recipientId,
      actorId: actorId,
      type: SocialNotificationType.activityKudos,
      createdAt: createdAt,
      activityId: activityId,
    );
    try {
      await _firestore
          .collection('profiles')
          .doc(recipientId)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap(), SetOptions(merge: true));
    } catch (error) {
      final code = error is FirebaseException ? error.code : 'unknown';
      debugPrint(
        '[KudosService] notification write failed activityId=$activityId '
        'recipientId=$recipientId actorId=$actorId code=$code error=$error',
      );
    }
  }
}
