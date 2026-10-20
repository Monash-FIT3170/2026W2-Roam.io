/*
 * Description:
 *   Unit tests for Party Mode tile-loss in-app notifications.
 */

const assert = require('node:assert/strict');
const { notifyTileFlip } = require('./party_tile_notifications');

// Minimal Firestore-like fake, matching party_dwell.test.js's fakes.
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
  const db = new FakeDb({
    'parties/p1': { teamAMembers: ['u1'], teamBMembers: ['u2'] },
  });

  await notifyTileFlip({
    db,
    partyId: 'p1',
    tileId: 't1',
    beforeData: { teamADwellSeconds: 400, teamBDwellSeconds: 0 },
    afterData: { teamADwellSeconds: 460, teamBDwellSeconds: 0 },
  });

  const notification = await db
    .collection('profiles')
    .doc('u1')
    .collection('notifications')
    .doc('party_tile_lost_p1_t1')
    .get();

  assert.equal(notification.exists, false);
})();

(async () => {
  const db = new FakeDb({
    'parties/p1': { teamAMembers: ['u1', 'u2'], teamBMembers: ['u3'] },
  });

  await notifyTileFlip({
    db,
    partyId: 'p1',
    tileId: 't1',
    beforeData: { teamADwellSeconds: 400, teamBDwellSeconds: 0 },
    afterData: { teamADwellSeconds: 400, teamBDwellSeconds: 500 },
  });

  for (const uid of ['u1', 'u2']) {
    const notification = await db
      .collection('profiles')
      .doc(uid)
      .collection('notifications')
      .doc('party_tile_lost_p1_t1')
      .get();
    assert.equal(notification.exists, true, `expected notification for ${uid}`);
    assert.equal(notification.data().recipientId, uid);
    assert.equal(notification.data().type, 'partyTileLost');
    assert.equal(notification.data().partyId, 'p1');
    assert.equal(notification.data().tileId, 't1');
  }
})();

(async () => {
  const db = new FakeDb({
    'parties/p1': { teamAMembers: ['u1'], teamBMembers: ['u3'] },
  });

  await notifyTileFlip({
    db,
    partyId: 'p1',
    tileId: 't1',
    beforeData: { teamADwellSeconds: 400, teamBDwellSeconds: 0 },
    afterData: { teamADwellSeconds: 400, teamBDwellSeconds: 500 },
  });

  const winnerNotification = await db
    .collection('profiles')
    .doc('u3')
    .collection('notifications')
    .doc('party_tile_lost_p1_t1')
    .get();

  assert.equal(winnerNotification.exists, false);

  console.log('party_tile_notifications.test.js: all assertions passed');
})();
