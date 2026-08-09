/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Firestore-backed private-account follow request lifecycle. Requests live
 *   at follow_requests/{requesterId_targetId}; acceptance creates the normal
 *   one-way follows/{requesterId_targetId} relationship and then removes the
 *   pending request. Request notifications represent current state.
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
    final requestPath = '$followRequestsCollection/$requestId';
    final requestRef = _requests.doc(requestId);
    final followRef = _follows.doc(
      FollowService.followIdFor(requesterId, targetId),
    );
    final publicProfileRef = _firestore
        .collection('public_profiles')
        .doc(targetId);
    final now = DateTime.now();

    var didCreate = false;
    try {
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

        final request = FollowRequest(
          id: requestId,
          requesterId: requesterId,
          targetId: targetId,
          status: FollowRequestStatus.pending,
          createdAt: now,
          updatedAt: now,
        );
        transaction.set(requestRef, request.toMap());
        didCreate = true;
      });
    } on FirebaseException catch (error) {
      debugPrint(
        '[FollowRequestService] sendFollowRequest failed '
        'plugin=${error.plugin} code=${error.code} '
        'message=${error.message} path=$requestPath '
        'requesterId=$requesterId targetId=$targetId '
        'schema={requesterId:string,targetId:string,status:pending,'
        'createdAt:isoString,updatedAt:isoString} error=$error',
      );
      rethrow;
    }

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
    await _tryDeleteRequestNotification(
      requesterId: requesterId,
      targetId: targetId,
      context: 'cancel',
    );
  }

  Future<void> acceptFollowRequest({
    required String requestId,
    required String currentUserId,
  }) async {
    final requestRef = _requests.doc(requestId);
    FollowRequest? acceptedRequest;
    final now = DateTime.now();
    var operation = 'request_lookup';
    var path = '$followRequestsCollection/$requestId';
    String? requesterId;
    String? targetId;

    try {
      await _firestore.runTransaction<void>((transaction) async {
        operation = 'request_lookup';
        path = '$followRequestsCollection/$requestId';
        final requestDoc = await transaction.get(requestRef);
        final data = requestDoc.data();
        if (data == null) {
          throw StateError('Follow request no longer exists.');
        }

        final request = FollowRequest.fromMap(requestDoc.id, data);
        requesterId = request.requesterId;
        targetId = request.targetId;
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
        operation = 'follow_lookup';
        path = '${FollowService.followsCollection}/$followId';
        final followDoc = await transaction.get(followRef);
        if (!followDoc.exists) {
          operation = 'follow_create';
          path = '${FollowService.followsCollection}/$followId';
          transaction.set(
            followRef,
            Follow(
              id: followId,
              followerId: request.requesterId,
              followeeId: request.targetId,
              createdAt: now,
              source: acceptedFollowSource,
              acceptedRequestId: request.id,
              acceptedRequestCreatedAt: request.createdAt,
            ).toMap(),
          );
        }
        operation = 'request_delete';
        path = '$followRequestsCollection/$requestId';
        transaction.delete(requestRef);
        acceptedRequest = request;
      });
    } on FirebaseException catch (error) {
      _logFirebaseFailure(
        action: 'acceptFollowRequest',
        operation: operation,
        path: path,
        requestId: requestId,
        requesterId: requesterId,
        targetId: targetId ?? currentUserId,
        error: error,
      );
      rethrow;
    }

    final request = acceptedRequest;
    if (request != null) {
      await _tryReplaceRequestNotificationWithFollow(
        request: request,
        createdAt: now,
      );
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
    var operation = 'request_lookup';
    var path = '$followRequestsCollection/$requestId';
    String? requesterId;
    String? targetId;

    try {
      await _firestore.runTransaction<void>((transaction) async {
        operation = 'request_lookup';
        path = '$followRequestsCollection/$requestId';
        final requestDoc = await transaction.get(requestRef);
        final data = requestDoc.data();
        if (data == null) return;
        final request = FollowRequest.fromMap(requestDoc.id, data);
        requesterId = request.requesterId;
        targetId = request.targetId;
        if (request.targetId != currentUserId) {
          throw StateError('Only the target can decline this follow request.');
        }
        if (!request.isPending) return;
        operation = 'request_delete';
        path = '$followRequestsCollection/$requestId';
        transaction.delete(requestRef);
      });
    } on FirebaseException catch (error) {
      _logFirebaseFailure(
        action: 'declineFollowRequest',
        operation: operation,
        path: path,
        requestId: requestId,
        requesterId: requesterId,
        targetId: targetId ?? currentUserId,
        error: error,
      );
      rethrow;
    }
    final resolvedRequesterId = requesterId;
    final resolvedTargetId = targetId;
    if (resolvedRequesterId != null && resolvedTargetId != null) {
      await _tryDeleteRequestNotification(
        requesterId: resolvedRequesterId,
        targetId: resolvedTargetId,
        context: 'decline',
      );
    }
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

  Future<void> _tryReplaceRequestNotificationWithFollow({
    required FollowRequest request,
    required DateTime createdAt,
  }) async {
    await _tryDeleteRequestNotification(
      requesterId: request.requesterId,
      targetId: request.targetId,
      context: 'accept',
    );
    final id = SocialNotification.followNotificationIdFor(
      followerId: request.requesterId,
      followeeId: request.targetId,
    );
    final notification = SocialNotification(
      id: id,
      recipientId: request.targetId,
      actorId: request.requesterId,
      type: SocialNotificationType.follow,
      createdAt: createdAt,
    );
    await _tryWriteNotification(
      recipientId: request.targetId,
      notificationId: id,
      notification: notification,
      context: 'accepted-follow',
    );
  }

  Future<void> _tryDeleteRequestNotification({
    required String requesterId,
    required String targetId,
    required String context,
  }) async {
    final id = requestNotificationIdFor(requesterId, targetId);
    try {
      await _firestore
          .collection('profiles')
          .doc(targetId)
          .collection('notifications')
          .doc(id)
          .delete();
    } on FirebaseException catch (error) {
      debugPrint(
        '[FollowRequestService] request notification cleanup failed '
        'context=$context operation=notification_delete '
        'path=profiles/$targetId/notifications/$id '
        'requesterId=$requesterId targetId=$targetId '
        'plugin=${error.plugin} code=${error.code} '
        'message=${error.message} error=$error',
      );
    } catch (error) {
      debugPrint(
        '[FollowRequestService] request notification cleanup failed '
        'context=$context operation=notification_delete '
        'path=profiles/$targetId/notifications/$id '
        'requesterId=$requesterId targetId=$targetId '
        'code=unknown error=$error',
      );
    }
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
    } on FirebaseException catch (error) {
      debugPrint(
        '[FollowRequestService] notification write failed context=$context '
        'operation=notification_write path=profiles/$recipientId/'
        'notifications/$notificationId '
        'recipientId=$recipientId actorId=${notification.actorId} '
        'plugin=${error.plugin} code=${error.code} '
        'message=${error.message} error=$error',
      );
    } catch (error) {
      debugPrint(
        '[FollowRequestService] notification write failed context=$context '
        'operation=notification_write path=profiles/$recipientId/'
        'notifications/$notificationId '
        'recipientId=$recipientId actorId=${notification.actorId} '
        'code=unknown error=$error',
      );
    }
  }

  void _logFirebaseFailure({
    required String action,
    required String operation,
    required String path,
    required String requestId,
    required String? requesterId,
    required String? targetId,
    required FirebaseException error,
  }) {
    debugPrint(
      '[FollowRequestService] $action failed operation=$operation '
      'path=$path requestId=$requestId requesterId=$requesterId '
      'targetId=$targetId plugin=${error.plugin} code=${error.code} '
      'message=${error.message} error=$error',
    );
  }
}
