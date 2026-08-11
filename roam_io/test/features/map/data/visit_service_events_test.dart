import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';
import 'package:roam_io/features/map/data/visit_service.dart';
import 'package:roam_io/features/you/services/stats_summary_service.dart';

void main() {
  group('VisitService visit events', () {
    late FakeFirebaseFirestore firestore;
    late VisitService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = VisitService(
        firestore: firestore,
        statsSummaryService: StatsSummaryService(firestore: firestore),
      );
    });

    PlaceOfInterest testPlace({required int id}) {
      return PlaceOfInterest(
        id: id,
        googlePlaceId: 'google-$id',
        name: 'Place $id',
        category: PlaceCategory.foodDrink,
        types: const ['cafe'],
        location: const LatLng(-37.8136, 144.9631),
        regionId: 'region-1',
      );
    }

    test('markVisited creates event and summary counters on first visit', () async {
      final result = await service.markVisited(
        userId: 'user-1',
        place: testPlace(id: 1),
      );

      expect(result.isFirstVisit, isTrue);

      final visitDoc = await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('visits')
          .doc('1')
          .get();
      expect(visitDoc.data()?['visitCount'], 1);

      final events = await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('visit_events')
          .get();
      expect(events.docs, hasLength(1));
      expect(events.docs.single.data()['lat'], isA<double>());

      final summary = await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('stats_summary')
          .doc('summary')
          .get();
      expect(summary.data()?['totalVisits'], 1);
      expect(summary.data()?['uniquePlaces'], 1);
    });

    test('markVisited increments revisit counters without uniquePlaces bump', () async {
      final place = testPlace(id: 2);
      await service.markVisited(userId: 'user-1', place: place);
      final revisit = await service.markVisited(userId: 'user-1', place: place);

      expect(revisit.isFirstVisit, isFalse);

      final visitDoc = await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('visits')
          .doc('2')
          .get();
      expect(visitDoc.data()?['visitCount'], 2);

      final events = await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('visit_events')
          .get();
      expect(events.docs, hasLength(2));

      final summary = await firestore
          .collection('profiles')
          .doc('user-1')
          .collection('stats_summary')
          .doc('summary')
          .get();
      expect(summary.data()?['totalVisits'], 2);
      expect(summary.data()?['uniquePlaces'], 1);
    });
  });
}
