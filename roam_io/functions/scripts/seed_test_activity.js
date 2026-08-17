/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Seeds the persistent Kudos/comments test activity for a real public
 *   profile without deleting existing interaction subcollections.
 */

const ACTIVITY_ID = 'sanjevan-test-activity';
const USERNAME = 'sanjevanr_test';
const VIEWER_USERNAME = 'Amar723';
const FIXED_CREATED_AT = '2026-08-10T00:00:00.000Z';
const ACTIVITY_TITLE = "Sanjevan's Test Activity";
const AGGREGATE_FIELDS = ['kudos', 'kudosCount', 'commentCount'];

function normalizeSearchText(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizeUsernameSearchText(value) {
  const normalized = normalizeSearchText(value);
  return normalized.startsWith('@') ? normalized.slice(1) : normalized;
}

function describePhotoUrl(value) {
  const url = typeof value === 'string' ? value.trim() : '';
  if (!url) return 'missing';
  if (url.startsWith('https://')) return 'https';
  if (url.startsWith('http://')) return 'http';
  if (url.startsWith('gs://')) return 'gs';
  try {
    const parsed = new URL(url);
    return parsed.protocol.replace(':', '') || 'malformed';
  } catch (_) {
    return 'storage_path';
  }
}

function docData(doc) {
  return typeof doc.data === 'function' ? doc.data() : doc.data;
}

function docSummary(doc) {
  const data = docData(doc) || {};
  return {
    uid: doc.id,
    username: data.username,
    usernameSearch: data.usernameSearch,
    displayName: data.displayName,
    hasPhotoUrl:
      typeof data.photoUrl === 'string' && data.photoUrl.trim().length > 0,
    photoUrlFormat: describePhotoUrl(data.photoUrl),
  };
}

function resolveProfileFromDocs({ username, publicProfileDocs, profileDocs }) {
  const normalized = normalizeUsernameSearchText(username);
  const publicMatches = publicProfileDocs
    .filter((doc) => {
      const data = docData(doc) || {};
      return normalizeUsernameSearchText(data.usernameSearch || data.username) ===
        normalized;
    })
    .map(docSummary);
  const privateMatches = profileDocs
    .filter((doc) => {
      const data = docData(doc) || {};
      return normalizeUsernameSearchText(data.username) === normalized;
    })
    .map(docSummary);
  const matchedUids = new Set([
    ...publicMatches.map((profile) => profile.uid),
    ...privateMatches.map((profile) => profile.uid),
  ]);

  if (matchedUids.size === 0) {
    throw new Error(`No profile found for username ${username}`);
  }
  if (matchedUids.size > 1) {
    throw new Error(
      `Multiple profiles found for username ${username}: ${
        [...matchedUids].join(', ')
      }`,
    );
  }

  const uid = [...matchedUids][0];
  const publicProfile = publicMatches.find((profile) => profile.uid === uid);
  const privateProfile = privateMatches.find((profile) => profile.uid === uid);
  if (!publicProfile) {
    throw new Error(
      `Profile ${uid} matches ${username} but public_profiles/${uid} is missing`,
    );
  }
  if (!privateProfile) {
    throw new Error(
      `Profile ${uid} matches ${username} but profiles/${uid}.username is missing or mismatched`,
    );
  }

  return {
    uid,
    publicProfile,
    privateProfile,
    publicMatches,
    privateMatches,
  };
}

const resolveOwnerFromDocs = resolveProfileFromDocs;

function buildTestActivity({
  activityId = ACTIVITY_ID,
  ownerUid,
  publicProfile,
  existingActivity,
}) {
  const createdAt = typeof existingActivity?.createdAt === 'string' &&
      existingActivity.createdAt.trim()
    ? existingActivity.createdAt
    : FIXED_CREATED_AT;
  const username = String(publicProfile.username || '').trim();
  const displayName =
    String(publicProfile.displayName || '').trim() || username || 'Traveller';
  const activity = {
    activityId,
    ownerId: ownerUid,
    profileId: ownerUid,
    displayName,
    username,
    title: ACTIVITY_TITLE,
    kind: 'exploration',
    showMapPreview: true,
    createdAt,
    metrics: [
      { label: 'Time', value: '12m 34s' },
      { label: 'Locations Visited', value: '3' },
      { label: 'XP Gained', value: '+120 XP' },
    ],
  };
  if (publicProfile.hasPhotoUrl && typeof publicProfile.photoUrl === 'string') {
    activity.photoUrl = publicProfile.photoUrl.trim();
  } else if (
    typeof publicProfile.photoUrl === 'string' &&
    publicProfile.photoUrl.trim()
  ) {
    activity.photoUrl = publicProfile.photoUrl.trim();
  }
  return activity;
}

function activitySchemaSummary(activity) {
  return {
    activityId: activity.activityId,
    ownerId: activity.ownerId,
    profileId: activity.profileId,
    title: activity.title,
    kind: activity.kind,
    createdAt: activity.createdAt,
    showMapPreview: activity.showMapPreview,
    metricsCount: Array.isArray(activity.metrics) ? activity.metrics.length : 0,
    username: activity.username,
    displayName: activity.displayName,
    hasPhotoUrl:
      typeof activity.photoUrl === 'string' &&
      activity.photoUrl.trim().length > 0,
    photoUrlFormat: describePhotoUrl(activity.photoUrl),
  };
}

function expectedTitleForActivityId(activityId) {
  return ACTIVITY_TITLE;
}

function activityDocSummary(doc, resolvedOwnerUid) {
  const exists = doc.exists === true;
  const data = exists ? doc.data() || {} : {};
  const hasOwnerUid = Object.prototype.hasOwnProperty.call(data, 'ownerUid');
  const aggregateFieldsPresent = AGGREGATE_FIELDS.filter((field) => {
    return Object.prototype.hasOwnProperty.call(data, field);
  });
  return {
    exists,
    path: doc.ref?.path || `activities/${doc.id}`,
    activityId: data.activityId,
    ownerId: data.ownerId,
    profileId: data.profileId,
    hasOwnerUid,
    ownerUid: data.ownerUid,
    aggregateFieldsPresent,
    hasAggregateFields: aggregateFieldsPresent.length > 0,
    title: data.title,
    createdAt: data.createdAt,
    ownerIdMatchesResolvedUid: data.ownerId === resolvedOwnerUid,
    profileIdMatchesResolvedUid: data.profileId === resolvedOwnerUid,
    activityIdMatchesDocumentId: data.activityId === doc.id,
    titleMatchesExpected: data.title === expectedTitleForActivityId(doc.id),
  };
}

function followDocSummary(doc, followerId, followeeId) {
  if (!followerId) return null;
  const exists = doc.exists === true;
  const data = exists ? doc.data() || {} : {};
  return {
    exists,
    path: doc.ref?.path || `follows/${followerId}_${followeeId}`,
    followerId: data.followerId,
    followeeId: data.followeeId,
    followerIdMatchesExpected: data.followerId === followerId,
    followeeIdMatchesResolvedUid: data.followeeId === followeeId,
  };
}

function valuesMatch(actual, expected) {
  if (Array.isArray(expected) || typeof expected === 'object') {
    return JSON.stringify(actual) === JSON.stringify(expected);
  }
  return actual === expected;
}

function activityFieldMismatches(existingActivity, expectedActivity) {
  if (!existingActivity) return ['document_missing'];
  return Object.keys(expectedActivity).filter((field) => {
    return !valuesMatch(existingActivity[field], expectedActivity[field]);
  });
}

async function fetchOwnerCandidates(db, username) {
  const normalized = normalizeUsernameSearchText(username);
  const publicSnapshot = await db
    .collection('public_profiles')
    .where('usernameSearch', '==', normalized)
    .get();
  const profilesSnapshot = await db.collection('profiles').get();
  return {
    publicProfileDocs: publicSnapshot.docs,
    profileDocs: profilesSnapshot.docs,
  };
}

async function resolveProfileByUsername(db, username) {
  const candidates = await fetchOwnerCandidates(db, username);
  return resolveProfileFromDocs({ username, ...candidates });
}

function titleDiagnosticDocSummary(doc) {
  const data = doc.data() || {};
  return {
    path: doc.ref?.path || `activities/${doc.id}`,
    activityId: data.activityId,
    ownerId: data.ownerId,
    profileId: data.profileId,
    hasOwnerUid: Object.prototype.hasOwnProperty.call(data, 'ownerUid'),
    title: data.title,
    createdAt: data.createdAt,
  };
}

async function fetchTitleDiagnostics(db, activityDocExists, activityId = ACTIVITY_ID) {
  if (activityDocExists) {
    return {
      ran: false,
      reason: 'exact_activity_doc_exists',
      matches: [],
    };
  }
  const expectedTitle = expectedTitleForActivityId(activityId);
  const snapshot = await db
    .collection('activities')
    .where('title', '==', expectedTitle)
    .get();
  return {
    ran: true,
    reason: 'exact_activity_doc_missing',
    matches: snapshot.docs.map(titleDiagnosticDocSummary),
  };
}

async function countActivitySubcollection(activityRef, name) {
  const snapshot = await activityRef.collection(name).get();
  return snapshot.size ?? snapshot.docs.length;
}

async function activityQueryPresence(db, activityId) {
  const snapshot = await db
    .collection('activities')
    .where('activityId', '==', activityId)
    .get();
  return {
    queriedField: 'activityId',
    queriedValue: activityId,
    matchingPaths: snapshot.docs.map((doc) => {
      return doc.ref?.path || `activities/${doc.id}`;
    }),
    containsExactPath: snapshot.docs.some((doc) => doc.id === activityId),
  };
}

function profileVerificationSummary({ username, resolved, role }) {
  return {
    role,
    requestedUsername: username,
    normalizedUsername: normalizeUsernameSearchText(username),
    uid: resolved.uid,
    mechanism:
      'public_profiles.usernameSearch exact match, cross-checked against profiles.username',
    publicProfileExists: Boolean(resolved.publicProfile),
    privateProfileExists: Boolean(resolved.privateProfile),
    publicProfilePhotoUrlFormat: resolved.publicProfile.photoUrlFormat,
  };
}

function directUidViewerSummary(uid) {
  if (!uid) return null;
  return {
    role: 'viewer',
    requestedUsername: null,
    normalizedUsername: null,
    uid,
    mechanism: 'direct UID argument',
    publicProfileExists: null,
    privateProfileExists: null,
    publicProfilePhotoUrlFormat: null,
  };
}

function visibilitySummary({ activity, ownerUid, viewerUid, follow }) {
  const exactDocEligible =
    activity.exists &&
    activity.activityIdMatchesDocumentId &&
    activity.ownerId === ownerUid;
  const viewerFollowsOwner =
    Boolean(follow?.exists) &&
    follow.followerIdMatchesExpected &&
    follow.followeeIdMatchesResolvedUid;
  return {
    ownerHomeEligible: exactDocEligible,
    ownerYouEligible: exactDocEligible,
    viewerHomeEligible:
      exactDocEligible && (viewerUid === ownerUid || viewerFollowsOwner),
    viewerYouEligible: exactDocEligible && viewerUid === activity.ownerId,
    viewerFollowsOwner,
  };
}

function firestoreFor({ db, projectId }) {
  if (db) return db;
  const admin = require('firebase-admin');

  if (!admin.apps.length) {
    admin.initializeApp(projectId ? { projectId } : undefined);
  }

  return admin.firestore();
}

function readAppConfigProjectId() {
  try {
    const fs = require('node:fs');
    const path = require('node:path');
    const firebaseJsonPath = path.join(__dirname, '..', '..', 'firebase.json');
    const firebaseJson = JSON.parse(fs.readFileSync(firebaseJsonPath, 'utf8'));
    return firebaseJson?.flutter?.platforms?.dart?.[
      'lib/firebase_options.dart'
    ]?.projectId || null;
  } catch (_) {
    return null;
  }
}

async function verifyTestActivity({
  db,
  projectId,
  username,
  ownerUsername = username || USERNAME,
  viewerUsername,
  activityId = ACTIVITY_ID,
  currentUserId,
} = {}) {
  const firestore = firestoreFor({ db, projectId });
  const owner = await resolveProfileByUsername(firestore, ownerUsername);
  const viewer = viewerUsername
    ? await resolveProfileByUsername(firestore, viewerUsername)
    : null;
  const viewerSummary = viewer
    ? profileVerificationSummary({
        username: viewerUsername,
        resolved: viewer,
        role: 'viewer',
      })
    : directUidViewerSummary(currentUserId);
  const viewerUid = viewerSummary?.uid;
  const activityRef = firestore.collection('activities').doc(activityId);
  const activityDoc = await activityRef.get();
  const activity = activityDocSummary(activityDoc, owner.uid);
  const commentsCount = await countActivitySubcollection(activityRef, 'comments');
  const kudosCount = await countActivitySubcollection(activityRef, 'kudos');
  const queryPresence = await activityQueryPresence(firestore, activityId);
  const titleDiagnostics = await fetchTitleDiagnostics(
    firestore,
    activity.exists,
    activityId,
  );
  const followId = viewerUid ? `${viewerUid}_${owner.uid}` : undefined;
  const followDoc = followId
    ? await firestore.collection('follows').doc(followId).get()
    : null;
  const follow = followDoc
    ? followDocSummary(followDoc, viewerUid, owner.uid)
    : null;

  return {
    projectId: projectId || '(default credentials project)',
    appConfigProjectId: readAppConfigProjectId(),
    owner: profileVerificationSummary({
      username: ownerUsername,
      resolved: owner,
      role: 'owner',
    }),
    viewer: viewerSummary,
    requestedUsername: ownerUsername,
    normalizedUsername: normalizeUsernameSearchText(ownerUsername),
    resolvedOwnerUid: owner.uid,
    resolvedViewerUid: viewerUid,
    resolvedOwnerMechanism:
      'public_profiles.usernameSearch exact match, cross-checked against profiles.username',
    publicProfileExists: Boolean(owner.publicProfile),
    privateProfileExists: Boolean(owner.privateProfile),
    publicProfilePhotoUrlFormat: owner.publicProfile.photoUrlFormat,
    activity,
    subcollections: {
      commentsCount,
      kudosCount,
    },
    queryPresence,
    titleDiagnostics,
    follow,
    visibility: visibilitySummary({
      activity,
      ownerUid: owner.uid,
      viewerUid,
      follow,
    }),
  };
}

async function seedTestActivity({
  db,
  projectId,
  username,
  ownerUsername = username || USERNAME,
  viewerUsername,
  activityId = ACTIVITY_ID,
  dryRun = false,
  currentUserId,
} = {}) {
  const firestore = firestoreFor({ db, projectId });
  const before = await verifyTestActivity({
    db: firestore,
    projectId,
    ownerUsername,
    viewerUsername,
    activityId,
    currentUserId,
  });
  const activityRef = firestore.collection('activities').doc(activityId);
  const existingDoc = await activityRef.get();
  const publicDoc = await firestore
    .collection('public_profiles')
    .doc(before.resolvedOwnerUid)
    .get();
  const publicProfile = {
    uid: before.resolvedOwnerUid,
    username: ownerUsername,
    usernameSearch: normalizeUsernameSearchText(ownerUsername),
    ...(publicDoc.data() || {}),
  };
  const activity = buildTestActivity({
    activityId,
    ownerUid: before.resolvedOwnerUid,
    publicProfile,
    existingActivity: existingDoc.data(),
  });
  const mismatchedFields = activityFieldMismatches(
    existingDoc.exists ? existingDoc.data() : null,
    activity,
  );
  const seedNeeded = !existingDoc.exists || mismatchedFields.length > 0;

  if (seedNeeded && !dryRun) {
    await activityRef.set(activity, { merge: true });
  }
  const after = await verifyTestActivity({
    db: firestore,
    projectId,
    ownerUsername,
    viewerUsername,
    activityId,
    currentUserId,
  });

  return {
    projectId: projectId || '(default credentials project)',
    dryRun,
    seedNeeded,
    writePerformed: seedNeeded && !dryRun,
    mismatchedFields,
    path: `activities/${activityId}`,
    resolvedOwnerUid: before.resolvedOwnerUid,
    resolvedOwnerMechanism: before.resolvedOwnerMechanism,
    before,
    after,
    commentsCountUnchanged:
      before.subcollections.commentsCount === after.subcollections.commentsCount,
    kudosCountBefore: before.subcollections.kudosCount,
    kudosCountAfter: after.subcollections.kudosCount,
    preservedSubcollections: [
      'activities/{activityId}/kudos',
      'activities/{activityId}/comments',
      'activities/{activityId}/comments/{commentId}/likes',
    ],
    activitySchema: activitySchemaSummary(activity),
  };
}

function parseArgs(argv) {
  const args = {
    projectId: undefined,
    username: USERNAME,
    ownerUsername: undefined,
    viewerUsername: undefined,
    activityId: ACTIVITY_ID,
    dryRun: false,
    currentUserId: undefined,
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--project') {
      args.projectId = argv[index + 1];
      index += 1;
    } else if (arg === '--username') {
      args.username = argv[index + 1];
      args.ownerUsername = argv[index + 1];
      index += 1;
    } else if (arg === '--owner-username') {
      args.ownerUsername = argv[index + 1];
      index += 1;
    } else if (arg === '--viewer-username') {
      args.viewerUsername = argv[index + 1];
      index += 1;
    } else if (arg === '--activity-id') {
      args.activityId = argv[index + 1];
      index += 1;
    } else if (arg === '--dry-run') {
      args.dryRun = true;
    } else if (arg === '--current-user' || arg === '--current-user-uid') {
      args.currentUserId = argv[index + 1];
      index += 1;
    }
  }
  return args;
}

if (require.main === module) {
  seedTestActivity(parseArgs(process.argv))
    .then((report) => {
      console.log(JSON.stringify(report, null, 2));
      process.exit(0);
    })
    .catch((error) => {
      console.error('[seed_test_activity] failed:', error);
      process.exit(1);
    });
}

module.exports = {
  ACTIVITY_ID,
  ACTIVITY_TITLE,
  AGGREGATE_FIELDS,
  USERNAME,
  VIEWER_USERNAME,
  activityDocSummary,
  activityFieldMismatches,
  activitySchemaSummary,
  buildTestActivity,
  countActivitySubcollection,
  describePhotoUrl,
  expectedTitleForActivityId,
  activityQueryPresence,
  fetchTitleDiagnostics,
  followDocSummary,
  normalizeUsernameSearchText,
  parseArgs,
  profileVerificationSummary,
  resolveOwnerFromDocs,
  resolveProfileFromDocs,
  seedTestActivity,
  titleDiagnosticDocSummary,
  visibilitySummary,
  verifyTestActivity,
};
