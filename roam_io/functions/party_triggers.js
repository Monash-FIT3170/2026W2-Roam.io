/*
 * Description:
 *   Cloud Function triggers wiring the tested Party Mode modules
 *   (party_dwell.js, party_tile_notifications.js, party_season.js) into
 *   Firestore/Scheduler. Thin wiring only — logic lives in, and is tested by,
 *   the modules above.
 */

const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const { notifyTileFlip } = require('./party_tile_notifications');
const { runDueSeasonResets } = require('./party_season');
const { recordDwellPing, resolvePingTeam } = require('./party_dwell');

if (getApps().length === 0) {
  initializeApp();
}

/**
 * Callable ping endpoint: records dwell time for the caller's tile, using a
 * server-resolved team (never the client-claimed one) so a client can't
 * attribute time to a team it isn't on.
 */
exports.submitDwellPing = onCall(
  {
    region: 'australia-southeast1',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'You must be signed in to send a Party Mode ping.',
      );
    }
    const { partyId, tileId, pingAt } = request.data || {};
    if (typeof partyId !== 'string' || typeof tileId !== 'string') {
      throw new HttpsError('invalid-argument', 'partyId and tileId are required.');
    }

    const db = getFirestore();
    const uid = request.auth.uid;
    const team = await resolvePingTeam({ db, partyId, uid });

    await recordDwellPing({
      db,
      partyId,
      tileId,
      uid,
      team,
      pingAt: pingAt ? new Date(pingAt) : new Date(),
    });
  },
);

/**
 * On parties/{partyId}/tiles/{tileId} write, notify the team that lost the
 * tile (if any) via the in-app notification inbox.
 */
exports.onPartyTileWritten = onDocumentWritten(
  {
    document: 'parties/{partyId}/tiles/{tileId}',
    region: 'australia-southeast1',
  },
  async (event) => {
    const { partyId, tileId } = event.params;
    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();
    if (!afterData) return; // tile deleted (e.g. season wipe), nothing to notify.

    try {
      await notifyTileFlip({
        db: getFirestore(),
        partyId,
        tileId,
        beforeData,
        afterData,
      });
    } catch (error) {
      // Never fail the tile write over a notification issue; log only.
      console.error('[PartyTileNotif] failed to notify tile flip', {
        partyId,
        tileId,
        error: error && error.message ? error.message : String(error),
      });
    }
  },
);

/**
 * Daily check for parties whose 14-day season has elapsed; resets and
 * summarizes each one that's due.
 */
exports.onPartySeasonSchedule = onSchedule(
  {
    schedule: 'every day 00:00',
    region: 'australia-southeast1',
  },
  async () => {
    try {
      const results = await runDueSeasonResets({
        db: getFirestore(),
        now: new Date(),
      });
      console.log('[PartySeason] reset due seasons', {
        resetCount: results.length,
      });
    } catch (error) {
      console.error('[PartySeason] failed to run due season resets', {
        error: error && error.message ? error.message : String(error),
      });
    }
  },
);
