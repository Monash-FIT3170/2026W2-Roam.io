const assert = require('node:assert/strict');
const { planMemberships } = require('./backfill_party_memberships');

const plan = planMemberships([
  { id: 'a', teamAMembers: ['alice', 'carol'], teamBMembers: ['bob'] },
  { id: 'b', teamAMembers: ['alice'], teamBMembers: ['bob'] },
], new Map([
  ['alice', 'b'],
  ['bob', 'missing'],
  ['orphan', 'gone'],
]));

assert.deepEqual(plan, [
  { uid: 'alice', keep: 'b', expectedCurrent: 'b', removeFrom: ['a'] },
  { uid: 'bob', keep: 'a', expectedCurrent: 'missing', removeFrom: ['b'] },
  { uid: 'carol', keep: 'a', expectedCurrent: null, removeFrom: [] },
  { uid: 'orphan', keep: null, expectedCurrent: 'gone', removeFrom: [] },
]);
console.log('passed: party membership backfill plan');
