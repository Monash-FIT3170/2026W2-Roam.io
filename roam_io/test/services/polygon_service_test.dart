import 'package:cloud_firestore/cloud_firestore.dart';
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
  group('PolygonService', () {
    test('getVisitedPolygonRecords returns empty when document missing', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PolygonService(firestore: firestore);

      final records = await service.getVisitedPolygonRecords(profileId: 'unknown');
      expect(records, isEmpty);
    });

    test('getVisitedPolygonRecords parses visited_polygons map', () async {
      final firestore = FakeFirebaseFirestore();
      final visitedAt = DateTime(2026, 2, 10, 9);
      await firestore.collection('polygons_visited').doc('user-a').set(<String, dynamic>{
        'profile_id': 'user-a',
        'user_id': 'user-a',
        'visited_polygons': <String, dynamic>{
          'poly-1': Timestamp.fromDate(visitedAt),
          'poly-2': Timestamp.fromDate(visitedAt.add(const Duration(days: 1))),
        },
      });

      final service = PolygonService(firestore: firestore);
      final records = await service.getVisitedPolygonRecords(profileId: 'user-a');

      expect(records, hasLength(2));
      final ids = records.map((r) => r.polygonId).toSet();
      expect(ids, {'poly-1', 'poly-2'});
      expect(
        records.firstWhere((r) => r.polygonId == 'poly-1').visitedAt,
        visitedAt,
      );
    });

    test('upsertVisitedPolygon merges into existing map', () async {
      final firestore = FakeFirebaseFirestore();
      final t1 = DateTime(2026, 1, 1);
      await firestore.collection('polygons_visited').doc('user-b').set(<String, dynamic>{
        'profile_id': 'user-b',
        'visited_polygons': <String, dynamic>{
          'old': Timestamp.fromDate(t1),
        },
      });

      final service = PolygonService(firestore: firestore);
      final t2 = DateTime(2026, 6, 1);
      await service.upsertVisitedPolygon(
        profileId: 'user-b',
        polygonId: 'new-poly',
        visitedAt: t2,
      );

      final records = await service.getVisitedPolygonRecords(profileId: 'user-b');
      expect(records, hasLength(2));
      expect(
        records.firstWhere((r) => r.polygonId == 'new-poly').visitedAt,
        t2,
      );
    });

    test('deleteVisitedPolygon removes a polygon entry', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('polygons_visited').doc('user-c').set(<String, dynamic>{
        'profile_id': 'user-c',
        'visited_polygons': <String, dynamic>{
          'keep': Timestamp.fromDate(DateTime(2026, 1, 1)),
          'drop': Timestamp.fromDate(DateTime(2026, 1, 2)),
        },
      });

      final service = PolygonService(firestore: firestore);
      await service.deleteVisitedPolygon(profileId: 'user-c', polygonId: 'drop');

      final records = await service.getVisitedPolygonRecords(profileId: 'user-c');
      expect(records, hasLength(1));
      expect(records.single.polygonId, 'keep');
    });
  });
}
