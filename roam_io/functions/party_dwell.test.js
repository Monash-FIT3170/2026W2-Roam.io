/*
 * Description:
 *   Unit tests for Party Mode dwell-time ping recording and tile ownership.
 */

const assert = require('node:assert/strict');
const { recordDwellPing, getTileOwnership, resolvePingTeam } = require('./party_dwell');

// Minimal Firestore-like fake: a flat path->data store, addressed by
// chained collection()/doc() calls, mirroring the existing scripts/*.test.js fakes.
class FakeDoc {
  constructor(path, store) {
    this.path = path;
    this.store = store;
  }

  async get() {
    const data = this.store[this.path];
    return { exists: data !== undefined, data: () => data };
  }

  async set(data, opts) {
    if (opts && opts.merge) {
      this.store[this.path] = { ...(this.store[this.path] || {}), ...data };
    } else {
      this.store[this.path] = data;
    }
  }

  collection(name) {
    return new FakeCollection(`${this.path}/${name}`, this.store);
  }
}

class FakeCollection {
  constructor(path, store) {
    this.path = path;
    this.store = store;
  }

  doc(id) {
    return new FakeDoc(`${this.path}/${id}`, this.store);
  }
}

class FakeDb {
  constructor(store = {}) {
    this.store = store;
  }

  collection(name) {
    return new FakeCollection(name, this.store);
  }
}

(async () => {
  const db = new FakeDb();

  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u1',
    team: 'A',
    pingAt: new Date('2026-01-01T00:00:00Z'),
  });

  const tileDoc = await db
    .collection('parties')
    .doc('p1')
    .collection('tiles')
    .doc('t1')
    .get();
  const data = tileDoc.data();

  assert.equal(data.teamADwellSeconds, 0);
  assert.equal(data.teamBDwellSeconds, 0);
  assert.equal(
    data.lastPingByUser.u1.pingAt,
    '2026-01-01T00:00:00.000Z',
  );
  assert.equal(data.lastPingByUser.u1.team, 'A');
})();

(async () => {
  const db = new FakeDb();

  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u1',
    team: 'A',
    pingAt: new Date('2026-01-01T00:00:00Z'),
  });
  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u1',
    team: 'A',
    pingAt: new Date('2026-01-01T00:01:00Z'),
  });

  const tileDoc = await db
    .collection('parties')
    .doc('p1')
    .collection('tiles')
    .doc('t1')
    .get();
  const data = tileDoc.data();

  assert.equal(data.teamADwellSeconds, 60);
  assert.equal(data.teamBDwellSeconds, 0);
})();

(async () => {
  const db = new FakeDb();

  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u1',
    team: 'A',
    pingAt: new Date('2026-01-01T00:00:00Z'),
  });
  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u2',
    team: 'B',
    pingAt: new Date('2026-01-01T00:00:00Z'),
  });
  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u1',
    team: 'A',
    pingAt: new Date('2026-01-01T00:01:00Z'),
  });
  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u2',
    team: 'B',
    pingAt: new Date('2026-01-01T00:00:30Z'),
  });

  const tileDoc = await db
    .collection('parties')
    .doc('p1')
    .collection('tiles')
    .doc('t1')
    .get();
  const data = tileDoc.data();

  assert.equal(data.teamADwellSeconds, 60);
  assert.equal(data.teamBDwellSeconds, 30);
})();

(async () => {
  const db = new FakeDb();

  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u1',
    team: 'A',
    pingAt: new Date('2026-01-01T00:00:00Z'),
  });
  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u1',
    team: 'A',
    pingAt: new Date('2026-01-01T00:00:15Z'), // 15s, under the 30s gate
  });

  const owner = await getTileOwnership({ db, partyId: 'p1', tileId: 't1' });

  assert.equal(owner, null);
})();

(async () => {
  const db = new FakeDb();

  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u1',
    team: 'A',
    pingAt: new Date('2026-01-01T00:00:00Z'),
  });
  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u1',
    team: 'A',
    pingAt: new Date('2026-01-01T00:00:45Z'), // 45s, past the 30s gate
  });

  const owner = await getTileOwnership({ db, partyId: 'p1', tileId: 't1' });

  assert.equal(owner, 'A');
})();

(async () => {
  const db = new FakeDb();

  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u1',
    team: 'A',
    pingAt: new Date('2026-01-01T00:00:00Z'),
  });
  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u2',
    team: 'B',
    pingAt: new Date('2026-01-01T00:00:00Z'),
  });
  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u1',
    team: 'A',
    pingAt: new Date('2026-01-01T00:06:40Z'), // 400s for A, past the gate
  });
  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u2',
    team: 'B',
    pingAt: new Date('2026-01-01T00:08:20Z'), // 500s for B, past the gate
  });

  const beforeFlip = await getTileOwnership({
    db,
    partyId: 'p1',
    tileId: 't1',
  });
  assert.equal(beforeFlip, 'B');

  // A closes the gap past B's total with one more ping; ownership flips live.
  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u1',
    team: 'A',
    pingAt: new Date('2026-01-01T00:15:00Z'), // +800s, A total now 1200s
  });

  const afterFlip = await getTileOwnership({
    db,
    partyId: 'p1',
    tileId: 't1',
  });
  assert.equal(afterFlip, 'A');
})();

(async () => {
  const db = new FakeDb();

  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u1',
    team: 'A',
    pingAt: new Date('2026-01-01T00:00:00Z'),
  });
  await recordDwellPing({
    db,
    partyId: 'p1',
    tileId: 't1',
    uid: 'u1',
    team: 'A',
    pingAt: new Date('2026-01-01T00:06:00Z'), // 360s, past the gate
  });

  // Repeated ownership reads, with no new pings in between, must not
  // decay or otherwise mutate the stored counters.
  await getTileOwnership({ db, partyId: 'p1', tileId: 't1' });
  await getTileOwnership({ db, partyId: 'p1', tileId: 't1' });

  const tileDoc = await db
    .collection('parties')
    .doc('p1')
    .collection('tiles')
    .doc('t1')
    .get();

  assert.equal(tileDoc.data().teamADwellSeconds, 360);
})();

(async () => {
  const db = new FakeDb({
    'parties/p1': { teamAMembers: ['u1'], teamBMembers: ['u2'] },
  });

  const team = await resolvePingTeam({ db, partyId: 'p1', uid: 'u1' });

  assert.equal(team, 'A');
})();

(async () => {
  const db = new FakeDb({
    'parties/p1': { teamAMembers: ['u1'], teamBMembers: ['u2'] },
  });

  await assert.rejects(() =>
    resolvePingTeam({ db, partyId: 'p1', uid: 'not-a-member' }),
  );

  console.log('party_dwell.test.js: all assertions passed');
})();
