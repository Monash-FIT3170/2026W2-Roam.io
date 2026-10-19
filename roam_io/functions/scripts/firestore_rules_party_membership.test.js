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
      joinCode: 'ABC123', name: 'Alice Adventurers', teamAMembers: ['alice'], teamBMembers: [], tiles: {},
    }));
    await assertSucceeds(alice.runTransaction(async (tx) => {
      tx.set(partyOne, {
        joinCode: 'ABC123', name: 'Alice Adventurers', teamAMembers: ['alice'], teamBMembers: [], tiles: {},
      });
      tx.set(aliceMembership, { partyId: 'one' });
    }));
    await assertSucceeds(bob.runTransaction(async (tx) => {
      tx.set(partyTwo, {
        joinCode: 'XYZ789', name: 'Bob Explorers', teamAMembers: ['bob'], teamBMembers: [], tiles: {},
      });
      tx.set(bobMembership, { partyId: 'two' });
    }));

    await env.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('friendships').doc('alice_charlie').set({
        pairKey: 'alice_charlie', memberIds: ['alice', 'charlie'],
        acceptedRequestId: 'alice_charlie', createdAt: new Date().toISOString(),
      });
      await context.firestore().collection('follows').doc('alice_dave').set({
        followerId: 'alice', followeeId: 'dave', createdAt: new Date().toISOString(),
      });
    });
    const charlieInbox = alice.collection('profiles').doc('charlie').collection('notifications');
    const validInvite = {
      recipientId: 'charlie', actorId: 'alice', type: 'partyInvite',
      partyId: 'one', createdAt: new Date().toISOString(), readAt: null,
    };
    await assertSucceeds(charlieInbox.doc('party_invite_one_alice').set(validInvite));
    await assertSucceeds(alice.collection('profiles').doc('dave').collection('notifications')
      .doc('party_invite_one_alice').set({ ...validInvite, recipientId: 'dave' }));
    await assertFails(alice.collection('friendships').doc('alice_dave').get());
    await assertSucceeds(alice.collection('follows').doc('alice_dave').get());
    await assertSucceeds(alice.collection('follow_requests').doc('alice_dave').get());
    await assertFails(alice.collection('follow_requests').doc('alice_dave').delete());
    await env.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('party_memberships').doc('dave').set({ partyId: 'other' });
    });
    await assertFails(alice.collection('profiles').doc('dave').collection('notifications')
      .doc('party_invite_one_alice').set({ ...validInvite, recipientId: 'dave' }));
    await assertFails(charlieInbox.doc('party_invite_one_bob').set({
      ...validInvite, actorId: 'bob',
    }));
    await assertFails(charlieInbox.doc('wrong_id').set(validInvite));
    await assertFails(alice.collection('profiles').doc('mallory').collection('notifications')
      .doc('party_invite_one_alice').set({ ...validInvite, recipientId: 'mallory' }));

    await assertFails(partyOne.update({ teamBMembers: ['mallory'] }));
    await assertSucceeds(partyOne.update({ name: 'New Adventure' }));
    await assertFails(bob.collection('parties').doc('one').update({ name: 'Hijacked' }));
    await assertFails(partyOne.update({ name: ' ' }));
    await assertFails(partyOne.update({ name: 'x'.repeat(41) }));
    await assertFails(partyOne.update({ joinCode: 'CHANGED' }));
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
