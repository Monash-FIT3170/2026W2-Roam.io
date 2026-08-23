/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Tests first-time visited region persistence and timestamped unlock streams
 *   used by XP idempotency and profile analytics.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/visited_region_service.dart';
import 'package:roam_io/features/map/fog/fog_decay_difficulty.dart';
import 'package:roam_io/services/polygon_service.dart';

void main() {
  group('VisitedRegionService.markVisited', () {
    test('returns true only for the first persisted region unlock', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'user-1'),
        signedIn: true,
      );
      final service = VisitedRegionService(
        auth: auth,
        polygonService: PolygonService(firestore: firestore),
      );

      final firstResult = await service.markVisited('region-1');
      final duplicateResult = await service.markVisited('region-1');

      expect(firstResult, isTrue);
      expect(duplicateResult, isFalse);
    });

    test('returns false when no user is signed in', () async {
      final service = VisitedRegionService(
        auth: MockFirebaseAuth(signedIn: false),
        polygonService: PolygonService(firestore: FakeFirebaseFirestore()),
      );

      expect(await service.markVisited('region-1'), isFalse);
    });
  });

  group('VisitedRegionService.watchVisitedPolygonRecords', () {
    test(
      'streams timestamped tile unlock records for the signed-in user',
      () async {
        final firestore = FakeFirebaseFirestore();
        final auth = MockFirebaseAuth(
          mockUser: MockUser(uid: 'user-1'),
          signedIn: true,
        );
        final service = VisitedRegionService(
          auth: auth,
          polygonService: PolygonService(firestore: firestore),
        );
        final visitedAt = DateTime(2026, 5, 8, 10);

        await service.markVisited('region-1', visitedAt: visitedAt);

        final records = await service.watchVisitedPolygonRecords().first;

        expect(records, hasLength(1));
        expect(records.single.profileId, 'user-1');
        expect(records.single.polygonId, 'region-1');
        expect(records.single.visitedAt, visitedAt);
      },
    );

    test('emits an empty list when no user is signed in', () async {
      final service = VisitedRegionService(
        auth: MockFirebaseAuth(signedIn: false),
        polygonService: PolygonService(firestore: FakeFirebaseFirestore()),
      );

      expect(await service.watchVisitedPolygonRecords().first, isEmpty);
    });
  });

  group('fog decay preserves exploration history', () {
    test('expired visual fog does not delete the explored region', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'user-decay'),
        signedIn: true,
      );
      final polygonService = PolygonService(firestore: firestore);
      final service = VisitedRegionService(
        auth: auth,
        polygonService: polygonService,
      );
      final exploredAt = DateTime(2026, 1, 1);

      await service.markVisited('region-a', visitedAt: exploredAt);

      final visuallyClear = await service.loadFogClearedRegionIds(
        difficulty: FogDecayDifficulty.monthly,
        now: DateTime(2026, 2, 15),
      );

      expect(visuallyClear.contains('region-a'), isFalse);
      expect(await service.loadVisitedRegionIds(), contains('region-a'));

      final records = await polygonService.getVisitedPolygonRecords(
        profileId: 'user-decay',
      );
      final metadata = await polygonService.getVisitedPolygonMeta(
        profileId: 'user-decay',
      );
      expect(records.single.visitedAt, exploredAt);
      expect(metadata['region-a']?.visitedAt, exploredAt);
      expect(metadata['region-a']?.lastEnteredAt, exploredAt);
    });

    test(
      'revisit clears fog and updates only the latest exploration time',
      () async {
        final firestore = FakeFirebaseFirestore();
        final auth = MockFirebaseAuth(
          mockUser: MockUser(uid: 'user-revisit'),
          signedIn: true,
        );
        final polygonService = PolygonService(firestore: firestore);
        final service = VisitedRegionService(
          auth: auth,
          polygonService: polygonService,
        );
        final firstExploredAt = DateTime(2026, 1, 1);
        final revisitedAt = DateTime(2026, 2, 10);

        expect(
          await service.markVisited('region-a', visitedAt: firstExploredAt),
          isTrue,
        );
        await polygonService.recordPolygonReentry(
          profileId: 'user-revisit',
          polygonId: 'region-a',
          enteredAt: revisitedAt,
        );

        final records = await polygonService.getVisitedPolygonRecords(
          profileId: 'user-revisit',
        );
        final metadata = await polygonService.getVisitedPolygonMeta(
          profileId: 'user-revisit',
        );
        final visuallyClear = await service.loadFogClearedRegionIds(
          difficulty: FogDecayDifficulty.monthly,
          now: DateTime(2026, 2, 20),
        );

        expect(visuallyClear, contains('region-a'));
        expect(records, hasLength(1));
        expect(records.single.visitedAt, firstExploredAt);
        expect(metadata['region-a']?.visitedAt, firstExploredAt);
        expect(metadata['region-a']?.lastEnteredAt, revisitedAt);
        expect(
          await service.markVisited('region-a', visitedAt: revisitedAt),
          isFalse,
        );
      },
    );
  });
}
