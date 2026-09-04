/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Tests persisted polygon unlock records and duplicate unlock prevention.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/services/polygon_service.dart';

void main() {
  group('PolygonService', () {
    test(
      'getVisitedPolygonRecords returns empty when document missing',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = PolygonService(firestore: firestore);

        final records = await service.getVisitedPolygonRecords(
          profileId: 'unknown',
        );
        expect(records, isEmpty);
      },
    );

    test('getVisitedPolygonRecords parses visited_polygons map', () async {
      final firestore = FakeFirebaseFirestore();
      final visitedAt = DateTime(2026, 2, 10, 9);
      await firestore.collection('polygons_visited').doc('user-a').set(
        <String, dynamic>{
          'profile_id': 'user-a',
          'user_id': 'user-a',
          'visited_polygons': <String, dynamic>{
            'poly-1': Timestamp.fromDate(visitedAt),
            'poly-2': Timestamp.fromDate(
              visitedAt.add(const Duration(days: 1)),
            ),
          },
        },
      );

      final service = PolygonService(firestore: firestore);
      final records = await service.getVisitedPolygonRecords(
        profileId: 'user-a',
      );

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
      await firestore.collection('polygons_visited').doc('user-b').set(
        <String, dynamic>{
          'profile_id': 'user-b',
          'visited_polygons': <String, dynamic>{'old': Timestamp.fromDate(t1)},
        },
      );

      final service = PolygonService(firestore: firestore);
      final t2 = DateTime(2026, 6, 1);
      await service.upsertVisitedPolygon(
        profileId: 'user-b',
        polygonId: 'new-poly',
        visitedAt: t2,
      );

      final records = await service.getVisitedPolygonRecords(
        profileId: 'user-b',
      );
      expect(records, hasLength(2));
      expect(
        records.firstWhere((r) => r.polygonId == 'new-poly').visitedAt,
        t2,
      );
    });

    test('deleteVisitedPolygon removes a polygon entry', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('polygons_visited').doc('user-c').set(
        <String, dynamic>{
          'profile_id': 'user-c',
          'visited_polygons': <String, dynamic>{
            'keep': Timestamp.fromDate(DateTime(2026, 1, 1)),
            'drop': Timestamp.fromDate(DateTime(2026, 1, 2)),
          },
        },
      );

      final service = PolygonService(firestore: firestore);
      await service.deleteVisitedPolygon(
        profileId: 'user-c',
        polygonId: 'drop',
      );

      final records = await service.getVisitedPolygonRecords(
        profileId: 'user-c',
      );
      expect(records, hasLength(1));
      expect(records.single.polygonId, 'keep');
    });

    test(
      'updateVisitedPolygon updates an existing polygon timestamp',
      () async {
        final firestore = FakeFirebaseFirestore();
        final original = DateTime(2026, 1, 1);
        final updated = DateTime(2026, 4, 5, 10);
        await firestore.collection('polygons_visited').doc('user-update').set(
          <String, dynamic>{
            'profile_id': 'user-update',
            'visited_polygons': <String, dynamic>{
              'poly-update': Timestamp.fromDate(original),
            },
          },
        );

        final service = PolygonService(firestore: firestore);

        await service.updateVisitedPolygon(
          profileId: 'user-update',
          polygonId: 'poly-update',
          visitedAt: updated,
        );

        final records = await service.getVisitedPolygonRecords(
          profileId: 'user-update',
        );
        expect(records.single.visitedAt, updated);
      },
    );

    test('upsertVisitedPolygon returns false for duplicate polygon', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PolygonService(firestore: firestore);
      final firstVisit = DateTime(2026, 1, 1);

      final first = await service.upsertVisitedPolygon(
        profileId: 'user-duplicate',
        polygonId: 'poly-duplicate',
        visitedAt: firstVisit,
      );
      final second = await service.upsertVisitedPolygon(
        profileId: 'user-duplicate',
        polygonId: 'poly-duplicate',
        visitedAt: firstVisit.add(const Duration(days: 1)),
      );

      expect(first, isTrue);
      expect(second, isFalse);

      final records = await service.getVisitedPolygonRecords(
        profileId: 'user-duplicate',
      );
      expect(records.single.visitedAt, firstVisit);
    });

    test(
      'upsertVisitedPolygon uses current time when visitedAt is omitted',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = PolygonService(firestore: firestore);

        final didUnlock = await service.upsertVisitedPolygon(
          profileId: 'user-now',
          polygonId: 'poly-now',
        );

        expect(didUnlock, isTrue);
        final records = await service.getVisitedPolygonRecords(
          profileId: 'user-now',
        );
        expect(records.single.polygonId, 'poly-now');
        expect(records.single.visitedAt, isA<DateTime>());
      },
    );

    test('resolves legacy profileId document shapes', () async {
      final firestore = FakeFirebaseFirestore();
      final visitedAt = DateTime(2026, 5, 1);
      await firestore.collection('polygons_visited').doc('legacy-doc').set(
        <String, dynamic>{
          'profileId': 'legacy-user',
          'visited_polygons': <String, dynamic>{
            'legacy-poly': Timestamp.fromDate(visitedAt),
          },
        },
      );

      final service = PolygonService(firestore: firestore);

      final records = await service.getVisitedPolygonRecords(
        profileId: 'legacy-user',
      );

      expect(records.single.polygonId, 'legacy-poly');
      expect(records.single.visitedAt, visitedAt);
    });

    test('watchVisitedPolygonRecords emits parsed polygon records', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PolygonService(firestore: firestore);
      final visitedAt = DateTime(2026, 6, 1);

      await firestore.collection('polygons_visited').doc('watch-user').set(
        <String, dynamic>{
          'profile_id': 'watch-user',
          'visited_polygons': <String, dynamic>{
            '': Timestamp.fromDate(visitedAt),
            'watch-poly': Timestamp.fromDate(visitedAt),
          },
        },
      );

      final records = await service
          .watchVisitedPolygonRecords(profileId: 'watch-user')
          .first;

      expect(records, hasLength(1));
      expect(records.single.polygonId, 'watch-poly');
    });

    test('upsertVisitedPolygon stores visited_polygon_meta', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PolygonService(firestore: firestore);
      final visitedAt = DateTime(2026, 3, 1, 12);

      final didUnlock = await service.upsertVisitedPolygon(
        profileId: 'user-meta',
        polygonId: 'poly-meta',
        visitedAt: visitedAt,
        areaSquareMetres: 12345.6,
        name: 'Carlton',
      );

      expect(didUnlock, isTrue);

      final meta = await service.getVisitedPolygonMeta(profileId: 'user-meta');
      expect(meta['poly-meta']?.areaSquareMetres, 12345.6);
      expect(meta['poly-meta']?.name, 'Carlton');
      expect(meta['poly-meta']?.lastEnteredAt, visitedAt);
    });

    test(
      'recordPolygonReentry increments entry count and lastEnteredAt',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = PolygonService(firestore: firestore);
        final firstEnter = DateTime(2026, 3, 1, 12);
        final secondEnter = DateTime(2026, 3, 2, 12);

        await service.upsertVisitedPolygon(
          profileId: 'user-reentry',
          polygonId: 'poly-reentry',
          visitedAt: firstEnter,
          areaSquareMetres: 500,
          name: 'Fitzroy',
        );

        final count = await service.recordPolygonReentry(
          profileId: 'user-reentry',
          polygonId: 'poly-reentry',
          enteredAt: secondEnter,
        );

        expect(count, 1);

        final meta = await service.getVisitedPolygonMeta(
          profileId: 'user-reentry',
        );
        expect(meta['poly-reentry']?.lastEnteredAt, secondEnter);

        final counts = await service.getPolygonEntryCounts(
          profileId: 'user-reentry',
        );
        expect(counts['poly-reentry'], 1);
      },
    );

    test(
      'recordPolygonReentry creates meta and parses existing string count',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = PolygonService(firestore: firestore);
        final enteredAt = DateTime(2026, 7, 1, 8);
        await firestore.collection('polygons_visited').doc('user-new-meta').set(
          <String, dynamic>{
            'profile_id': 'user-new-meta',
            'entry_counts': <String, dynamic>{'poly-new-meta': '2'},
          },
        );

        final count = await service.recordPolygonReentry(
          profileId: 'user-new-meta',
          polygonId: 'poly-new-meta',
          enteredAt: enteredAt,
        );

        expect(count, 3);
        final meta = await service.getVisitedPolygonMeta(
          profileId: 'user-new-meta',
        );
        expect(meta['poly-new-meta']?.visitedAt, enteredAt);
        expect(meta['poly-new-meta']?.lastEnteredAt, enteredAt);
      },
    );

    test(
      'recordPolygonReentry uses current time when enteredAt is omitted',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = PolygonService(firestore: firestore);

        final count = await service.recordPolygonReentry(
          profileId: 'user-reentry-now',
          polygonId: 'poly-reentry-now',
        );

        expect(count, 1);
        final meta = await service.getVisitedPolygonMeta(
          profileId: 'user-reentry-now',
        );
        expect(meta['poly-reentry-now']?.visitedAt, isA<DateTime>());
        expect(meta['poly-reentry-now']?.lastEnteredAt, isA<DateTime>());
      },
    );

    test('watchVisitedPolygonMeta filters malformed entries', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PolygonService(firestore: firestore);
      final visitedAt = DateTime(2026, 8, 1);
      await firestore.collection('polygons_visited').doc('meta-watch').set(
        <String, dynamic>{
          'profile_id': 'meta-watch',
          'visited_polygon_meta': <String, dynamic>{
            '': <String, dynamic>{'visitedAt': Timestamp.fromDate(visitedAt)},
            'bad': 'not-a-map',
            'good': <String, dynamic>{
              'visitedAt': Timestamp.fromDate(visitedAt),
              'areaSquareMetres': 42,
              'name': 'Parkville',
            },
          },
        },
      );

      final meta = await service
          .watchVisitedPolygonMeta(profileId: 'meta-watch')
          .first;

      expect(meta.keys, {'good'});
      expect(meta['good']?.areaSquareMetres, 42);
      expect(meta['good']?.name, 'Parkville');
    });

    test('incrementPolygonEntryCount parses existing counts', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PolygonService(firestore: firestore);
      await firestore.collection('polygons_visited').doc('count-user').set(
        <String, dynamic>{
          'profile_id': 'count-user',
          'entry_counts': <String, dynamic>{'count-poly': '4'},
        },
      );

      final count = await service.incrementPolygonEntryCount(
        profileId: 'count-user',
        polygonId: 'count-poly',
      );

      expect(count, 5);
      final counts = await service.getPolygonEntryCounts(
        profileId: 'count-user',
      );
      expect(counts['count-poly'], 5);
    });

    test(
      'incrementPolygonEntryCount handles missing and numeric counts',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = PolygonService(firestore: firestore);

        final firstCount = await service.incrementPolygonEntryCount(
          profileId: 'count-branches',
          polygonId: 'new-count',
        );

        await firestore
            .collection('polygons_visited')
            .doc('count-branches')
            .set(<String, dynamic>{
              'entry_counts': <String, dynamic>{'numeric-count': 6},
            }, SetOptions(merge: true));

        final numericCount = await service.incrementPolygonEntryCount(
          profileId: 'count-branches',
          polygonId: 'numeric-count',
        );

        expect(firstCount, 1);
        expect(numericCount, 7);
      },
    );

    test(
      'getPolygonEntryCounts filters invalid and non-positive counts',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = PolygonService(firestore: firestore);
        await firestore.collection('polygons_visited').doc('filter-user').set(
          <String, dynamic>{
            'profile_id': 'filter-user',
            'entry_counts': <String, dynamic>{
              'keep-num': 3,
              'keep-string': '2',
              'zero': 0,
              'bad': 'NaN',
              'outside': 9,
              '': 7,
            },
          },
        );

        final counts = await service.getPolygonEntryCounts(
          profileId: 'filter-user',
          validPolygonIds: {'keep-num', 'keep-string', 'zero', 'bad'},
        );

        expect(counts, {'keep-num': 3, 'keep-string': 2});
      },
    );

    test('watchPolygonEntryCounts emits filtered counts', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PolygonService(firestore: firestore);
      await firestore.collection('polygons_visited').doc('watch-counts').set(
        <String, dynamic>{
          'profile_id': 'watch-counts',
          'entry_counts': <String, dynamic>{'visible': 1, 'hidden': 2},
        },
      );

      final counts = await service
          .watchPolygonEntryCounts(
            profileId: 'watch-counts',
            validPolygonIds: {'visible'},
          )
          .first;

      expect(counts, {'visible': 1});
    });

    test('fog decay presentation persists without deleting history', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PolygonService(firestore: firestore);
      final visitedAt = DateTime(2026, 1, 1);
      final decayAt = DateTime(2026, 1, 31);
      await service.upsertVisitedPolygon(
        profileId: 'user-decay-animation',
        polygonId: 'region-1',
        visitedAt: visitedAt,
      );

      await service.markFogDecayPresented(
        profileId: 'user-decay-animation',
        decayAtByPolygonId: <String, DateTime>{'region-1': decayAt},
      );

      expect(
        await service.getFogDecayPresentedAt(profileId: 'user-decay-animation'),
        <String, DateTime>{'region-1': decayAt},
      );
      final history = await service.getVisitedPolygonRecords(
        profileId: 'user-decay-animation',
      );
      expect(history.single.polygonId, 'region-1');
      expect(history.single.visitedAt, visitedAt);
    });
  });
}
