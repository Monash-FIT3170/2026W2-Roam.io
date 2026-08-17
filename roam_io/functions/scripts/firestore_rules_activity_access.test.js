/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 16 August 2026 — Sanjevan Rajasegar
 * Description:
 *   Firestore rules tests for profile activity reads, follows, activity
 *   creation, counters, and interaction subcollections.
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
      activityId: 'activity-1',
      ownerId: 'owner',
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

function testActivityData(activityId, ownerId, overrides = {}) {
  return {
    activityId,
    ownerId,
    profileId: ownerId,
    displayName: 'Owner',
    username: 'owner',
    title: 'Owner Activity 1',
    kind: 'exploration',
    metrics: [{ label: 'XP Gained', value: '+120 XP' }],
    showMapPreview: true,
    createdAt: '2026-08-10T00:00:00.000Z',
    ...overrides,
  };
}

function activityOwnerQuery(db, ownerId) {
  return db
    .collection('activities')
    .where('ownerId', '==', ownerId)
    .orderBy('createdAt', 'desc')
    .limit(20)
    .get();
}

async function runActivityCreateRulesTests() {
  const testEnv = await initializeTestEnvironment({ projectId, firestore: { rules } });
  try {
    await seed(testEnv);
    const ownerDb = testEnv.authenticatedContext('owner').firestore();
    const viewerDb = testEnv.authenticatedContext('viewer').firestore();
    const anonDb = testEnv.unauthenticatedContext().firestore();

    await assertSucceeds(
      ownerDb
        .collection('activities')
        .doc('owner-generated-1')
        .set(testActivityData('owner-generated-1', 'owner')),
    );
    await assertFails(
      ownerDb
        .collection('activities')
        .doc('wrong-doc-id')
        .set(testActivityData('owner-generated-1', 'owner')),
    );
    await assertFails(
      ownerDb
        .collection('activities')
        .doc('wrong-owner')
        .set(testActivityData('wrong-owner', 'viewer')),
    );
    await assertFails(
      anonDb
        .collection('activities')
        .doc('anon-generated')
        .set(testActivityData('anon-generated', 'owner')),
    );

    await assertSucceeds(
      ownerDb.collection('activity_counters').doc('owner').set({
        ownerId: 'owner',
        lastTestActivityNumber: 1,
        createdAt: '2026-08-10T00:00:00.000Z',
        updatedAt: '2026-08-10T00:00:00.000Z',
      }),
    );
    await assertSucceeds(
      ownerDb.collection('activity_counters').doc('owner').set({
        ownerId: 'owner',
        lastTestActivityNumber: 2,
        createdAt: '2026-08-10T00:00:00.000Z',
        updatedAt: '2026-08-10T00:01:00.000Z',
      }),
    );
    await assertFails(
      ownerDb.collection('activity_counters').doc('owner').set({
        ownerId: 'owner',
        lastTestActivityNumber: 3,
        createdAt: 'changed',
        updatedAt: '2026-08-10T00:02:00.000Z',
      }),
    );
    await assertFails(
      viewerDb.collection('activity_counters').doc('owner').get(),
    );
    await assertFails(
      viewerDb.collection('activity_counters').doc('owner').set({
        ownerId: 'owner',
        lastTestActivityNumber: 1,
        createdAt: '2026-08-10T00:00:00.000Z',
        updatedAt: '2026-08-10T00:00:00.000Z',
      }),
    );
    console.log('passed: activity create and counter rules');
  } finally {
    await testEnv.cleanup();
  }
}

async function runActivityQueryRulesTests() {
  const testEnv = await initializeTestEnvironment({ projectId, firestore: { rules } });
  try {
    await seed(testEnv);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('public_profiles').doc('public-owner').set({
        uid: 'public-owner',
        username: 'public_owner',
        usernameSearch: 'public_owner',
        displayName: 'Public Owner',
        displayNameSearch: 'public owner',
        isPrivateAccount: false,
        createdAt: '2026-08-10T00:00:00.000Z',
        updatedAt: '2026-08-10T00:00:00.000Z',
      });
      await db.collection('public_profiles').doc('private-owner').set({
        uid: 'private-owner',
        username: 'private_owner',
        usernameSearch: 'private_owner',
        displayName: 'Private Owner',
        displayNameSearch: 'private owner',
        isPrivateAccount: true,
        createdAt: '2026-08-10T00:00:00.000Z',
        updatedAt: '2026-08-10T00:00:00.000Z',
      });
      await db.collection('activities').doc('public-activity').set(
        testActivityData('public-activity', 'public-owner', {
          title: 'Public Activity',
        }),
      );
      await db.collection('activities').doc('private-activity').set(
        testActivityData('private-activity', 'private-owner', {
          title: 'Private Activity',
        }),
      );
      await db.collection('follows').doc(followId('approved-follower', 'private-owner')).set({
        followerId: 'approved-follower',
        followeeId: 'private-owner',
        createdAt: '2026-08-10T00:00:00.000Z',
        source: 'follow_request_acceptance',
      });
      await db.collection('follow_requests').doc(followId('pending-user', 'private-owner')).set({
        requesterId: 'pending-user',
        targetId: 'private-owner',
        status: 'pending',
        createdAt: '2026-08-10T00:00:00.000Z',
        updatedAt: '2026-08-10T00:00:00.000Z',
      });
    });

    const ownerDb = testEnv.authenticatedContext('owner').firestore();
    const viewerDb = testEnv.authenticatedContext('viewer').firestore();
    const publicOwnerDb = testEnv.authenticatedContext('public-owner').firestore();
    const privateOwnerDb = testEnv.authenticatedContext('private-owner').firestore();
    const approvedFollowerDb = testEnv.authenticatedContext('approved-follower').firestore();
    const pendingUserDb = testEnv.authenticatedContext('pending-user').firestore();
    const anonDb = testEnv.unauthenticatedContext().firestore();

    await assertSucceeds(activityOwnerQuery(ownerDb, 'owner'));
    await assertSucceeds(activityOwnerQuery(publicOwnerDb, 'public-owner'));
    await assertSucceeds(activityOwnerQuery(viewerDb, 'public-owner'));
    await assertSucceeds(activityOwnerQuery(privateOwnerDb, 'private-owner'));
    await assertSucceeds(activityOwnerQuery(approvedFollowerDb, 'private-owner'));
    await assertFails(activityOwnerQuery(viewerDb, 'private-owner'));
    await assertFails(activityOwnerQuery(pendingUserDb, 'private-owner'));
    await assertFails(activityOwnerQuery(anonDb, 'public-owner'));
    console.log('passed: activity owner query privacy rules');
  } finally {
    await testEnv.cleanup();
  }
}

async function runActivityInteractionRulesTests() {
  const testEnv = await initializeTestEnvironment({ projectId, firestore: { rules } });
  try {
    await seed(testEnv);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('public_profiles').doc('private-owner').set({
        uid: 'private-owner',
        username: 'private_owner',
        usernameSearch: 'private_owner',
        displayName: 'Private Owner',
        displayNameSearch: 'private owner',
        isPrivateAccount: true,
        createdAt: '2026-08-10T00:00:00.000Z',
        updatedAt: '2026-08-10T00:00:00.000Z',
      });
      await db.collection('activities').doc('private-activity').set(
        testActivityData('private-activity', 'private-owner'),
      );
      await db.collection('follows').doc(followId('approved-follower', 'private-owner')).set({
        followerId: 'approved-follower',
        followeeId: 'private-owner',
        createdAt: '2026-08-10T00:00:00.000Z',
        source: 'follow_request_acceptance',
      });
    });

    const viewerDb = testEnv.authenticatedContext('viewer').firestore();
    const approvedFollowerDb = testEnv.authenticatedContext('approved-follower').firestore();
    const createdAt = '2026-08-10T00:01:00.000Z';

    await assertSucceeds(
      viewerDb.collection('activities').doc('activity-1').collection('kudos').doc('viewer').set({
        activityId: 'activity-1',
        activityOwnerId: 'owner',
        userId: 'viewer',
        createdAt,
      }),
    );
    await assertSucceeds(
      viewerDb.collection('activities').doc('activity-1').collection('comments').doc('comment-1').set({
        activityId: 'activity-1',
        authorId: 'viewer',
        authorDisplayName: 'Viewer',
        text: 'Great activity',
        createdAt,
        updatedAt: createdAt,
        parentCommentId: null,
        replyToUserId: null,
        replyToDisplayName: null,
      }),
    );
    await assertSucceeds(
      approvedFollowerDb
        .collection('activities')
        .doc('private-activity')
        .collection('kudos')
        .doc('approved-follower')
        .set({
          activityId: 'private-activity',
          activityOwnerId: 'private-owner',
          userId: 'approved-follower',
          createdAt,
        }),
    );
    await assertFails(
      viewerDb
        .collection('activities')
        .doc('private-activity')
        .collection('kudos')
        .doc('viewer')
        .set({
          activityId: 'private-activity',
          activityOwnerId: 'private-owner',
          userId: 'viewer',
          createdAt,
        }),
    );
    await assertFails(
      viewerDb.collection('activities').doc('missing-activity').collection('kudos').doc('viewer').set({
        activityId: 'missing-activity',
        activityOwnerId: 'viewer',
        userId: 'viewer',
        createdAt,
      }),
    );
    console.log('passed: activity interaction subcollection rules');
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
  await runActivityCreateRulesTests();
  await runActivityQueryRulesTests();
  await runActivityInteractionRulesTests();
  await runPrivateAccountRulesTests();
  console.log('firestore public profile and follow rules passed');
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
