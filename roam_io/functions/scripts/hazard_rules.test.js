const fs = require('node:fs');
const path = require('node:path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const { deleteObject, getDownloadURL, ref, uploadString } = require('firebase/storage');

const projectId = 'roam-io-71e2c';
const firestoreRules = fs.readFileSync(
  path.resolve(__dirname, '../../firestore.rules'),
  'utf8',
);
const storageRules = fs.readFileSync(
  path.resolve(__dirname, '../../storage.rules'),
  'utf8',
);

function hazard(overrides = {}) {
  const now = new Date();
  return {
    reporterId: 'owner',
    category: 'pothole',
    latitude: -37.8136,
    longitude: 144.9631,
    description: 'Deep pothole',
    createdAt: now,
    lastConfirmedAt: now,
    expiresAt: new Date(now.getTime() + 60 * 60 * 1000),
    ...overrides,
  };
}

async function run() {
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules: firestoreRules },
    storage: { rules: storageRules },
  });

  try {
    const owner = testEnv.authenticatedContext('owner');
    const viewer = testEnv.authenticatedContext('viewer');
    const anonymous = testEnv.unauthenticatedContext();
    const ownerDoc = owner.firestore().collection('hazards').doc('hazard-1');

    await assertSucceeds(ownerDoc.set(hazard()));
    await assertSucceeds(viewer.firestore().collection('hazards').doc('hazard-1').get());
    await assertFails(anonymous.firestore().collection('hazards').doc('hazard-1').get());
    await assertFails(
      viewer.firestore().collection('hazards').doc('impersonated').set(hazard()),
    );
    await assertFails(
      owner.firestore().collection('hazards').doc('bad-category').set(
        hazard({ category: 'dragon' }),
      ),
    );
    await assertFails(
      owner.firestore().collection('hazards').doc('too-long').set(
        hazard({ expiresAt: new Date(Date.now() + 13 * 60 * 60 * 1000) }),
      ),
    );

    const confirmedAt = new Date();
    const viewerDoc = viewer.firestore().collection('hazards').doc('hazard-1');
    await assertSucceeds(
      viewerDoc.update({
        lastConfirmedAt: confirmedAt,
        expiresAt: new Date(confirmedAt.getTime() + 60 * 60 * 1000),
      }),
    );
    await assertFails(viewerDoc.update({ category: 'flooding' }));
    await assertFails(viewerDoc.delete());

    const ownerPhoto = ref(owner.storage(), 'hazard_photos/owner/photo.jpg');
    const viewerPhoto = ref(viewer.storage(), 'hazard_photos/owner/photo.jpg');
    await assertSucceeds(uploadString(ownerPhoto, 'photo-bytes'));
    await assertSucceeds(getDownloadURL(viewerPhoto));
    await assertFails(uploadString(viewerPhoto, 'overwrite'));
    await assertFails(deleteObject(viewerPhoto));
    await assertSucceeds(deleteObject(ownerPhoto));

    console.log('passed: community hazard Firestore and Storage rules');
  } finally {
    await testEnv.cleanup();
  }
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
