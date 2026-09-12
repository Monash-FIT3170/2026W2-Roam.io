const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const rules = fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8');

async function run() {
  const env = await initializeTestEnvironment({
    projectId: 'demo-roam-party-membership',
    firestore: { rules },
  });
  try {
    const alice = env.authenticatedContext('alice').firestore();
    const bob = env.authenticatedContext('bob').firestore();
    const partyOne = alice.collection('parties').doc('one');
    const partyTwo = bob.collection('parties').doc('two');
    const partyTwoForAlice = alice.collection('parties').doc('two');
    const aliceMembership = alice.collection('party_memberships').doc('alice');
    const bobMembership = bob.collection('party_memberships').doc('bob');

    await assertFails(partyOne.set({
      joinCode: 'ABC123', teamAMembers: ['alice'], teamBMembers: [], tiles: {},
    }));
    await assertSucceeds(alice.runTransaction(async (tx) => {
      tx.set(partyOne, {
        joinCode: 'ABC123', teamAMembers: ['alice'], teamBMembers: [], tiles: {},
      });
      tx.set(aliceMembership, { partyId: 'one' });
    }));
    await assertSucceeds(bob.runTransaction(async (tx) => {
      tx.set(partyTwo, {
        joinCode: 'XYZ789', teamAMembers: ['bob'], teamBMembers: [], tiles: {},
      });
      tx.set(bobMembership, { partyId: 'two' });
    }));

    await assertFails(partyOne.update({ teamBMembers: ['mallory'] }));
    await assertFails(aliceMembership.set({ partyId: 'two' }));
    await assertFails(alice.runTransaction(async (tx) => {
      tx.update(partyTwoForAlice, { teamBMembers: ['alice'] });
      tx.set(aliceMembership, { partyId: 'two' });
    }));
    await assertSucceeds(alice.runTransaction(async (tx) => {
      tx.update(partyOne, { teamAMembers: [] });
      tx.delete(aliceMembership);
    }));
    await assertSucceeds(alice.runTransaction(async (tx) => {
      tx.update(partyTwoForAlice, { teamBMembers: ['alice'] });
      tx.set(aliceMembership, { partyId: 'two' });
    }));

    assert.deepEqual((await partyTwo.get()).data().teamBMembers, ['alice']);
    assert.deepEqual((await aliceMembership.get()).data(), { partyId: 'two' });

    await env.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('parties').doc('legacy').set({
        joinCode: 'LEGACY', teamAMembers: ['charlie'], teamBMembers: [], tiles: {},
      });
    });
    const charlie = env.authenticatedContext('charlie').firestore();
    await assertFails(bob.collection('parties').doc('legacy').update({ teamAMembers: [] }));
    await assertSucceeds(charlie.collection('parties').doc('legacy').update({ teamAMembers: [] }));
    console.log('passed: one-party membership rules');
  } finally {
    await env.cleanup();
  }
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
