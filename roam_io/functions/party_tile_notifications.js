/*
 * Description:
 *   Writes an in-app inbox notification to every member of a team when a
 *   Party Mode tile flips away from them, reusing the follow-notification
 *   schema at profiles/{uid}/notifications/{id}.
 */

const { deriveOwnership } = require('./party_dwell');

async function notifyTileFlip({ db, partyId, tileId, beforeData, afterData }) {
  const before = deriveOwnership(beforeData);
  const after = deriveOwnership(afterData);

  if (before === after || before === null) return;

  const partyDoc = await db.collection('parties').doc(partyId).get();
  if (!partyDoc.exists) return;
  const party = partyDoc.data();
  const losingTeamMembers =
    before === 'A' ? party.teamAMembers : party.teamBMembers;

  const notificationId = `party_tile_lost_${partyId}_${tileId}`;
  const createdAt = new Date().toISOString();

  for (const uid of losingTeamMembers || []) {
    await db
      .collection('profiles')
      .doc(uid)
      .collection('notifications')
      .doc(notificationId)
      .set({
        recipientId: uid,
        actorId: null,
        type: 'partyTileLost',
        partyId,
        tileId,
        createdAt,
        readAt: null,
      });
  }
}

module.exports = { notifyTileFlip };
