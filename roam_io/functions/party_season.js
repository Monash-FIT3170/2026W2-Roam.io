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

module.exports = { resetPartySeason };
