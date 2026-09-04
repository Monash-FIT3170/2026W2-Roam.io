/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Lightweight assertions for deterministic test activity seeding helpers.
 */

const assert = require('node:assert/strict');

const {
  ACTIVITY_ID,
  activityDocSummary,
  activityFieldMismatches,
  buildTestActivity,
  describePhotoUrl,
  fetchTitleDiagnostics,
  followDocSummary,
  parseArgs,
  resolveOwnerFromDocs,
  seedTestActivity,
  visibilitySummary,
  verifyTestActivity,
} = require('./seed_test_activity');

function doc(id, data) {
  return { id, exists: true, ref: { path: `test/${id}` }, data: () => data };
}

function missingDoc(id, collection) {
  return {
    id,
    exists: false,
    ref: { path: `${collection}/${id}` },
    data: () => undefined,
  };
}

function fakeFirestore(collections) {
  function docsFor(name) {
    if (!collections[name]) collections[name] = {};
    return collections[name];
  }

  function snapshotFromDocs(docs) {
    return {
      size: docs.length,
      docs,
    };
  }

  function docSnapshot(collectionName, id, data) {
    return {
      id,
      exists: true,
      ref: { path: `${collectionName}/${id}` },
      data: () => data,
    };
  }

  function collectionApi(name) {
    const docs = docsFor(name);
    return {
      doc(id) {
        return {
          collection(childName) {
            return collectionApi(`${name}/${id}/${childName}`);
          },
          get: async () =>
            Object.prototype.hasOwnProperty.call(docs, id)
              ? docSnapshot(name, id, docs[id])
              : missingDoc(id, name),
          set: async (data, options = {}) => {
            docs[id] = options.merge ? { ...(docs[id] || {}), ...data } : data;
          },
        };
      },
      where(field, operator, value) {
        assert.equal(operator, '==');
        return {
          get: async () =>
            snapshotFromDocs(
              Object.entries(docs)
                .filter(([, data]) => data[field] === value)
                .map(([id, data]) => docSnapshot(name, id, data)),
            ),
        };
      },
      get: async () =>
        snapshotFromDocs(
          Object.entries(docs).map(([id, data]) => docSnapshot(name, id, data)),
        ),
    };
  }

  return {
    collection(name) {
      return collectionApi(name);
    },
  };
}

const resolved = resolveOwnerFromDocs({
  username: 'sanjevanr_test',
  publicProfileDocs: [
    doc('uid-1', {
      username: 'sanjevanr_test',
      usernameSearch: 'sanjevanr_test',
      displayName: 'Sanjevan Test',
      photoUrl: 'gs://bucket/avatars/uid-1.jpg',
    }),
  ],
  profileDocs: [
    doc('uid-1', {
      username: 'SanjevanR_Test',
      displayName: 'Sanjevan Test',
    }),
  ],
});

assert.equal(resolved.uid, 'uid-1');
assert.equal(resolved.publicProfile.photoUrlFormat, 'gs');

const activity = buildTestActivity({
  ownerUid: resolved.uid,
  publicProfile: {
    ...resolved.publicProfile,
    photoUrl: 'gs://bucket/avatars/uid-1.jpg',
  },
});

assert.equal(activity.activityId, ACTIVITY_ID);
assert.equal(activity.ownerId, 'uid-1');
assert.equal(activity.profileId, 'uid-1');
assert.equal(activity.title, "Sanjevan's Test Activity");
assert.equal(activity.kind, 'exploration');
assert.equal(activity.createdAt, '2026-08-10T00:00:00.000Z');
assert.equal(activity.photoUrl, 'gs://bucket/avatars/uid-1.jpg');
assert.equal(activity.metrics.length, 3);
assert.deepEqual(activityFieldMismatches(activity, activity), []);
assert.deepEqual(activityFieldMismatches(null, activity), ['document_missing']);
assert.deepEqual(
  activityFieldMismatches({ ...activity, ownerId: 'wrong' }, activity),
  ['ownerId'],
);

const activitySummary = activityDocSummary(
  doc('sanjevan-test-activity', activity),
  'uid-1',
);
assert.equal(activitySummary.path, 'test/sanjevan-test-activity');
assert.equal(activitySummary.ownerIdMatchesResolvedUid, true);
assert.equal(activitySummary.activityIdMatchesDocumentId, true);
assert.equal(activitySummary.titleMatchesExpected, true);
assert.equal(activitySummary.hasOwnerUid, false);

const wrongOwnerUidSummary = activityDocSummary(
  doc('sanjevan-test-activity', {
    ...activity,
    ownerUid: 'legacy-wrong-field',
  }),
  'uid-1',
);
assert.equal(wrongOwnerUidSummary.hasOwnerUid, true);
assert.equal(wrongOwnerUidSummary.ownerUid, 'legacy-wrong-field');

const followSummary = followDocSummary(
  doc('uid-2_uid-1', { followerId: 'uid-2', followeeId: 'uid-1' }),
  'uid-2',
  'uid-1',
);
assert.equal(followSummary.exists, true);
assert.equal(followSummary.followerIdMatchesExpected, true);
assert.equal(followSummary.followeeIdMatchesResolvedUid, true);

assert.deepEqual(
  visibilitySummary({
    activity: activitySummary,
    ownerUid: 'uid-1',
    viewerUid: 'uid-2',
    follow: followSummary,
  }),
  {
    ownerHomeEligible: true,
    ownerYouEligible: true,
    viewerHomeEligible: true,
    viewerYouEligible: false,
    viewerFollowsOwner: true,
  },
);

assert.equal(
  visibilitySummary({
    activity: activitySummary,
    ownerUid: 'uid-1',
    viewerUid: 'uid-3',
    follow: null,
  }).viewerHomeEligible,
  false,
);

const preservedCreatedAt = buildTestActivity({
  ownerUid: 'uid-1',
  publicProfile: resolved.publicProfile,
  existingActivity: { createdAt: '2026-08-01T00:00:00.000Z' },
});
assert.equal(preservedCreatedAt.createdAt, '2026-08-01T00:00:00.000Z');

assert.throws(
  () =>
    resolveOwnerFromDocs({
      username: 'missing',
      publicProfileDocs: [],
      profileDocs: [],
    }),
  /No profile found/,
);

assert.throws(
  () =>
    resolveOwnerFromDocs({
      username: 'sanjevanr_test',
      publicProfileDocs: [
        doc('uid-1', {
          username: 'sanjevanr_test',
          usernameSearch: 'sanjevanr_test',
        }),
        doc('uid-2', {
          username: 'sanjevanr_test',
          usernameSearch: 'sanjevanr_test',
        }),
      ],
      profileDocs: [],
    }),
  /Multiple profiles found/,
);

assert.throws(
  () =>
    resolveOwnerFromDocs({
      username: 'sanjevanr_test',
      publicProfileDocs: [],
      profileDocs: [
        doc('uid-1', {
          username: 'sanjevanr_test',
          displayName: 'Sanjevan Test',
        }),
      ],
    }),
  /public_profiles\/uid-1 is missing/,
);

assert.equal(describePhotoUrl('https://example.com/a.jpg'), 'https');
assert.equal(describePhotoUrl('avatars/uid-1.jpg'), 'storage_path');
assert.equal(
  parseArgs([
    'node',
    'script',
    '--project',
    'roam-io-71e2c',
    '--owner-username',
    'sanjevanr_test',
    '--viewer-username',
    'Amar723',
  ]).viewerUsername,
  'Amar723',
);

assert.equal(
  parseArgs(['node', 'script', '--username', 'sanjevanr_test']).ownerUsername,
  'sanjevanr_test',
);

async function runAsyncAssertions() {
  const verification = await verifyTestActivity({
    db: fakeFirestore({
      public_profiles: {
        'sanjevan-uid': {
          username: 'sanjevanr_test',
          usernameSearch: 'sanjevanr_test',
          displayName: 'Sanjevan Test',
        },
        'amar-uid': {
          username: 'Amar723',
          usernameSearch: 'amar723',
          displayName: 'Amar',
        },
      },
      profiles: {
        'sanjevan-uid': { username: 'sanjevanr_test' },
        'amar-uid': { username: 'Amar723' },
      },
      activities: {
        'sanjevan-test-activity': {
          activityId: 'sanjevan-test-activity',
          ownerId: 'sanjevan-uid',
          profileId: 'sanjevan-uid',
          title: "Sanjevan's Test Activity",
          createdAt: '2026-08-10T00:00:00.000Z',
        },
      },
      follows: {
        'amar-uid_sanjevan-uid': {
          followerId: 'amar-uid',
          followeeId: 'sanjevan-uid',
          createdAt: '2026-08-10T00:00:00.000Z',
        },
      },
    }),
    projectId: 'roam-io-71e2c',
    ownerUsername: 'sanjevanr_test',
    viewerUsername: 'Amar723',
  });
  assert.equal(verification.resolvedOwnerUid, 'sanjevan-uid');
  assert.equal(verification.resolvedViewerUid, 'amar-uid');
  assert.equal(verification.activity.ownerIdMatchesResolvedUid, true);
  assert.equal(verification.activity.hasOwnerUid, false);
  assert.equal(verification.follow.path, 'follows/amar-uid_sanjevan-uid');
  assert.equal(verification.visibility.ownerHomeEligible, true);
  assert.equal(verification.visibility.ownerYouEligible, true);
  assert.equal(verification.visibility.viewerHomeEligible, true);
  assert.equal(verification.visibility.viewerYouEligible, false);

  const diagnostics = await fetchTitleDiagnostics(
    {
      collection: () => ({
        where: () => ({
          get: async () => ({
            docs: [
              doc('other-test-activity', {
                activityId: 'other-test-activity',
                ownerId: 'uid-1',
                profileId: 'uid-1',
                title: "Sanjevan's Test Activity",
                createdAt: '2026-08-10T00:00:00.000Z',
              }),
            ],
          }),
        }),
      }),
    },
    false,
  );
  assert.equal(diagnostics.ran, true);
  assert.equal(diagnostics.reason, 'exact_activity_doc_missing');
  assert.equal(diagnostics.matches.length, 1);
  assert.equal(diagnostics.matches[0].path, 'test/other-test-activity');

  const skipped = await fetchTitleDiagnostics({}, true);
  assert.equal(skipped.ran, false);
  assert.equal(skipped.reason, 'exact_activity_doc_exists');
}

runAsyncAssertions()
  .then(() => {
    console.log('seed_test_activity helpers passed');
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
