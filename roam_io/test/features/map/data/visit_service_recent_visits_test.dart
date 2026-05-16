/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Verifies VisitService.watchRecentVisits caps results, orders by visitedAt
 *   descending, and reacts to Firestore updates under fake_cloud_firestore.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/visit.dart';
import 'package:roam_io/features/map/data/visit_service.dart';

void main() {
  group('VisitService.watchRecentVisits', () {
    test('emits at most five visits newest first', () async {
      final firestore = FakeFirebaseFirestore();
      final service = VisitService(firestore: firestore);
      const userId = 'user-a';

      Future<void> seedVisit(int placeId, DateTime at) async {
        await firestore
            .collection('profiles')
            .doc(userId)
            .collection('visits')
            .doc(placeId.toString())
            .set({
              'placeId': placeId,
              'googlePlaceId': 'g$placeId',
              'placeName': 'Place $placeId',
              'regionId': 'r1',
              'category': 'nature',
              'visitedAt': Timestamp.fromDate(at),
            });
      }

      await seedVisit(1, DateTime(2026, 1, 1));
      await seedVisit(2, DateTime(2026, 6, 1));
      await seedVisit(3, DateTime(2026, 3, 1));
      await seedVisit(4, DateTime(2026, 12, 1));
      await seedVisit(5, DateTime(2026, 2, 1));
      await seedVisit(6, DateTime(2026, 11, 15));
      await seedVisit(7, DateTime(2026, 11, 20));

      final first = await service.watchRecentVisits(userId).first;

      expect(first, hasLength(5));
      expect(first.map((Visit v) => v.placeId).toList(), [4, 7, 6, 2, 3]);
    });

    test('emits a new list when visitedAt changes', () async {
      final firestore = FakeFirebaseFirestore();
      final service = VisitService(firestore: firestore);
      const userId = 'user-b';

      Future<void> seedVisit(int placeId, DateTime at) async {
        await firestore
            .collection('profiles')
            .doc(userId)
            .collection('visits')
            .doc(placeId.toString())
            .set({
              'placeId': placeId,
              'googlePlaceId': 'g$placeId',
              'placeName': 'Place $placeId',
              'regionId': 'r1',
              'category': 'nature',
              'visitedAt': Timestamp.fromDate(at),
            });
      }

      await seedVisit(1, DateTime(2026, 1, 1));
      await seedVisit(2, DateTime(2026, 2, 1));

      final emissions = <List<Visit>>[];
      final sub = service.watchRecentVisits(userId).listen(emissions.add);

      await Future<void>.delayed(Duration.zero);
      expect(emissions, isNotEmpty);
      expect(emissions.last.map((v) => v.placeId).toList(), [2, 1]);

      await firestore
          .collection('profiles')
          .doc(userId)
          .collection('visits')
          .doc('1')
          .update({'visitedAt': Timestamp.fromDate(DateTime(2026, 12, 31))});

      await Future<void>.delayed(Duration.zero);
      expect(emissions.last.map((v) => v.placeId).toList(), [1, 2]);

      await sub.cancel();
    });
  });

  group('VisitService.getVisitCountsByRegion', () {
    test('counts completed visits per region', () async {
      final firestore = FakeFirebaseFirestore();
      final service = VisitService(firestore: firestore);
      const userId = 'user-c';

      Future<void> seedVisit({
        required int placeId,
        required String regionId,
      }) async {
        await firestore
            .collection('profiles')
            .doc(userId)
            .collection('visits')
            .doc(placeId.toString())
            .set({
              'placeId': placeId,
              'googlePlaceId': 'g$placeId',
              'placeName': 'Place $placeId',
              'regionId': regionId,
              'category': 'nature',
              'visitedAt': Timestamp.fromDate(DateTime(2026, 5, placeId)),
            });
      }

      await seedVisit(placeId: 1, regionId: 'tile-a');
      await seedVisit(placeId: 2, regionId: 'tile-a');
      await seedVisit(placeId: 3, regionId: 'tile-b');

      final counts = await service.getVisitCountsByRegion(userId);

      expect(counts, <String, int>{'tile-a': 2, 'tile-b': 1});
    });
  });
}
