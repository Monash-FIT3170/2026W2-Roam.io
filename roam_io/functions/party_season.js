/*
 * Description:
 *   Fortnightly Party Mode season reset: summarizes tile ownership into a
 *   persisted season record, then wipes tile ownership/dwell counters so the
 *   next season starts clean.
 */

const { deriveOwnership } = require('./party_dwell');

async function resetPartySeason({ db, partyId, now }) {
  const partyRef = db.collection('parties').doc(partyId);
  const partyDoc = await partyRef.get();
  const party = partyDoc.data();

  const tilesCollection = partyRef.collection('tiles');
  const tilesSnapshot = await tilesCollection.get();

  let teamATileCount = 0;
  let teamBTileCount = 0;
  for (const doc of tilesSnapshot.docs) {
    const owner = deriveOwnership(doc.data());
    if (owner === 'A') teamATileCount += 1;
    if (owner === 'B') teamBTileCount += 1;
  }

  const winner =
    teamATileCount === teamBTileCount
      ? null
      : teamATileCount > teamBTileCount
        ? 'A'
        : 'B';

  const nowIso = now.toISOString();
  const summary = {
    teamAMembers: party.teamAMembers,
    teamBMembers: party.teamBMembers,
    teamATileCount,
    teamBTileCount,
    winner,
    startAt: party.currentSeasonStartAt,
    endAt: nowIso,
  };

  await partyRef.collection('seasons').doc().set(summary);

  for (const doc of tilesSnapshot.docs) {
    await doc.ref.delete();
  }
  await partyRef.set(
    { ...party, currentSeasonStartAt: nowIso },
  );

  return summary;
}

const SEASON_LENGTH_DAYS = 14;

/// Whether a party's current season has run its full 14-day cadence.
/// Parties with no recorded start (not yet seeded) are never due.
function isSeasonDue({ party, now, seasonLengthDays = SEASON_LENGTH_DAYS }) {
  if (!party || !party.currentSeasonStartAt) return false;
  const elapsedMs = now.getTime() - new Date(party.currentSeasonStartAt).getTime();
  return elapsedMs >= seasonLengthDays * 24 * 60 * 60 * 1000;
}

/// Resets every party whose season has run its 14-day cadence.
async function runDueSeasonResets({ db, now, seasonLengthDays = SEASON_LENGTH_DAYS }) {
  const partiesSnapshot = await db.collection('parties').get();
  const results = [];

  for (const doc of partiesSnapshot.docs) {
    if (isSeasonDue({ party: doc.data(), now, seasonLengthDays })) {
      results.push(await resetPartySeason({ db, partyId: doc.id, now }));
    }
  }

  return results;
}

module.exports = { resetPartySeason, isSeasonDue, runDueSeasonResets };
