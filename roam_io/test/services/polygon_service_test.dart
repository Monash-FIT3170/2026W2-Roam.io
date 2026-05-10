import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/services/polygon_service.dart';

void main() {
  group('PolygonService', () {
    test('loads visited polygons from the uid-keyed document shape', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PolygonService(firestore: firestore);
      final visitedAt = DateTime(2026, 5, 6, 9, 30);

      await firestore.collection('polygons_visited').doc('user-1').set({
        'profile_id': 'user-1',
        'visited_polygons': {'region-a': Timestamp.fromDate(visitedAt)},
      });

      final records = await service.getVisitedPolygonRecords(
        profileId: 'user-1',
      );

      expect(records, hasLength(1));
      expect(records.single.polygonId, 'region-a');
      expect(records.single.visitedAt, visitedAt);
    });

    test(
      'loads visited polygons from an existing user_id-based document',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = PolygonService(firestore: firestore);
        final visitedAt = DateTime(2026, 5, 7, 8, 15);

        await firestore.collection('polygons_visited').doc('legacy-doc').set({
          'user_id': 'user-1',
          'visited_polygons': {'region-b': Timestamp.fromDate(visitedAt)},
        });

        final records = await service.getVisitedPolygonRecords(
          profileId: 'user-1',
        );

        expect(records, hasLength(1));
        expect(records.single.polygonId, 'region-b');
        expect(records.single.visitedAt, visitedAt);
      },
    );

    test('upserts into the existing user_id-based document', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PolygonService(firestore: firestore);
      final existingVisitedAt = DateTime(2026, 5, 5, 7, 45);
      final newVisitedAt = DateTime(2026, 5, 8, 11, 0);

      await firestore.collection('polygons_visited').doc('legacy-doc').set({
        'user_id': 'user-1',
        'visited_polygons': {'region-c': Timestamp.fromDate(existingVisitedAt)},
      });

      await service.upsertVisitedPolygon(
        profileId: 'user-1',
        polygonId: 'region-d',
        visitedAt: newVisitedAt,
      );

      final legacySnapshot = await firestore
          .collection('polygons_visited')
          .doc('legacy-doc')
          .get();
      final directSnapshot = await firestore
          .collection('polygons_visited')
          .doc('user-1')
          .get();

      expect(legacySnapshot.exists, isTrue);
      expect(directSnapshot.exists, isFalse);

      final legacyData = legacySnapshot.data()!;
      final visitedPolygons =
          legacyData['visited_polygons'] as Map<String, dynamic>;

      expect(legacyData['user_id'], 'user-1');
      expect(legacyData['profile_id'], 'user-1');
      expect(visitedPolygons.keys.toSet(), {'region-c', 'region-d'});
      expect(visitedPolygons['region-d'], Timestamp.fromDate(newVisitedAt));
    });
  });
}
