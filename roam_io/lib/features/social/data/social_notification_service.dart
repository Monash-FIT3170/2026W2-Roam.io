/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Firestore-backed social inbox under profiles/{uid}/notifications.
 *   Follow notification documents are created after follow persistence
 *   (client best-effort + Cloud Function when deployed) with deterministic
 *   relationship-state IDs. Clients read, watch unread state, and mark readAt.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/social_notification.dart';

/// One emit from [SocialNotificationService.watchRecentSnapshots].
class SocialNotificationRecentSnapshot {
  const SocialNotificationRecentSnapshot({
    required this.items,
    required this.isFromCache,
  });

  final List<SocialNotification> items;
  final bool isFromCache;
}

/// Owns persistent social inbox reads and read-state updates.
class SocialNotificationService {
  SocialNotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String notificationsSubcollection = 'notifications';
  static const int defaultRecentLimit = 50;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _notifications(String uid) {
    return _firestore
        .collection('profiles')
        .doc(uid)
        .collection(notificationsSubcollection);
  }

  /// Recent notifications for [uid], newest first, with cache metadata.
  Stream<SocialNotificationRecentSnapshot> watchRecentSnapshots(
    String uid, {
    int limit = defaultRecentLimit,
  }) {
    return _notifications(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final items = <SocialNotification>[];
          for (final doc in snapshot.docs) {
            try {
              items.add(SocialNotification.fromMap(doc.id, doc.data()));
            } catch (error, stackTrace) {
              debugPrint(
                '[SocialNotificationService] skip notification '
                'uid=$uid notificationId=${doc.id} type=${doc.data()['type']} '
                'error=$error\n$stackTrace',
              );
            }
          }
          return SocialNotificationRecentSnapshot(
            items: items,
            isFromCache: snapshot.metadata.isFromCache,
          );
        });
  }

  /// Recent notifications for [uid], newest first.
  Stream<List<SocialNotification>> watchRecent(
    String uid, {
    int limit = defaultRecentLimit,
  }) {
    return watchRecentSnapshots(
      uid,
      limit: limit,
    ).map((snapshot) => snapshot.items);
  }

  /// Unread social notifications for cold-start summary (newest first).
  Stream<List<SocialNotification>> watchUnreadSocialNotifications(
    String uid, {
    int limit = defaultRecentLimit,
  }) {
    return watchRecent(uid, limit: limit).map(
      (items) => items.where((item) => !item.isRead).toList(growable: false),
    );
  }

  /// Count of unread notifications for badge surfaces.
  Stream<int> watchUnreadCount(String uid) {
    return watchRecent(
      uid,
    ).map((items) => items.where((item) => !item.isRead).length);
  }

  /// Marks currently unread notifications as read. Does not delete rows.
  Future<void> markAllRead(String uid) async {
    final snapshot = await _notifications(
      uid,
    ).orderBy('createdAt', descending: true).limit(defaultRecentLimit).get();
    final now = DateTime.now().toIso8601String();
    final batch = _firestore.batch();
    var writes = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['readAt'] != null) continue;
      batch.update(doc.reference, <String, dynamic>{'readAt': now});
      writes += 1;
    }
    if (writes == 0) return;
    await batch.commit();
  }

  /// Test/admin helper: writes a follow notification document directly.
  ///
  /// Production creation is owned by FollowService client write and/or the
  /// Cloud Function on follows create.
  Future<void> upsertFollowNotificationForTests({
    required String recipientId,
    required String actorId,
    required String notificationId,
    DateTime? createdAt,
    DateTime? readAt,
  }) async {
    final notification = SocialNotification(
      id: notificationId,
      recipientId: recipientId,
      actorId: actorId,
      type: SocialNotificationType.follow,
      createdAt: createdAt ?? DateTime.now(),
      readAt: readAt,
    );
    await _notifications(
      recipientId,
    ).doc(notificationId).set(notification.toMap());
  }

  /// Test/admin helper for follow request notifications.
  Future<void> upsertNotificationForTests(SocialNotification notification) {
    return _notifications(
      notification.recipientId,
    ).doc(notification.id).set(notification.toMap());
  }
}
