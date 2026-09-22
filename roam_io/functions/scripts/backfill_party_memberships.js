/*
 * One-time migration for parties created before party_memberships existed.
 * Dry-run by default. Run with --apply before deploying the new party rules.
 * If a user is in several old rosters, keep their existing membership pointer
 * when valid, otherwise keep the party with the lowest document ID.
 */

function planMemberships(parties, memberships) {
  const byUser = new Map();
  for (const party of parties) {
    for (const uid of [...(party.teamAMembers || []), ...(party.teamBMembers || [])]) {
      if (typeof uid !== 'string' || !uid) continue;
      if (!byUser.has(uid)) byUser.set(uid, new Set());
      byUser.get(uid).add(party.id);
    }
  }

  const plan = [];
  for (const [uid, partyIds] of byUser) {
    const ids = [...partyIds].sort();
    const current = memberships.get(uid);
    const keep = ids.includes(current) ? current : ids[0];
    if (current !== keep || ids.length > 1) {
      plan.push({ uid, keep, expectedCurrent: current || null, removeFrom: ids.filter((id) => id !== keep) });
    }
  }
  for (const [uid] of memberships) {
    if (!byUser.has(uid)) plan.push({ uid, keep: null, expectedCurrent: memberships.get(uid), removeFrom: [] });
  }
  return plan.sort((a, b) => a.uid.localeCompare(b.uid));
}

async function backfill({ projectId, apply = false } = {}) {
  if (!projectId) throw new Error('--project is required');
  const admin = require('firebase-admin');
  if (!admin.apps.length) admin.initializeApp({ projectId });
  const db = admin.firestore();
  const [partySnapshot, membershipSnapshot] = await Promise.all([
    db.collection('parties').get(),
    db.collection('party_memberships').get(),
  ]);
  const parties = partySnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const memberships = new Map(membershipSnapshot.docs.map(
    (doc) => [doc.id, doc.data().partyId],
  ));
  const plan = planMemberships(parties, memberships);

  if (apply) {
    for (const item of plan) {
      await db.runTransaction(async (tx) => {
        const membershipRef = db.collection('party_memberships').doc(item.uid);
        const partyRefs = item.removeFrom.map((id) => db.collection('parties').doc(id));
        const [membership, ...partyDocs] = await Promise.all([
          tx.get(membershipRef),
          ...partyRefs.map((ref) => tx.get(ref)),
        ]);
        const current = membership.data()?.partyId;
        if ((current || null) !== item.expectedCurrent) {
          throw new Error(`Membership changed for ${item.uid}; rerun the dry-run`);
        }
        for (let index = 0; index < partyDocs.length; index += 1) {
          const data = partyDocs[index].data();
          if (!data) continue;
          tx.update(partyRefs[index], {
            teamAMembers: (data.teamAMembers || []).filter((uid) => uid !== item.uid),
            teamBMembers: (data.teamBMembers || []).filter((uid) => uid !== item.uid),
          });
        }
        if (item.keep) tx.set(membershipRef, { partyId: item.keep });
        else if (membership.exists) tx.delete(membershipRef);
      });
    }
  }
  return { projectId, applied: apply, affectedUsers: plan.length, plan };
}

if (require.main === module) {
  const args = process.argv.slice(2);
  const projectIndex = args.indexOf('--project');
  backfill({
    projectId: projectIndex >= 0 ? args[projectIndex + 1] : undefined,
    apply: args.includes('--apply'),
  }).then((report) => {
    console.log(JSON.stringify(report, null, 2));
  }).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = { planMemberships, backfill };
