/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Backfills public_profiles from authoritative private profiles for
 *   registered-user social search without exposing private account fields.
 *   Mirrors only the safe isPrivateAccount bit needed by Follow Requests.
 */

function normalizeSearchText(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizeUsernameSearchText(value) {
  const normalized = normalizeSearchText(value);
  return normalized.startsWith('@') ? normalized.slice(1) : normalized;
}

function publicProfileFromPrivateProfile(uid, profile, nowIso) {
  const username = typeof profile.username === 'string'
    ? profile.username.trim()
    : '';
  const displayName = typeof profile.displayName === 'string'
    ? profile.displayName.trim()
    : '';

  if (!uid) {
    return { publicProfile: null, skipReason: 'missing_uid' };
  }
  if (!username) {
    return { publicProfile: null, skipReason: 'missing_username' };
  }
  if (!displayName) {
    return { publicProfile: null, skipReason: 'missing_display_name' };
  }

  const publicProfile = {
    uid,
    username,
    usernameSearch: normalizeUsernameSearchText(username),
    displayName,
    displayNameSearch: normalizeSearchText(displayName),
    isPrivateAccount: profile.privacy?.isPrivateAccount === true,
    createdAt: typeof profile.createdAt === 'string'
      ? profile.createdAt
      : nowIso,
    updatedAt: nowIso,
  };

  if (typeof profile.photoUrl === 'string' && profile.photoUrl.trim()) {
    publicProfile.photoUrl = profile.photoUrl;
  }
  if (Number.isInteger(profile.xp)) {
    publicProfile.xp = profile.xp;
  }
  if (Number.isInteger(profile.level)) {
    publicProfile.level = profile.level;
  }

  return { publicProfile, skipReason: null };
}

function hasPublicProfileChanged(existing, next) {
  const keys = new Set([...Object.keys(existing || {}), ...Object.keys(next)]);
  for (const key of keys) {
    if (key === 'updatedAt') continue;
    if (existing?.[key] !== next[key]) {
      return true;
    }
  }
  return false;
}

async function backfillPublicProfiles({ projectId, dryRun = false } = {}) {
  const admin = require('firebase-admin');

  if (!admin.apps.length) {
    admin.initializeApp(projectId ? { projectId } : undefined);
  }

  const db = admin.firestore();
  const profiles = await db.collection('profiles').get();
  const publicProfilesBefore = await db.collection('public_profiles').get();
  const nowIso = new Date().toISOString();
  const stats = {
    profilesCount: profiles.size,
    publicProfilesBefore: publicProfilesBefore.size,
    inspected: 0,
    valid: 0,
    created: 0,
    updated: 0,
    unchanged: 0,
    skipped: 0,
    skippedByReason: {},
  };

  let batch = db.batch();
  let pendingWrites = 0;

  async function commitIfNeeded(force = false) {
    if (pendingWrites === 0 || (!force && pendingWrites < 450)) return;
    if (!dryRun) {
      await batch.commit();
    }
    batch = db.batch();
    pendingWrites = 0;
  }

  for (const doc of profiles.docs) {
    stats.inspected += 1;
    const { publicProfile, skipReason } = publicProfileFromPrivateProfile(
      doc.id,
      doc.data(),
      nowIso,
    );

    if (!publicProfile) {
      stats.skipped += 1;
      stats.skippedByReason[skipReason] =
        (stats.skippedByReason[skipReason] || 0) + 1;
      continue;
    }
    stats.valid += 1;

    const publicRef = db.collection('public_profiles').doc(doc.id);
    const publicDoc = await publicRef.get();

    if (!publicDoc.exists) {
      stats.created += 1;
      batch.set(publicRef, publicProfile, { merge: true });
      pendingWrites += 1;
      await commitIfNeeded();
      continue;
    }

    if (hasPublicProfileChanged(publicDoc.data(), publicProfile)) {
      stats.updated += 1;
      batch.set(publicRef, publicProfile, { merge: true });
      pendingWrites += 1;
      await commitIfNeeded();
    } else {
      stats.unchanged += 1;
    }
  }

  await commitIfNeeded(true);
  const publicProfilesAfter = dryRun
    ? publicProfilesBefore
    : await db.collection('public_profiles').get();
  stats.publicProfilesAfter = publicProfilesAfter.size;
  return stats;
}

function parseArgs(argv) {
  const args = { projectId: undefined, dryRun: false };
  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--dry-run') {
      args.dryRun = true;
    } else if (arg === '--project') {
      args.projectId = argv[index + 1];
      index += 1;
    }
  }
  return args;
}

if (require.main === module) {
  const args = parseArgs(process.argv);
  backfillPublicProfiles(args)
    .then((stats) => {
      console.log(JSON.stringify(stats, null, 2));
      process.exit(0);
    })
    .catch((error) => {
      console.error('[backfill_public_profiles] failed:', error);
      process.exit(1);
    });
}

module.exports = {
  backfillPublicProfiles,
  hasPublicProfileChanged,
  normalizeSearchText,
  normalizeUsernameSearchText,
  publicProfileFromPrivateProfile,
};
