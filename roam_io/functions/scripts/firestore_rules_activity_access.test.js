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

function followNotificationId(followerId, followeeId) {
  return `follow_${followerId}_${followeeId}`;
}

function followRequestNotificationId(requesterId, targetId) {
  return `follow_request_${requesterId}_${targetId}`;
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
      isPrivateAccount: false,
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
    // Clear existing follow so followee Remove can be exercised on a fresh doc.
    await assertSucceeds(
      followerDb.collection('follows').doc(followId('follower', 'owner')).delete(),
    );
    await assertSucceeds(
      followerDb.collection('follows').doc(followId('follower', 'owner')).set({
        followerId: 'follower',
        followeeId: 'owner',
        createdAt: '2026-08-07T00:00:00.000Z',
      }),
    );
    const ownerDb = testEnv.authenticatedContext('owner').firestore();
    await assertSucceeds(
      ownerDb.collection('follows').doc(followId('follower', 'owner')).delete(),
    );
    console.log('passed: follow write rules');
  } finally {
    await testEnv.cleanup();
  }
}

async function runNotificationRulesTests() {
  const testEnv = await initializeTestEnvironment({ projectId, firestore: { rules } });
  try {
    await seed(testEnv);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db
        .collection('profiles')
        .doc('owner')
        .collection('notifications')
        .doc(followNotificationId('follower', 'owner'))
        .set({
          recipientId: 'owner',
          actorId: 'follower',
          type: 'follow',
          createdAt: '2026-08-07T00:00:00.000Z',
          readAt: null,
        });
    });

    const ownerDb = testEnv.authenticatedContext('owner').firestore();
    const viewerDb = testEnv.authenticatedContext('viewer').firestore();
    const followerDb = testEnv.authenticatedContext('follower').firestore();

    await assertSucceeds(
      ownerDb
        .collection('profiles')
        .doc('owner')
        .collection('notifications')
        .doc(followNotificationId('follower', 'owner'))
        .get(),
    );
    await assertFails(
      viewerDb
        .collection('profiles')
        .doc('owner')
        .collection('notifications')
        .doc(followNotificationId('follower', 'owner'))
        .get(),
    );
    await assertFails(
      followerDb
        .collection('profiles')
        .doc('owner')
        .collection('notifications')
        .doc('new')
        .set({
          recipientId: 'owner',
          actorId: 'follower',
          type: 'follow',
          createdAt: '2026-08-07T00:00:00.000Z',
          readAt: null,
        }),
    );
    // Client may create when the matching follow exists (fresh id, not seeded).
    const actorCreateId = followId('follower', 'owner2');
    await assertSucceeds(
      followerDb.collection('follows').doc(actorCreateId).set({
        followerId: 'follower',
        followeeId: 'owner2',
        createdAt: '2026-08-07T00:00:00.000Z',
      }),
    );
    await assertSucceeds(
      followerDb
        .collection('profiles')
        .doc('owner2')
        .collection('notifications')
        .doc(followNotificationId('follower', 'owner2'))
        .set({
          recipientId: 'owner2',
          actorId: 'follower',
          type: 'follow',
          createdAt: '2026-08-07T00:00:00.000Z',
          readAt: null,
        }),
    );
    // Spoofed actorId / wrong id denied even with a follow present.
    await assertFails(
      followerDb
        .collection('profiles')
        .doc('owner2')
        .collection('notifications')
        .doc('spoof_owner2')
        .set({
          recipientId: 'owner2',
          actorId: 'spoof',
          type: 'follow',
          createdAt: '2026-08-07T00:00:00.000Z',
          readAt: null,
        }),
    );
    await assertSucceeds(
      ownerDb
        .collection('profiles')
        .doc('owner')
        .collection('notifications')
        .doc(followNotificationId('follower', 'owner'))
        .update({ readAt: '2026-08-07T01:00:00.000Z' }),
    );
    await assertFails(
      ownerDb
        .collection('profiles')
        .doc('owner')
        .collection('notifications')
        .doc(followNotificationId('follower', 'owner'))
        .update({ actorId: 'someone-else' }),
    );
    await assertFails(
      viewerDb
        .collection('profiles')
        .doc('owner2')
        .collection('notifications')
        .doc(followNotificationId('follower', 'owner2'))
        .delete(),
    );
    await assertSucceeds(
      followerDb
        .collection('profiles')
        .doc('owner2')
        .collection('notifications')
        .doc(followNotificationId('follower', 'owner2'))
        .delete(),
    );
    console.log('passed: social notification rules');
  } finally {
    await testEnv.cleanup();
  }
}

async function runPrivateAccountRulesTests() {
  const testEnv = await initializeTestEnvironment({ projectId, firestore: { rules } });
  try {
    await seed(testEnv);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('public_profiles').doc('owner').set(
        {
          isPrivateAccount: true,
          updatedAt: '2026-08-07T02:00:00.000Z',
        },
        { merge: true },
      );
      await db.collection('public_profiles').doc('public-target').set({
        uid: 'public-target',
        username: 'public_target',
        usernameSearch: 'public_target',
        displayName: 'Public Target',
        displayNameSearch: 'public target',
        isPrivateAccount: false,
        createdAt: '2026-08-07T00:00:00.000Z',
        updatedAt: '2026-08-07T02:00:00.000Z',
      });
    });

    const ownerDb = testEnv.authenticatedContext('owner').firestore();
    const viewerDb = testEnv.authenticatedContext('viewer').firestore();
    const requesterDb = testEnv.authenticatedContext('requester').firestore();
    const followerDb = testEnv.authenticatedContext('follower').firestore();
    const otherDb = testEnv.authenticatedContext('other').firestore();

    await assertSucceeds(ownerDb.collection('profiles').doc('owner').collection('visits').doc('1').get());
    await assertSucceeds(ownerDb.collection('profiles').doc('owner').collection('xp_events').doc('xp-1').get());
    await assertSucceeds(ownerDb.collection('polygons_visited').doc('owner').get());
    await assertSucceeds(ownerDb.collection('activities').doc('activity-1').get());

    await assertSucceeds(viewerDb.collection('public_profiles').doc('owner').get());
    await assertFails(viewerDb.collection('profiles').doc('owner').collection('visits').doc('1').get());
    await assertFails(viewerDb.collection('profiles').doc('owner').collection('xp_events').doc('xp-1').get());
    await assertFails(viewerDb.collection('polygons_visited').doc('owner').get());
    await assertFails(viewerDb.collection('activities').doc('activity-1').get());

    await assertFails(
      requesterDb.collection('follows').doc(followId('requester', 'owner')).set({
        followerId: 'requester',
        followeeId: 'owner',
        createdAt: '2026-08-07T02:00:00.000Z',
      }),
    );

    await assertSucceeds(
      requesterDb.collection('follow_requests').doc(followId('requester', 'owner')).get(),
    );

    await assertSucceeds(
      requesterDb.collection('follow_requests').doc(followId('requester', 'owner')).set({
        requesterId: 'requester',
        targetId: 'owner',
        status: 'pending',
        createdAt: '2026-08-07T02:00:00.000Z',
        updatedAt: '2026-08-07T02:00:00.000Z',
      }),
    );
    const requestNotificationId = followRequestNotificationId('requester', 'owner');
    await assertSucceeds(
      requesterDb
        .collection('profiles')
        .doc('owner')
        .collection('notifications')
        .doc(requestNotificationId)
        .set({
          recipientId: 'owner',
          actorId: 'requester',
          type: 'followRequest',
          createdAt: '2026-08-07T02:00:00.000Z',
          readAt: null,
        }),
    );
    await assertFails(
      requesterDb
        .collection('profiles')
        .doc('owner')
        .collection('notifications')
        .doc('follow_request_requester_owner_wrong')
        .set({
          recipientId: 'owner',
          actorId: 'requester',
          type: 'followRequest',
          createdAt: 'wrong-time',
          readAt: null,
        }),
    );
    await assertSucceeds(
      requesterDb.collection('follow_requests').doc(followId('requester', 'owner')).get(),
    );
    await assertSucceeds(
      ownerDb.collection('follow_requests').doc(followId('requester', 'owner')).get(),
    );
    await assertFails(
      otherDb.collection('follow_requests').doc(followId('requester', 'owner')).get(),
    );
    await assertFails(
      requesterDb.collection('follow_requests').doc(followId('requester', 'owner')).set({
        requesterId: 'requester',
        targetId: 'owner',
        status: 'pending',
        createdAt: '2026-08-07T02:00:00.000Z',
        updatedAt: '2026-08-07T02:00:00.000Z',
      }),
    );
    await assertFails(requesterDb.collection('profiles').doc('owner').collection('visits').doc('1').get());
    await assertFails(
      requesterDb.collection('follow_requests').doc(followId('owner', 'owner')).set({
        requesterId: 'owner',
        targetId: 'owner',
        status: 'pending',
        createdAt: '2026-08-07T02:00:00.000Z',
        updatedAt: '2026-08-07T02:00:00.000Z',
      }),
    );
    await assertFails(
      requesterDb.collection('follow_requests').doc('wrong-id').set({
        requesterId: 'requester',
        targetId: 'owner',
        status: 'pending',
        createdAt: '2026-08-07T02:00:00.000Z',
        updatedAt: '2026-08-07T02:00:00.000Z',
      }),
    );
    await assertFails(
      requesterDb.collection('follow_requests').doc(followId('requester', 'owner')).set({
        requesterId: 'requester',
        targetId: 'owner',
        status: 'pending',
        createdAt: '2026-08-07T02:00:00.000Z',
      }),
    );
    await assertFails(
      requesterDb.collection('follow_requests').doc(followId('requester', 'public-target')).set({
        requesterId: 'requester',
        targetId: 'public-target',
        status: 'pending',
        createdAt: '2026-08-07T02:00:00.000Z',
        updatedAt: '2026-08-07T02:00:00.000Z',
      }),
    );
    await assertFails(
      otherDb.collection('follow_requests').doc(followId('requester', 'owner')).delete(),
    );
    const requesterAcceptBatch = requesterDb.batch();
    requesterAcceptBatch.set(requesterDb.collection('follows').doc(followId('requester', 'owner')), {
      followerId: 'requester',
      followeeId: 'owner',
      createdAt: '2026-08-07T02:01:00.000Z',
      source: 'follow_request_acceptance',
      acceptedRequestId: followId('requester', 'owner'),
      acceptedRequestCreatedAt: '2026-08-07T02:00:00.000Z',
    });
    requesterAcceptBatch.delete(
      requesterDb.collection('follow_requests').doc(followId('requester', 'owner')),
    );
    await assertFails(requesterAcceptBatch.commit());
    const unrelatedAcceptBatch = otherDb.batch();
    unrelatedAcceptBatch.set(otherDb.collection('follows').doc(followId('requester', 'owner')), {
      followerId: 'requester',
      followeeId: 'owner',
      createdAt: '2026-08-07T02:01:00.000Z',
      source: 'follow_request_acceptance',
      acceptedRequestId: followId('requester', 'owner'),
      acceptedRequestCreatedAt: '2026-08-07T02:00:00.000Z',
    });
    unrelatedAcceptBatch.delete(
      otherDb.collection('follow_requests').doc(followId('requester', 'owner')),
    );
    await assertFails(unrelatedAcceptBatch.commit());
    await assertFails(
      ownerDb.collection('follows').doc('wrong-id').set({
        followerId: 'requester',
        followeeId: 'owner',
        createdAt: '2026-08-07T02:01:00.000Z',
        source: 'follow_request_acceptance',
        acceptedRequestId: followId('requester', 'owner'),
        acceptedRequestCreatedAt: '2026-08-07T02:00:00.000Z',
      }),
    );
    await assertFails(
      ownerDb.collection('follows').doc(followId('other', 'owner')).set({
        followerId: 'other',
        followeeId: 'owner',
        createdAt: '2026-08-07T02:01:00.000Z',
        source: 'follow_request_acceptance',
        acceptedRequestId: followId('other', 'owner'),
        acceptedRequestCreatedAt: '2026-08-07T02:00:00.000Z',
      }),
    );

    const acceptBatch = ownerDb.batch();
    acceptBatch.set(ownerDb.collection('follows').doc(followId('requester', 'owner')), {
      followerId: 'requester',
      followeeId: 'owner',
      createdAt: '2026-08-07T02:01:00.000Z',
      source: 'follow_request_acceptance',
      acceptedRequestId: followId('requester', 'owner'),
      acceptedRequestCreatedAt: '2026-08-07T02:00:00.000Z',
    });
    acceptBatch.delete(ownerDb.collection('follow_requests').doc(followId('requester', 'owner')));
    await assertSucceeds(acceptBatch.commit());
    await assertSucceeds(
      ownerDb
        .collection('profiles')
        .doc('owner')
        .collection('notifications')
        .doc(requestNotificationId)
        .delete(),
    );
    await assertSucceeds(
      ownerDb
        .collection('profiles')
        .doc('owner')
        .collection('notifications')
        .doc(followNotificationId('requester', 'owner'))
        .set({
          recipientId: 'owner',
          actorId: 'requester',
          type: 'follow',
          createdAt: '2026-08-07T02:01:00.000Z',
          readAt: null,
        }),
    );
    await assertSucceeds(requesterDb.collection('profiles').doc('owner').collection('visits').doc('1').get());
    await assertFails(
      ownerDb.collection('follows').doc(followId('requester', 'owner')).set({
        followerId: 'requester',
        followeeId: 'owner',
        createdAt: '2026-08-07T02:01:01.000Z',
        source: 'follow_request_acceptance',
        acceptedRequestId: followId('requester', 'owner'),
        acceptedRequestCreatedAt: '2026-08-07T02:00:00.000Z',
      }),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('follow_requests').doc(followId('other', 'owner')).set({
        requesterId: 'other',
        targetId: 'owner',
        status: 'pending',
        createdAt: '2026-08-07T02:04:00.000Z',
        updatedAt: '2026-08-07T02:04:00.000Z',
      });
      await context.firestore().collection('follow_requests').doc(followId('viewer', 'owner')).set({
        requesterId: 'viewer',
        targetId: 'owner',
        status: 'pending',
        createdAt: '2026-08-07T02:05:00.000Z',
        updatedAt: '2026-08-07T02:05:00.000Z',
      });
    });
    await assertSucceeds(
      ownerDb.collection('follow_requests').doc(followId('other', 'owner')).delete(),
    );
    await assertSucceeds(
      otherDb.collection('follows').doc(followId('other', 'owner')).get().then((doc) => {
        if (doc.exists) throw new Error('decline created an unexpected follow');
      }),
    );
    await assertSucceeds(
      viewerDb.collection('follow_requests').doc(followId('viewer', 'owner')).delete(),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('follows').doc(followId('follower', 'owner')).set({
        followerId: 'follower',
        followeeId: 'owner',
        createdAt: '2026-08-07T02:02:00.000Z',
      });
    });
    await assertSucceeds(followerDb.collection('profiles').doc('owner').collection('xp_events').doc('xp-1').get());
    await assertFails(
      otherDb.collection('follows').doc(followId('follower', 'owner')).set({
        followerId: 'follower',
        followeeId: 'owner',
        createdAt: '2026-08-07T02:03:00.000Z',
      }),
    );

    console.log('passed: private account access and follow request rules');
  } finally {
    await testEnv.cleanup();
  }
}

(async () => {
  await runScenario('owner public dashboard reads', 'owner', assertSucceeds);
  await runScenario('authenticated public dashboard reads', 'viewer', assertSucceeds);
  await runScenario('unauthenticated public dashboard denied', null, assertFails);
  await runFollowWriteTests();
  await runNotificationRulesTests();
  await runPrivateAccountRulesTests();
  console.log('firestore public profile and follow rules passed');
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
