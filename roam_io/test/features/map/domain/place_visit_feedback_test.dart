import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/domain/place_visit_feedback.dart';

void main() {
  test(
    '100m is inclusive and distance labels do not hide crossing the limit',
    () {
      for (final distance in [0.0, 99.9, 100.0]) {
        final state = PlaceVisitFeedback(
          isVisited: false,
          distanceMetres: distance,
        );
        expect(state.canVisit, isTrue);
        expect(state.markerState, PlaceMarkerState.inRange);
      }
      const outside = PlaceVisitFeedback(
        isVisited: false,
        distanceMetres: 100.1,
      );
      expect(outside.canVisit, isFalse);
      expect(outside.rangeLabel, 'Out of range');
      expect(outside.distanceLabel, '101m away');
      expect(outside.markerState, PlaceMarkerState.unvisited);
      expect(
        const PlaceVisitFeedback(
          isVisited: false,
          distanceMetres: 1250,
        ).distanceLabel,
        '1.3km away',
      );
    },
  );

  test('unknown and invalid locations never indicate visit eligibility', () {
    for (final distance in [null, double.nan, double.infinity, -1.0]) {
      final state = PlaceVisitFeedback(
        isVisited: false,
        distanceMetres: distance,
      );
      expect(state.hasLocation, isFalse);
      expect(state.canVisit, isFalse);
      expect(state.rangeLabel, 'Location unavailable');
      expect(state.distanceLabel, isNull);
    }
  });

  test('recorded visits remain visited both inside and outside the radius', () {
    for (final distance in [null, 50.0, 250.0]) {
      final state = PlaceVisitFeedback(
        isVisited: true,
        distanceMetres: distance,
      );
      expect(state.markerState, PlaceMarkerState.visited);
      expect(state.canVisit, isFalse);
      expect(state.isInRange, distance == 50);
    }
  });
}
