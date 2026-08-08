import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/domain/nearby_place.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/journeys/widgets/end_journey_sheet.dart';

void main() {
  const position = LatLng(-37.81, 144.96);
  const places = [
    NearbyPlace(
      placeId: 'station',
      name: 'Central Station',
      address: '1 Station Street',
      latLng: LatLng(-37.811, 144.961),
      distanceMeters: 8,
    ),
    NearbyPlace(
      name: 'Home',
      address: '',
      latLng: LatLng(-37.812, 144.962),
      distanceMeters: 9,
      isCustomLocation: true,
    ),
  ];

  Future<ValueNotifier<EndJourneyResult?>> openSheet(
    WidgetTester tester, {
    double distance = 1234,
    Duration duration = const Duration(hours: 1, minutes: 5),
  }) async {
    final result = ValueNotifier<EndJourneyResult?>(null);
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result.value = await EndJourneySheet.show(
                context: context,
                currentPosition: position,
                distanceMeters: distance,
                duration: duration,
                transportMode: TransportMode.train,
                nearbyPlaces: places,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    return result;
  }

  testWidgets('finishes at the selected nearby place', (tester) async {
    final result = await openSheet(tester);

    expect(find.text('1.23 km'), findsOneWidget);
    expect(find.text('1h 5m'), findsOneWidget);
    expect(find.text('Train'), findsOneWidget);
    expect(find.text('Central Station'), findsOneWidget);
    expect(find.text('Saved Location'), findsOneWidget);

    await tester.tap(find.text('Central Station'));
    await tester.pump();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(result.value?.endLocation.placeId, 'station');
  });

  testWidgets('continues tracking and supports current location selection', (
    tester,
  ) async {
    EndJourneyResult? result;
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await EndJourneySheet.show(
                context: context,
                currentPosition: position,
                distanceMeters: 42,
                duration: const Duration(seconds: 9),
                transportMode: TransportMode.walk,
                nearbyPlaces: places,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('42 m'), findsOneWidget);
    expect(find.text('9s'), findsOneWidget);
    await tester.tap(find.text('Central Station'));
    await tester.pump();
    await tester.tap(find.text('Current Location'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(result?.continueTracking, isTrue);
    expect(result?.endLocation.latLng, position);
  });

  testWidgets('formats a duration containing minutes', (tester) async {
    await openSheet(
      tester,
      distance: 500,
      duration: const Duration(minutes: 2, seconds: 3),
    );
    expect(find.text('2m 3s'), findsOneWidget);
  });
}
