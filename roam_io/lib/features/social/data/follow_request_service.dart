/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Firestore-backed private-account follow request lifecycle. Requests live
 *   at follow_requests/{requesterId_targetId}; acceptance creates the normal
 *   one-way follows/{requesterId_targetId} relationship and then removes the
 *   pending request. Decline/cancel/unfollow are silent.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/follow.dart';
import '../domain/follow_request.dart';
import '../domain/social_notification.dart';
import 'follow_service.dart';

/// Owns private-account follow request transitions.
class FollowRequestService {
  FollowRequestService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String followRequestsCollection = 'follow_requests';
  static const String acceptedFollowSource = 'follow_request_acceptance';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection(followRequestsCollection);

  CollectionReference<Map<String, dynamic>> get _follows =>
      _firestore.collection(FollowService.followsCollection);

  /// Deterministic document ID for "requester requests target".
  static String requestIdFor(String requesterId, String targetId) {
    return '${requesterId}_$targetId';
  }

  static String requestNotificationIdFor(String requesterId, String targetId) {
    return 'follow_request_${requestIdFor(requesterId, targetId)}';
  }

  static String acceptanceNotificationIdFor(
    String targetId,
    String requesterId,
  ) {
    return 'follow_request_accepted_${targetId}_$requesterId';
  }

  Stream<FollowRequest?> watchPendingBetween({
    required String requesterId,
    required String targetId,
  }) {
    if (requesterId == targetId) {
      return Stream<FollowRequest?>.value(null);
    }
    return _requests.doc(requestIdFor(requesterId, targetId)).snapshots().map((
      doc,
    ) {
      final data = doc.data();
      if (data == null) return null;
      final request = FollowRequest.fromMap(doc.id, data);
      return request.isPending ? request : null;
    });
  }

  Stream<List<FollowRequest>> watchIncomingFollowRequests(String uid) {
    return _requests
        .where('targetId', isEqualTo: uid)
        .where('status', isEqualTo: FollowRequestStatus.pending.wireValue)
        .snapshots()
        .map(_requestsFromSnapshot);
  }

  Stream<List<FollowRequest>> watchOutgoingFollowRequests(String uid) {
    return _requests
        .where('requesterId', isEqualTo: uid)
        .where('status', isEqualTo: FollowRequestStatus.pending.wireValue)
        .snapshots()
        .map(_requestsFromSnapshot);
  }

  Future<void> sendFollowRequest({
    required String requesterId,
    required String targetId,
  }) async {
    if (requesterId == targetId) return;
    final requestId = requestIdFor(requesterId, targetId);
    final requestRef = _requests.doc(requestId);
    final followRef = _follows.doc(
      FollowService.followIdFor(requesterId, targetId),
    );
    final publicProfileRef = _firestore
        .collection('public_profiles')
        .doc(targetId);
    final now = DateTime.now();

    var didCreate = false;
    await _firestore.runTransaction<void>((transaction) async {
      final targetDoc = await transaction.get(publicProfileRef);
      final targetData = targetDoc.data();
      if (targetData == null) {
        throw StateError('Target profile does not exist.');
      }
      final isPrivate = targetData['isPrivateAccount'] as bool? ?? false;
      if (!isPrivate) {
        throw StateError('Target profile is no longer private.');
      }

      final followDoc = await transaction.get(followRef);
      if (followDoc.exists) return;

      final requestDoc = await transaction.get(requestRef);
      final requestData = requestDoc.data();
      if (requestData != null) {
        final existing = FollowRequest.fromMap(requestDoc.id, requestData);
        if (existing.isPending) return;
      }

      transaction.set(
        requestRef,
        FollowRequest(
          id: requestId,
          requesterId: requesterId,
          targetId: targetId,
          status: FollowRequestStatus.pending,
          createdAt: now,
          updatedAt: now,
        ).toMap(),
      );
      didCreate = true;
    });

    if (didCreate) {
      await _tryCreateRequestNotification(
        requesterId: requesterId,
        targetId: targetId,
        createdAt: now,
      );
    }
  }

  Future<void> cancelFollowRequest({
    required String requesterId,
    required String targetId,
  }) async {
    if (requesterId == targetId) return;
    final requestRef = _requests.doc(requestIdFor(requesterId, targetId));
    await _firestore.runTransaction<void>((transaction) async {
      final requestDoc = await transaction.get(requestRef);
      final data = requestDoc.data();
      if (data == null) return;
      final request = FollowRequest.fromMap(requestDoc.id, data);
      if (request.requesterId != requesterId || request.targetId != targetId) {
        throw StateError('Cannot cancel a malformed follow request.');
      }
      if (!request.isPending) return;
      transaction.delete(requestRef);
    });
  }

  Future<void> acceptFollowRequest({
    required String requestId,
    required String currentUserId,
  }) async {
    final requestRef = _requests.doc(requestId);
    FollowRequest? acceptedRequest;
    final now = DateTime.now();

    await _firestore.runTransaction<void>((transaction) async {
      final requestDoc = await transaction.get(requestRef);
      final data = requestDoc.data();
      if (data == null) {
        throw StateError('Follow request no longer exists.');
      }

      final request = FollowRequest.fromMap(requestDoc.id, data);
      if (request.targetId != currentUserId) {
        throw StateError('Only the target can accept this follow request.');
      }
      if (!request.isPending) {
        throw StateError('Follow request is no longer pending.');
      }

      final followId = FollowService.followIdFor(
        request.requesterId,
        request.targetId,
      );
      final followRef = _follows.doc(followId);
      final followDoc = await transaction.get(followRef);
      if (!followDoc.exists) {
        transaction.set(
          followRef,
          Follow(
            id: followId,
            followerId: request.requesterId,
            followeeId: request.targetId,
            createdAt: now,
            source: acceptedFollowSource,
            acceptedRequestId: request.id,
          ).toMap(),
        );
      }
      transaction.delete(requestRef);
      acceptedRequest = request;
    });

    final request = acceptedRequest;
    if (request != null) {
      await _tryCreateAcceptanceNotification(
        requesterId: request.requesterId,
        targetId: request.targetId,
        createdAt: now,
      );
    }
  }

  Future<void> declineFollowRequest({
    required String requestId,
    required String currentUserId,
  }) async {
    final requestRef = _requests.doc(requestId);
    await _firestore.runTransaction<void>((transaction) async {
      final requestDoc = await transaction.get(requestRef);
      final data = requestDoc.data();
      if (data == null) return;
      final request = FollowRequest.fromMap(requestDoc.id, data);
      if (request.targetId != currentUserId) {
        throw StateError('Only the target can decline this follow request.');
      }
      if (!request.isPending) return;
      transaction.delete(requestRef);
    });
  }

  List<FollowRequest> _requestsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final requests = snapshot.docs
        .map((doc) => FollowRequest.fromMap(doc.id, doc.data()))
        .where((request) => request.isPending)
        .toList();
    requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return requests;
  }

  Future<void> _tryCreateRequestNotification({
    required String requesterId,
    required String targetId,
    required DateTime createdAt,
  }) async {
    final id = requestNotificationIdFor(requesterId, targetId);
    final notification = SocialNotification(
      id: id,
      recipientId: targetId,
      actorId: requesterId,
      type: SocialNotificationType.followRequest,
      createdAt: createdAt,
    );
    await _tryWriteNotification(
      recipientId: targetId,
      notificationId: id,
      notification: notification,
      context: 'request',
    );
  }

  Future<void> _tryCreateAcceptanceNotification({
    required String requesterId,
    required String targetId,
    required DateTime createdAt,
  }) async {
    final id = acceptanceNotificationIdFor(targetId, requesterId);
    final notification = SocialNotification(
      id: id,
      recipientId: requesterId,
      actorId: targetId,
      type: SocialNotificationType.followRequestAccepted,
      createdAt: createdAt,
    );
    await _tryWriteNotification(
      recipientId: requesterId,
      notificationId: id,
      notification: notification,
      context: 'acceptance',
    );
  }

  Future<void> _tryWriteNotification({
    required String recipientId,
    required String notificationId,
    required SocialNotification notification,
    required String context,
  }) async {
    try {
      await _firestore
          .collection('profiles')
          .doc(recipientId)
          .collection('notifications')
          .doc(notificationId)
          .set(notification.toMap(), SetOptions(merge: true));
    } catch (error) {
      final code = error is FirebaseException ? error.code : 'unknown';
      debugPrint(
        '[FollowRequestService] notification write failed context=$context '
        'recipientId=$recipientId actorId=${notification.actorId} '
        'code=$code error=$error',
      );
    }
  }
}
