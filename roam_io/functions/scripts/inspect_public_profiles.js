/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Inspects the private profiles collection and public_profiles projection
 *   for safe social-search diagnostics without logging private profile fields.
 */

const {
  normalizeSearchText,
  normalizeUsernameSearchText,
} = require('./backfill_public_profiles');

function parseArgs(argv) {
  const args = {
    projectId: undefined,
    username: 'jacob_delapaz',
    samples: 4,
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--project') {
      args.projectId = argv[index + 1];
      index += 1;
    } else if (arg === '--username') {
      args.username = argv[index + 1];
      index += 1;
    } else if (arg === '--samples') {
      args.samples = Number.parseInt(argv[index + 1], 10);
      index += 1;
    }
  }

  return args;
}

function publicProfileSummary(uid, data) {
  if (!data) return null;
  const photoUrl = typeof data.photoUrl === 'string' ? data.photoUrl.trim() : '';
  return {
    uid,
    displayName: data.displayName,
    displayNameSearch: data.displayNameSearch,
    username: data.username,
    usernameSearch: data.usernameSearch,
    hasPhotoUrl: photoUrl.length > 0,
    photoUrlFormat: describePhotoUrl(photoUrl),
    xp: Number.isInteger(data.xp) ? data.xp : null,
    level: Number.isInteger(data.level) ? data.level : null,
  };
}

function privateProfileSummary(uid, data) {
  if (!data) return null;
  const photoUrl = typeof data.photoUrl === 'string' ? data.photoUrl.trim() : '';
  return {
    uid,
    displayName: data.displayName,
    username: data.username,
    hasPhotoUrl: photoUrl.length > 0,
    photoUrlFormat: describePhotoUrl(photoUrl),
    xp: Number.isInteger(data.xp) ? data.xp : null,
    level: Number.isInteger(data.level) ? data.level : null,
  };
}

function describePhotoUrl(value) {
  if (!value) return 'missing';
  if (value.startsWith('https://')) return 'https';
  if (value.startsWith('http://')) return 'http';
  if (value.startsWith('gs://')) return 'gs';
  try {
    const parsed = new URL(value);
    return parsed.protocol.replace(':', '') || 'malformed';
  } catch (_) {
    return 'storage_path';
  }
}

async function prefixQuery(db, field, value, limit = 10) {
  const snapshot = await db
    .collection('public_profiles')
    .orderBy(field)
    .startAt(value)
    .endAt(`${value}\uf8ff`)
    .limit(limit)
    .get();

  return snapshot.docs.map((doc) => publicProfileSummary(doc.id, doc.data()));
}

async function inspectPublicProfiles({
  projectId,
  username = 'jacob_delapaz',
  samples = 4,
} = {}) {
  const admin = require('firebase-admin');

  if (!admin.apps.length) {
    admin.initializeApp(projectId ? { projectId } : undefined);
  }

  const db = admin.firestore();
  const profilesSnapshot = await db.collection('profiles').get();
  const publicProfilesSnapshot = await db.collection('public_profiles').get();
  const normalizedUsername = normalizeUsernameSearchText(username);

  const matchingProfiles = profilesSnapshot.docs
    .map((doc) => privateProfileSummary(doc.id, doc.data()))
    .filter((profile) => {
      return normalizeUsernameSearchText(profile.username) === normalizedUsername;
    });

  const profileSamples = profilesSnapshot.docs
    .map((doc) => privateProfileSummary(doc.id, doc.data()))
    .filter((profile) => {
      return profile.username && profile.displayName;
    })
    .slice(0, samples);

  const publicMatches = [];
  for (const profile of matchingProfiles) {
    const publicDoc = await db.collection('public_profiles').doc(profile.uid).get();
    publicMatches.push({
      profile,
      publicProfileExists: publicDoc.exists,
      publicProfile: publicProfileSummary(profile.uid, publicDoc.data()),
    });
  }

  const verifiedSamples = [];
  for (const profile of profileSamples) {
    const publicDoc = await db.collection('public_profiles').doc(profile.uid).get();
    const usernameQuery = await prefixQuery(
      db,
      'usernameSearch',
      normalizeUsernameSearchText(profile.username),
      5,
    );
    const displayQuery = await prefixQuery(
      db,
      'displayNameSearch',
      normalizeSearchText(profile.displayName),
      5,
    );
    verifiedSamples.push({
      profile,
      publicProfileExists: publicDoc.exists,
      publicProfile: publicProfileSummary(profile.uid, publicDoc.data()),
      photoUrlProjectionMatches:
        (profile.hasPhotoUrl === (typeof publicDoc.data()?.photoUrl === 'string' &&
          publicDoc.data().photoUrl.trim().length > 0)) &&
        profile.photoUrlFormat === describePhotoUrl(
          typeof publicDoc.data()?.photoUrl === 'string'
            ? publicDoc.data().photoUrl.trim()
            : '',
        ),
      usernameQueryReturnedUid: usernameQuery.some((hit) => hit.uid === profile.uid),
      displayNameQueryReturnedUid: displayQuery.some((hit) => hit.uid === profile.uid),
    });
  }

  return {
    projectId: projectId || '(default credentials project)',
    profilesCount: profilesSnapshot.size,
    publicProfilesExists: publicProfilesSnapshot.size > 0,
    publicProfilesCount: publicProfilesSnapshot.size,
    requestedUsername: username,
    normalizedUsername,
    matchingProfiles,
    publicMatches,
    directUsernamePrefixResults: await prefixQuery(
      db,
      'usernameSearch',
      normalizedUsername,
    ),
    verifiedSamples,
  };
}

if (require.main === module) {
  inspectPublicProfiles(parseArgs(process.argv))
    .then((report) => {
      console.log(JSON.stringify(report, null, 2));
      process.exit(0);
    })
    .catch((error) => {
      console.error('[inspect_public_profiles] failed:', error);
      process.exit(1);
    });
}

module.exports = {
  describePhotoUrl,
  inspectPublicProfiles,
  parseArgs,
  prefixQuery,
};
