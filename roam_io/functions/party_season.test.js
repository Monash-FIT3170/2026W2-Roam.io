/*
 * Description:
 *   Unit tests for Party Mode fortnightly season reset and summarization.
 */

const assert = require('node:assert/strict');
const { resetPartySeason } = require('./party_season');

// Minimal Firestore-like fake supporting doc get/set/delete and collection
// listing, matching the fakes used in party_dwell.test.js / party_tile_notifications.test.js.
class FakeDoc {
  constructor(path, store) {
    this.path = path;
    this.store = store;
    this.id = path.split('/').pop();
  }

  async get() {
    const data = this.store[this.path];
    return { exists: data !== undefined, id: this.id, data: () => data };
  }

  async set(data) {
    this.store[this.path] = data;
  }

  async delete() {
    delete this.store[this.path];
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
    const docId = id ?? `auto-${Object.keys(this.store).length}`;
    return new FakeDoc(`${this.path}/${docId}`, this.store);
  }

  async get() {
    const prefix = `${this.path}/`;
    const docs = Object.keys(this.store)
      .filter((path) => path.startsWith(prefix) && !path.slice(prefix.length).includes('/'))
      .map((path) => {
        const id = path.slice(prefix.length);
        return { id, ref: new FakeDoc(path, this.store), data: () => this.store[path] };
      });
    return { docs };
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
  const db = new FakeDb({
    'parties/p1': { teamAMembers: ['u1'], teamBMembers: ['u2'] },
  });

  const summary = await resetPartySeason({
    db,
    partyId: 'p1',
    now: new Date('2026-09-09T00:00:00Z'),
  });

  assert.equal(summary.teamATileCount, 0);
  assert.equal(summary.teamBTileCount, 0);
  assert.equal(summary.winner, null);
})();

(async () => {
  const db = new FakeDb({
    'parties/p1': { teamAMembers: ['u1'], teamBMembers: ['u2'] },
    'parties/p1/tiles/t1': { teamADwellSeconds: 400, teamBDwellSeconds: 0 },
    'parties/p1/tiles/t2': { teamADwellSeconds: 0, teamBDwellSeconds: 400 },
    'parties/p1/tiles/t3': { teamADwellSeconds: 500, teamBDwellSeconds: 0 },
  });

  const summary = await resetPartySeason({
    db,
    partyId: 'p1',
    now: new Date('2026-09-09T00:00:00Z'),
  });

  assert.equal(summary.teamATileCount, 2);
  assert.equal(summary.teamBTileCount, 1);
  assert.equal(summary.winner, 'A');
})();

(async () => {
  const db = new FakeDb({
    'parties/p1': { teamAMembers: ['u1'], teamBMembers: ['u2'] },
    'parties/p1/tiles/t1': { teamADwellSeconds: 400, teamBDwellSeconds: 0 },
    'parties/p1/tiles/t2': { teamADwellSeconds: 0, teamBDwellSeconds: 400 },
  });

  const summary = await resetPartySeason({
    db,
    partyId: 'p1',
    now: new Date('2026-09-09T00:00:00Z'),
  });

  assert.equal(summary.teamATileCount, 1);
  assert.equal(summary.teamBTileCount, 1);
  assert.equal(summary.winner, null);
})();

(async () => {
  const db = new FakeDb({
    'parties/p1': {
      teamAMembers: ['u1'],
      teamBMembers: ['u2'],
      currentSeasonStartAt: '2026-08-26T00:00:00.000Z',
    },
    'parties/p1/tiles/t1': { teamADwellSeconds: 400, teamBDwellSeconds: 0 },
  });

  await resetPartySeason({
    db,
    partyId: 'p1',
    now: new Date('2026-09-09T00:00:00Z'),
  });

  const tilesAfter = await db
    .collection('parties')
    .doc('p1')
    .collection('tiles')
    .get();
  assert.equal(tilesAfter.docs.length, 0, 'tiles should be wiped');

  const seasonsAfter = await db
    .collection('parties')
    .doc('p1')
    .collection('seasons')
    .get();
  assert.equal(seasonsAfter.docs.length, 1);
  const persisted = seasonsAfter.docs[0].data();
  assert.deepEqual(persisted.teamAMembers, ['u1']);
  assert.deepEqual(persisted.teamBMembers, ['u2']);
  assert.equal(persisted.teamATileCount, 1);
  assert.equal(persisted.teamBTileCount, 0);
  assert.equal(persisted.winner, 'A');
  assert.equal(persisted.startAt, '2026-08-26T00:00:00.000Z');
  assert.equal(persisted.endAt, '2026-09-09T00:00:00.000Z');
  assert.deepEqual(
    Object.keys(persisted).sort(),
    [
      'endAt',
      'startAt',
      'teamAMembers',
      'teamATileCount',
      'teamBMembers',
      'teamBTileCount',
      'winner',
    ],
    'season summary must only carry team-level fields, no per-tile/per-user breakdown',
  );

  console.log('party_season.test.js: all assertions passed');
})();
