/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Firestore rules tests for public profile dashboard reads and follow writes.
 */

const fs = require('node:fs');
const path = require('node:path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const projectId = 'roam-io-71e2c';
const rules = fs.readFileSync(
  path.resolve(__dirname, '../../firestore.rules'),
  'utf8',
);

function followId(followerId, followeeId) {
  return `${followerId}_${followeeId}`;
}

async function seed(testEnv) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('profiles').doc('owner').set({
      uid: 'owner',
      username: 'owner',
      displayName: 'Owner',
      email: 'private@example.com',
      darkModeEnabled: true,
      xp: 10,
      level: 1,
    });
    await db.collection('public_profiles').doc('owner').set({
      uid: 'owner',
      username: 'owner',
      usernameSearch: 'owner',
      displayName: 'Owner',
      displayNameSearch: 'owner',
      xp: 10,
      level: 1,
      createdAt: '2026-08-07T00:00:00.000Z',
      updatedAt: '2026-08-07T00:00:00.000Z',
    });
    await db.collection('profiles').doc('owner').collection('visits').doc('1').set({
      placeId: 1,
      placeName: 'Campus',
      googlePlaceId: 'g-1',
      regionId: 'r-1',
      category: 'study',
      visitedAt: new Date('2026-08-07T00:00:00.000Z'),
    });
    await db
      .collection('profiles')
      .doc('owner')
      .collection('xp_events')
      .doc('xp-1')
      .set({
        amount: 50,
        earnedAt: new Date('2026-08-07T00:00:00.000Z'),
        source: 'visit',
      });
    await db.collection('polygons_visited').doc('owner').set({
      profile_id: 'owner',
      user_id: 'owner',
      visited_polygons: {
        'tile-1': new Date('2026-08-07T00:00:00.000Z'),
      },
    });
    await db.collection('activities').doc('activity-1').set({
      profileId: 'owner',
      displayName: 'Owner',
      username: 'owner',
      title: 'Campus walk',
      kind: 'exploration',
      metrics: [{ label: 'XP Gained', value: '+50 XP' }],
      createdAt: '2026-08-07T00:00:00.000Z',
    });
  });
}

async function assertActivityReads(assertion, db) {
  await assertion(db.collection('public_profiles').doc('owner').get());
  await assertion(db.collection('profiles').doc('owner').collection('visits').doc('1').get());
  await assertion(
    db.collection('profiles').doc('owner').collection('xp_events').doc('xp-1').get(),
  );
  await assertion(db.collection('polygons_visited').doc('owner').get());
  await assertion(db.collection('activities').doc('activity-1').get());
}

async function runScenario(name, uid, assertion) {
  const testEnv = await initializeTestEnvironment({ projectId, firestore: { rules } });
  try {
    await seed(testEnv);
    const db = uid ? testEnv.authenticatedContext(uid).firestore() : testEnv.unauthenticatedContext().firestore();
    await assertActivityReads(assertion, db);
    if (uid === 'owner') {
      await assertSucceeds(db.collection('profiles').doc('owner').get());
    } else {
      await assertFails(db.collection('profiles').doc('owner').get());
    }
    console.log(`passed: ${name}`);
  } finally {
    await testEnv.cleanup();
  }
}

async function runFollowWriteTests() {
  const testEnv = await initializeTestEnvironment({ projectId, firestore: { rules } });
  try {
    await seed(testEnv);
    const followerDb = testEnv.authenticatedContext('follower').firestore();
    const otherDb = testEnv.authenticatedContext('other').firestore();
    const anonDb = testEnv.unauthenticatedContext().firestore();

    await assertSucceeds(
      followerDb.collection('follows').doc(followId('follower', 'owner')).set({
        followerId: 'follower',
        followeeId: 'owner',
        createdAt: '2026-08-07T00:00:00.000Z',
      }),
    );
    await assertSucceeds(
      followerDb.collection('follows').doc(followId('follower', 'owner')).get(),
    );
    await assertFails(
      followerDb.collection('follows').doc(followId('follower', 'follower')).set({
        followerId: 'follower',
        followeeId: 'follower',
        createdAt: '2026-08-07T00:00:00.000Z',
      }),
    );
    await assertFails(
      otherDb.collection('follows').doc(followId('follower', 'other')).set({
        followerId: 'follower',
        followeeId: 'other',
        createdAt: '2026-08-07T00:00:00.000Z',
      }),
    );
    await assertFails(
      followerDb.collection('follows').doc('not-deterministic').set({
        followerId: 'follower',
        followeeId: 'owner',
        createdAt: '2026-08-07T00:00:00.000Z',
      }),
    );
    await assertFails(
      followerDb.collection('follows').doc(followId('follower', 'owner')).update({
        followeeId: 'other',
      }),
    );
    await assertFails(
      otherDb.collection('follows').doc(followId('follower', 'owner')).delete(),
    );
    await assertFails(
      anonDb.collection('follows').doc(followId('anon', 'owner')).set({
        followerId: 'anon',
        followeeId: 'owner',
        createdAt: '2026-08-07T00:00:00.000Z',
      }),
    );
    await assertSucceeds(
      followerDb.collection('follows').doc(followId('follower', 'owner')).delete(),
    );
    console.log('passed: follow write rules');
  } finally {
    await testEnv.cleanup();
  }
}

(async () => {
  await runScenario('owner public dashboard reads', 'owner', assertSucceeds);
  await runScenario('authenticated public dashboard reads', 'viewer', assertSucceeds);
  await runScenario('unauthenticated public dashboard denied', null, assertFails);
  await runFollowWriteTests();
  console.log('firestore public profile and follow rules passed');
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
