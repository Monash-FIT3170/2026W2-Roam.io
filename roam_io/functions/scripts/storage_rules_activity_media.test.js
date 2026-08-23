/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026 — Sanjevan Rajasegar
 * Description:
 *   Storage rules tests for activity_media owner pre-activity download URLs,
 *   profile visibility reads, and owner-only mutation enforcement.
 */

const fs = require('node:fs');
const path = require('node:path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  deleteObject,
  getDownloadURL,
  ref,
  uploadString,
} = require('firebase/storage');

const projectId = 'roam-io-71e2c';
const firestoreRules = fs.readFileSync(
  path.resolve(__dirname, '../../firestore.rules'),
  'utf8',
);
const storageRules = fs.readFileSync(
  path.resolve(__dirname, '../../storage.rules'),
  'utf8',
);

function followId(followerId, followeeId) {
  return `${followerId}_${followeeId}`;
}

async function seedVisibility(testEnv) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('public_profiles').doc('owner').set({
      uid: 'owner',
      username: 'owner',
      usernameSearch: 'owner',
      displayName: 'Owner',
      displayNameSearch: 'owner',
      xp: 10,
      level: 1,
      isPrivateAccount: false,
      createdAt: '2026-08-22T00:00:00.000Z',
      updatedAt: '2026-08-22T00:00:00.000Z',
    });
    await db.collection('public_profiles').doc('privateOwner').set({
      uid: 'privateOwner',
      username: 'private',
      usernameSearch: 'private',
      displayName: 'Private',
      displayNameSearch: 'private',
      xp: 10,
      level: 1,
      isPrivateAccount: true,
      createdAt: '2026-08-22T00:00:00.000Z',
      updatedAt: '2026-08-22T00:00:00.000Z',
    });
    await db.collection('activities').doc('activity-public').set({
      activityId: 'activity-public',
      ownerId: 'owner',
      profileId: 'owner',
      displayName: 'Owner',
      username: 'owner',
      title: 'Public activity',
      kind: 'journey',
      metrics: [],
      media: [],
      createdAt: '2026-08-22T00:00:00.000Z',
    });
    await db.collection('activities').doc('activity-private').set({
      activityId: 'activity-private',
      ownerId: 'privateOwner',
      profileId: 'privateOwner',
      displayName: 'Private',
      username: 'private',
      title: 'Private activity',
      kind: 'journey',
      metrics: [],
      media: [],
      createdAt: '2026-08-22T00:00:00.000Z',
    });
    await db.collection('follows').doc(followId('follower', 'privateOwner')).set({
      followerId: 'follower',
      followeeId: 'privateOwner',
      createdAt: '2026-08-22T00:00:00.000Z',
    });
  });
}

async function run() {
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules: firestoreRules },
    storage: { rules: storageRules },
  });

  try {
    await seedVisibility(testEnv);

    const ownerStorage = testEnv.authenticatedContext('owner').storage();
    const viewerStorage = testEnv.authenticatedContext('viewer').storage();
    const followerStorage = testEnv.authenticatedContext('follower').storage();
    const privateOwnerStorage = testEnv
      .authenticatedContext('privateOwner')
      .storage();

    const pendingPath = 'activity_media/owner/activity-pending/media.jpg';
    const pendingRef = ref(ownerStorage, pendingPath);
    await assertSucceeds(uploadString(pendingRef, 'image-bytes'));
    await assertSucceeds(getDownloadURL(pendingRef));
    await assertFails(getDownloadURL(ref(viewerStorage, pendingPath)));

    const publicPath = 'activity_media/owner/activity-public/media.jpg';
    await assertSucceeds(uploadString(ref(ownerStorage, publicPath), 'public'));
    await assertSucceeds(getDownloadURL(ref(viewerStorage, publicPath)));

    const privatePath = 'activity_media/privateOwner/activity-private/media.jpg';
    await assertSucceeds(
      uploadString(ref(privateOwnerStorage, privatePath), 'private'),
    );
    await assertFails(getDownloadURL(ref(viewerStorage, privatePath)));
    await assertSucceeds(getDownloadURL(ref(followerStorage, privatePath)));

    await assertFails(
      uploadString(ref(viewerStorage, publicPath), 'overwrite-attempt'),
    );
    await assertFails(deleteObject(ref(viewerStorage, publicPath)));
    await assertSucceeds(deleteObject(ref(ownerStorage, publicPath)));

    console.log('passed: activity_media storage rules');
  } finally {
    await testEnv.cleanup();
  }
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
