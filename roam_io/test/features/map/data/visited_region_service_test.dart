/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Tests first-time visited region persistence results used for XP idempotency.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/visited_region_service.dart';
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
}
