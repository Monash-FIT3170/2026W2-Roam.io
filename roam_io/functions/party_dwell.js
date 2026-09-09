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

async function getTileOwnership({ db, partyId, tileId }) {
  const ref = tileRef({ db, partyId, tileId });
  const existing = await ref.get();
  if (!existing.exists) return null;

  const data = existing.data();
  const aEligible = data.teamADwellSeconds > CLAIM_GATE_SECONDS;
  const bEligible = data.teamBDwellSeconds > CLAIM_GATE_SECONDS;

  if (!aEligible && !bEligible) return null;
  if (aEligible && !bEligible) return 'A';
  if (bEligible && !aEligible) return 'B';
  return data.teamADwellSeconds >= data.teamBDwellSeconds ? 'A' : 'B';
}

module.exports = { recordDwellPing, getTileOwnership };
