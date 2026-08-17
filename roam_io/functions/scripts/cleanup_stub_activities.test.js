/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Unit tests for narrow old-stub activity cleanup planning.
 */

const assert = require('node:assert/strict');
const {
  KNOWN_STUB_ACTIVITY_IDS,
  cleanupStubActivities,
  parseArgs,
} = require('./cleanup_stub_activities');

class FakeDoc {
  constructor(id, store) {
    this.id = id;
    this.store = store;
  }

  async get() {
    return { exists: Boolean(this.store[`activities/${this.id}`]) };
  }

  collection(name) {
    return {
      get: async () => {
        const docs = this.store[`activities/${this.id}/${name}`] || [];
        return { size: docs.length, docs };
      },
    };
  }
}

class FakeDb {
  constructor(store) {
    this.store = store;
    this.deletedPaths = [];
  }

  collection(name) {
    assert.equal(name, 'activities');
    return {
      doc: (id) => new FakeDoc(id, this.store),
    };
  }

  async recursiveDelete(ref) {
    this.deletedPaths.push(`activities/${ref.id}`);
  }
}

assert.equal(parseArgs(['node', 'script']).dryRun, true);
assert.equal(parseArgs(['node', 'script', '--execute']).dryRun, false);
assert.deepEqual(
  parseArgs(['node', 'script', '--activity-id', 'stub-amar-sidequest'])
    .activityIds,
  ['stub-amar-sidequest'],
);

(async () => {
  const db = new FakeDb({
    'activities/stub-amar-sidequest': { ownerId: 'old' },
    'activities/stub-amar-sidequest/comments': [{ id: 'comment-1' }],
    'activities/stub-amar-sidequest/kudos': [],
  });
  const dryRun = await cleanupStubActivities({
    db,
    activityIds: ['stub-amar-sidequest'],
  });
  assert.equal(dryRun.dryRun, true);
  assert.equal(dryRun.broadlyDeletedActivitiesCollection, false);
  assert.equal(dryRun.results[0].path, 'activities/stub-amar-sidequest');
  assert.equal(dryRun.results[0].commentsCount, 1);
  assert.equal(dryRun.results[0].deleted, false);
  assert.deepEqual(db.deletedPaths, []);

  const executed = await cleanupStubActivities({
    db,
    dryRun: false,
    activityIds: ['stub-amar-sidequest'],
  });
  assert.equal(executed.results[0].deleted, true);
  assert.deepEqual(db.deletedPaths, ['activities/stub-amar-sidequest']);
  assert.ok(KNOWN_STUB_ACTIVITY_IDS.includes('stub-amar-sidequest'));
  console.log('cleanup_stub_activities tests passed');
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
