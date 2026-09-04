/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Narrow cleanup utility for old hardcoded activity documents.
 */

const KNOWN_STUB_ACTIVITY_IDS = [
  'stub-amar-sidequest',
  'stub-nathan-monash',
  'stub-jacob-melbourne',
  'placeholder:journey-to-coles',
];

function parseArgs(argv) {
  const args = {
    projectId: undefined,
    dryRun: true,
    activityIds: KNOWN_STUB_ACTIVITY_IDS,
  };
  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--project') {
      args.projectId = argv[index + 1];
      index += 1;
    } else if (arg === '--execute') {
      args.dryRun = false;
    } else if (arg === '--dry-run') {
      args.dryRun = true;
    } else if (arg === '--activity-id') {
      args.activityIds = [argv[index + 1]];
      index += 1;
    }
  }
  return args;
}

function firestoreFor({ db, projectId }) {
  if (db) return db;
  const admin = require('firebase-admin');
  if (!admin.apps.length) {
    admin.initializeApp(projectId ? { projectId } : undefined);
  }
  return admin.firestore();
}

async function collectionCount(activityRef, name) {
  const snapshot = await activityRef.collection(name).get();
  return snapshot.size ?? snapshot.docs.length;
}

async function cleanupStubActivities({ db, projectId, dryRun = true, activityIds } = {}) {
  const firestore = firestoreFor({ db, projectId });
  const ids = activityIds && activityIds.length
    ? activityIds
    : KNOWN_STUB_ACTIVITY_IDS;
  const results = [];

  for (const activityId of ids) {
    const ref = firestore.collection('activities').doc(activityId);
    const doc = await ref.get();
    const commentsCount = await collectionCount(ref, 'comments');
    const kudosCount = await collectionCount(ref, 'kudos');
    const result = {
      path: `activities/${activityId}`,
      existed: doc.exists === true,
      commentsCount,
      kudosCount,
      deleted: false,
    };
    if (!dryRun && (result.existed || commentsCount > 0 || kudosCount > 0)) {
      await firestore.recursiveDelete(ref);
      result.deleted = true;
    }
    results.push(result);
  }

  return {
    projectId: projectId || '(default credentials project)',
    dryRun,
    activityIds: ids,
    broadlyDeletedActivitiesCollection: false,
    results,
  };
}

if (require.main === module) {
  cleanupStubActivities(parseArgs(process.argv))
    .then((report) => {
      console.log(JSON.stringify(report, null, 2));
      process.exit(0);
    })
    .catch((error) => {
      console.error('[cleanup_stub_activities] failed:', error);
      process.exit(1);
    });
}

module.exports = {
  KNOWN_STUB_ACTIVITY_IDS,
  cleanupStubActivities,
  parseArgs,
};
