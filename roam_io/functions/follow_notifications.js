/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Creates a persistent follow inbox notification when a follows document is
 *   created. Doc ID matches the follow ID for idempotent retries.
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
