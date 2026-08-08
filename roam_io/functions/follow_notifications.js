/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Creates persistent social inbox notifications for immediate follows,
 *   private follow requests, and request acceptance. Accepted private requests
 *   skip the target-side "followed you" notification because the target
 *   initiated the approval.
 */

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

if (getApps().length === 0) {
  initializeApp();
}

/**
 * On follows/{followId} create, write
 * profiles/{followeeId}/notifications/{followId}.
 */
exports.onFollowCreated = onDocumentCreated(
  {
    document: 'follows/{followId}',
    region: 'australia-southeast1',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.warn('[FollowNotif] missing snapshot');
      return;
    }

    const followId = event.params.followId;
    const data = snap.data() || {};
    const followerId = data.followerId;
    const followeeId = data.followeeId;

    if (
      typeof followerId !== 'string' ||
      typeof followeeId !== 'string' ||
      !followerId ||
      !followeeId ||
      followerId === followeeId
    ) {
      console.warn('[FollowNotif] invalid follow payload', { followId, data });
      return;
    }

    if (data.source === 'follow_request_acceptance') {
      console.log('[FollowNotif] skip accepted request follow notification', {
        followId,
        followeeId,
        followerId,
      });
      return;
    }

    const expectedId = `${followerId}_${followeeId}`;
    if (followId !== expectedId) {
      console.warn('[FollowNotif] followId mismatch', { followId, expectedId });
      return;
    }

    const createdAt =
      typeof data.createdAt === 'string' && data.createdAt.length > 0
        ? data.createdAt
        : new Date().toISOString();

    try {
      await getFirestore()
        .collection('profiles')
        .doc(followeeId)
        .collection('notifications')
        .doc(followId)
        .set(
          {
            recipientId: followeeId,
            actorId: followerId,
            type: 'follow',
            createdAt,
            readAt: null,
          },
          { merge: true },
        );
      console.log('[FollowNotif] wrote notification', {
        followId,
        followeeId,
        followerId,
      });
    } catch (error) {
      // Never fail the follow relationship; log only.
      console.error('[FollowNotif] failed to write notification', {
        followId,
        error: error && error.message ? error.message : String(error),
      });
    }
  },
);

/**
 * On follow_requests/{requestId} create, write a request notification for the
 * private target. Doc ID is deterministic for idempotent retries.
 */
exports.onFollowRequestCreated = onDocumentCreated(
  {
    document: 'follow_requests/{requestId}',
    region: 'australia-southeast1',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const requestId = event.params.requestId;
    const data = snap.data() || {};
    const requesterId = data.requesterId;
    const targetId = data.targetId;
    if (
      typeof requesterId !== 'string' ||
      typeof targetId !== 'string' ||
      !requesterId ||
      !targetId ||
      requesterId === targetId ||
      requestId !== `${requesterId}_${targetId}`
    ) {
      console.warn('[FollowRequestNotif] invalid request payload', {
        requestId,
        data,
      });
      return;
    }

    const createdAt =
      typeof data.createdAt === 'string' && data.createdAt.length > 0
        ? data.createdAt
        : new Date().toISOString();

    try {
      await getFirestore()
        .collection('profiles')
        .doc(targetId)
        .collection('notifications')
        .doc(`follow_request_${requestId}`)
        .set(
          {
            recipientId: targetId,
            actorId: requesterId,
            type: 'followRequest',
            createdAt,
            readAt: null,
          },
          { merge: true },
        );
      console.log('[FollowRequestNotif] wrote notification', {
        requestId,
        targetId,
        requesterId,
      });
    } catch (error) {
      console.error('[FollowRequestNotif] failed to write notification', {
        requestId,
        error: error && error.message ? error.message : String(error),
      });
    }
  },
);

/**
 * On follows/{followId} create from request acceptance, write an acceptance
 * notification to the requester.
 */
exports.onFollowRequestAccepted = onDocumentCreated(
  {
    document: 'follows/{followId}',
    region: 'australia-southeast1',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const followId = event.params.followId;
    const data = snap.data() || {};
    if (data.source !== 'follow_request_acceptance') return;

    const requesterId = data.followerId;
    const targetId = data.followeeId;
    if (
      typeof requesterId !== 'string' ||
      typeof targetId !== 'string' ||
      !requesterId ||
      !targetId ||
      requesterId === targetId ||
      followId !== `${requesterId}_${targetId}`
    ) {
      console.warn('[FollowAcceptNotif] invalid follow payload', {
        followId,
        data,
      });
      return;
    }

    const createdAt =
      typeof data.createdAt === 'string' && data.createdAt.length > 0
        ? data.createdAt
        : new Date().toISOString();

    try {
      await getFirestore()
        .collection('profiles')
        .doc(requesterId)
        .collection('notifications')
        .doc(`follow_request_accepted_${targetId}_${requesterId}`)
        .set(
          {
            recipientId: requesterId,
            actorId: targetId,
            type: 'followRequestAccepted',
            createdAt,
            readAt: null,
          },
          { merge: true },
        );
      console.log('[FollowAcceptNotif] wrote notification', {
        followId,
        requesterId,
        targetId,
      });
    } catch (error) {
      console.error('[FollowAcceptNotif] failed to write notification', {
        followId,
        error: error && error.message ? error.message : String(error),
      });
    }
  },
);
