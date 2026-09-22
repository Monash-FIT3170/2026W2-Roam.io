import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/visited_region_service.dart';
import 'package:roam_io/features/map/fog/fog_decay_difficulty.dart';
import 'package:roam_io/features/map/fog/fog_decay_service.dart';
import 'package:roam_io/features/map/fog/fog_decay_warning_service.dart';
import 'package:roam_io/notifications/models/app_notification.dart';
import 'package:roam_io/services/polygon_service.dart';

void main() {
  test('complete exploration, warning, revisit, and decay lifecycle', () async {
    final firestore = FakeFirebaseFirestore();
    final polygonService = PolygonService(firestore: firestore);
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'integration-user'),
    );
    final scheduled = <({AppNotification notification, DateTime at})>[];
    final cancelled = <String>[];
    final warningService = FogDecayWarningService(
      schedule: (notification, {required scheduledAt}) async {
        scheduled.add((notification: notification, at: scheduledAt));
        return true;
      },
      cancel: (id) async => cancelled.add(id),
    );
    final visitedService = VisitedRegionService(
      auth: auth,
      polygonService: polygonService,
      fogDecayWarningService: warningService,
    );
    const decayService = FogDecayService();
    final firstExploredAt = DateTime(2026, 1, 1);

    // Scenario A: first exploration persists permanent history and timestamps.
    expect(
      await visitedService.markVisited(
        'location-a',
        visitedAt: firstExploredAt,
      ),
      isTrue,
    );
    final firstMetadata = await polygonService.getVisitedPolygonMeta(
      profileId: 'integration-user',
    );
    expect(firstMetadata['location-a']?.visitedAt, firstExploredAt);
    expect(firstMetadata['location-a']?.lastEnteredAt, firstExploredAt);
    expect(
      decayService.calculateDecayDate(
        lastExploredAt: firstExploredAt,
        difficulty: FogDecayDifficulty.monthly,
      ),
      DateTime(2026, 1, 31),
    );

    // Scenario B: one batched warning is due seven days before decay.
    await visitedService.refreshFogDecayWarnings(
      difficulty: FogDecayDifficulty.monthly,
      now: DateTime(2026, 1, 2),
    );
    expect(scheduled.single.at, DateTime(2026, 1, 24));

    // Scenario C: revisiting preserves first history and replaces the warning.
    final revisitedAt = DateTime(2026, 2, 1);
    await polygonService.recordPolygonReentry(
      profileId: 'integration-user',
      polygonId: 'location-a',
      enteredAt: revisitedAt,
    );
    scheduled.clear();
    await visitedService.refreshFogDecayWarnings(
      difficulty: FogDecayDifficulty.monthly,
      now: DateTime(2026, 2, 2),
    );
    expect(cancelled, contains('fog-decay-warning-0'));
    expect(scheduled.single.at, DateTime(2026, 2, 24));
    final revisitedMetadata = await polygonService.getVisitedPolygonMeta(
      profileId: 'integration-user',
    );
    expect(revisitedMetadata['location-a']?.visitedAt, firstExploredAt);
    expect(revisitedMetadata['location-a']?.lastEnteredAt, revisitedAt);

    // Scenario D: restart-style reads identify expiry without deleting history.
    final afterDecay = DateTime(2026, 3, 5);
    expect(
      await visitedService.loadFogClearedRegionIds(
        difficulty: FogDecayDifficulty.monthly,
        now: afterDecay,
      ),
      isEmpty,
    );
    expect(await visitedService.loadVisitedRegionIds(), contains('location-a'));
    final pending = await visitedService.loadUnpresentedFogDecayEvents(
      difficulty: FogDecayDifficulty.monthly,
      now: afterDecay,
    );
    expect(pending, <String, DateTime>{'location-a': DateTime(2026, 3, 3)});
    await visitedService.markFogDecayEventsPresented(pending);
    expect(
      await visitedService.loadUnpresentedFogDecayEvents(
        difficulty: FogDecayDifficulty.monthly,
        now: afterDecay,
      ),
      isEmpty,
    );

    // Scenario E: revisiting a fogged location starts a fresh clear cycle.
    final secondRevisit = DateTime(2026, 3, 10);
    await polygonService.recordPolygonReentry(
      profileId: 'integration-user',
      polygonId: 'location-a',
      enteredAt: secondRevisit,
    );
    expect(
      await visitedService.loadFogClearedRegionIds(
        difficulty: FogDecayDifficulty.monthly,
        now: DateTime(2026, 3, 11),
      ),
      contains('location-a'),
    );
    expect(await visitedService.loadVisitedRegionIds(), contains('location-a'));
    final finalMetadata = await polygonService.getVisitedPolygonMeta(
      profileId: 'integration-user',
    );
    expect(finalMetadata['location-a']?.visitedAt, firstExploredAt);
    expect(finalMetadata['location-a']?.lastEnteredAt, secondRevisit);
  });
}
