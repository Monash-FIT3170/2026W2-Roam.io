/*
 * Description:
 *   Party Mode dwell-time ping recording and per-tile team ownership.
 *   Elapsed dwell time is computed server-side from consecutive pings by the
 *   same user in the same tile, never trusting a client-reported duration.
 */

function tileRef({ db, partyId, tileId }) {
  return db
    .collection('parties')
    .doc(partyId)
    .collection('tiles')
    .doc(tileId);
}

async function recordDwellPing({ db, partyId, tileId, uid, team, pingAt }) {
  const ref = tileRef({ db, partyId, tileId });
  const existing = await ref.get();
  const data = existing.exists
    ? existing.data()
    : { teamADwellSeconds: 0, teamBDwellSeconds: 0, lastPingByUser: {} };

  const previous = data.lastPingByUser[uid];
  if (previous && previous.team === team) {
    const elapsedSeconds =
      (pingAt.getTime() - new Date(previous.pingAt).getTime()) / 1000;
    if (elapsedSeconds > 0) {
      const key = team === 'A' ? 'teamADwellSeconds' : 'teamBDwellSeconds';
      data[key] += elapsedSeconds;
    }
  }

  data.lastPingByUser[uid] = { team, pingAt: pingAt.toISOString() };

  await ref.set(data);
  return data;
}

const CLAIM_GATE_SECONDS = 5 * 60;

/// Pure ownership derivation from a tile's stored dwell counters, shared by
/// getTileOwnership (reads live data) and the tile-flip notification trigger
/// (compares before/after snapshots without a re-read).
function deriveOwnership(data) {
  if (!data) return null;
  const aEligible = data.teamADwellSeconds > CLAIM_GATE_SECONDS;
  const bEligible = data.teamBDwellSeconds > CLAIM_GATE_SECONDS;

  if (!aEligible && !bEligible) return null;
  if (aEligible && !bEligible) return 'A';
  if (bEligible && !aEligible) return 'B';
  return data.teamADwellSeconds >= data.teamBDwellSeconds ? 'A' : 'B';
}

async function getTileOwnership({ db, partyId, tileId }) {
  const ref = tileRef({ db, partyId, tileId });
  const existing = await ref.get();
  return existing.exists ? deriveOwnership(existing.data()) : null;
}

/// Server-trusted team lookup: never trust a client-claimed team, always
/// resolve it from the party roster.
async function resolvePingTeam({ db, partyId, uid }) {
  const partyDoc = await db.collection('parties').doc(partyId).get();
  if (!partyDoc.exists) {
    throw new Error(`Party "${partyId}" not found`);
  }
  const party = partyDoc.data();
  if ((party.teamAMembers || []).includes(uid)) return 'A';
  if ((party.teamBMembers || []).includes(uid)) return 'B';
  throw new Error(`User "${uid}" is not a member of party "${partyId}"`);
}

module.exports = {
  recordDwellPing,
  getTileOwnership,
  deriveOwnership,
  resolvePingTeam,
};
