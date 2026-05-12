/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Tests persisted polygon unlock records and duplicate unlock prevention.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/services/polygon_service.dart';

void main() {
  group('PolygonService.upsertVisitedPolygon', () {
    test('returns true for a newly persisted polygon unlock', () async {
      final service = PolygonService(firestore: FakeFirebaseFirestore());

      final didCreateUnlock = await service.upsertVisitedPolygon(
        profileId: 'user-1',
        polygonId: 'region-1',
        visitedAt: DateTime(2026, 5, 12, 10),
      );

      final records = await service.getVisitedPolygonRecords(
        profileId: 'user-1',
      );

      expect(didCreateUnlock, isTrue);
      expect(records.map((record) => record.polygonId), contains('region-1'));
    });

    test(
      'returns false and preserves timestamp for duplicate unlocks',
      () async {
        final service = PolygonService(firestore: FakeFirebaseFirestore());
        final firstVisit = DateTime(2026, 5, 12, 10);
        final duplicateVisit = DateTime(2026, 5, 12, 11);

        final firstResult = await service.upsertVisitedPolygon(
          profileId: 'user-1',
          polygonId: 'region-1',
          visitedAt: firstVisit,
        );
        final duplicateResult = await service.upsertVisitedPolygon(
          profileId: 'user-1',
          polygonId: 'region-1',
          visitedAt: duplicateVisit,
        );

        final records = await service.getVisitedPolygonRecords(
          profileId: 'user-1',
        );

        expect(firstResult, isTrue);
        expect(duplicateResult, isFalse);
        expect(records, hasLength(1));
        expect(records.single.visitedAt, firstVisit);
      },
    );
  });
}
