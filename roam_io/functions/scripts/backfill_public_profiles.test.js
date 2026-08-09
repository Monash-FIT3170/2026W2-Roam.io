/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Lightweight assertions for public profile backfill mapping helpers.
 */

const assert = require('node:assert/strict');

const {
  hasPublicProfileChanged,
  normalizeSearchText,
  normalizeUsernameSearchText,
  publicProfileFromPrivateProfile,
} = require('./backfill_public_profiles');

const { publicProfile: profile } = publicProfileFromPrivateProfile(
  'user-1',
  {
    username: 'SanjevanR_Test',
    displayName: 'Sanjevan Rajasegar',
    email: 'private@example.com',
    darkModeEnabled: true,
    photoUrl: 'https://example.com/photo.jpg',
    xp: 140,
    level: 2,
    createdAt: '2026-08-01T00:00:00.000Z',
  },
  '2026-08-07T00:00:00.000Z',
);

assert.equal(normalizeSearchText(' SANJ '), 'sanj');
assert.equal(normalizeUsernameSearchText(' @Jacob_DeLaPaz '), 'jacob_delapaz');
assert.equal(profile.uid, 'user-1');
assert.equal(profile.username, 'SanjevanR_Test');
assert.equal(profile.usernameSearch, 'sanjevanr_test');
assert.equal(profile.displayNameSearch, 'sanjevan rajasegar');
assert.equal(profile.xp, 140);
assert.equal(profile.level, 2);
assert.equal(profile.photoUrl, 'https://example.com/photo.jpg');
assert.equal(profile.email, undefined);
assert.equal(profile.darkModeEnabled, undefined);

const { publicProfile: atUsernameProfile } = publicProfileFromPrivateProfile(
  'user-at',
  {
    username: '@Jacob_DeLaPaz',
    displayName: 'Jacob de la Paz',
  },
  '2026-08-07T00:00:00.000Z',
);
assert.equal(atUsernameProfile.username, '@Jacob_DeLaPaz');
assert.equal(atUsernameProfile.usernameSearch, 'jacob_delapaz');
assert.equal(atUsernameProfile.displayNameSearch, 'jacob de la paz');

assert.deepEqual(
  publicProfileFromPrivateProfile(
    'user-2',
    { username: '', displayName: 'A' },
  ),
  { publicProfile: null, skipReason: 'missing_username' },
);
assert.deepEqual(
  publicProfileFromPrivateProfile(
    'user-3',
    { username: 'valid', displayName: '' },
  ),
  { publicProfile: null, skipReason: 'missing_display_name' },
);
assert.equal(hasPublicProfileChanged(profile, { ...profile }), false);
assert.equal(
  hasPublicProfileChanged(profile, { ...profile, displayName: 'Changed' }),
  true,
);
assert.equal(
  hasPublicProfileChanged({ ...profile, photoUrl: undefined }, profile),
  true,
);

console.log('backfill_public_profiles helpers passed');
