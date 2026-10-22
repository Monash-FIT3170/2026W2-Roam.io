/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 17/05/2026
 * Description:
 *   Widget tests for place details distance display and mark-as-visited flows.
 */

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/map_controller.dart';
import 'package:roam_io/features/map/data/place_details_sheet.dart';

import '../../../support/map_test_doubles.dart';

void main() {
  // MapController and sheet may touch Firebase during proximity updates.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  testWidgets(
    'shows live in-range and out-of-range feedback without reopening',
    (tester) async {
      final geo = FakeGeoLocatorService(testPosition(-37.8136, 144.9631));
      final controller = await _pumpDetails(tester, geo);
      expect(find.text('Not visited'), findsOneWidget);
      expect(find.text('In range'), findsOneWidget);
      expect(_visitButton(tester).onPressed, isNotNull);

      geo.setPosition(testPosition(-37.82, 144.9631));
      await controller.getDistanceToPlace(testPlace());
      await tester.pumpAndSettle();
      expect(find.text('Out of range'), findsOneWidget);
      expect(find.textContaining('Get within 100m'), findsOneWidget);
      expect(_visitButton(tester).onPressed, isNull);

      geo.setPosition(testPosition(-37.8136, 144.9631));
      await controller.getDistanceToPlace(testPlace());
      await tester.pumpAndSettle();
      expect(find.text('In range'), findsOneWidget);
      expect(_visitButton(tester).onPressed, isNotNull);
    },
  );

  testWidgets(
    'location failure has a retry instead of an endless loading state',
    (tester) async {
      final geo = FakeGeoLocatorService(null);
      await _pumpDetails(tester, geo);
      expect(find.text('Location unavailable'), findsOneWidget);
      expect(_visitButton(tester).onPressed, isNull);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      geo.setPosition(testPosition(-37.8136, 144.9631));
      await tester.tap(find.text('Try location again'));
      await tester.pumpAndSettle();
      expect(find.text('In range'), findsOneWidget);
      expect(_visitButton(tester).onPressed, isNotNull);
    },
  );

  testWidgets(
    'saved visit changes the open sheet and remains visited outside range',
    (tester) async {
      final geo = FakeGeoLocatorService(testPosition(-37.8136, 144.9631));
      final controller = await _pumpDetails(tester, geo);
      await controller.markPlaceAsVisited(testPlace());
      await tester.pumpAndSettle();
      expect(find.text('Visited'), findsOneWidget);
      expect(find.text('Mark as Visited'), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Edit Visit'),
            )
            .onPressed,
        isNotNull,
      );
      geo.setPosition(testPosition(-38, 145));
      await controller.getDistanceToPlace(testPlace());
      await tester.pumpAndSettle();
      expect(find.text('Visited'), findsOneWidget);
      expect(find.text('Out of range'), findsOneWidget);
      expect(
        find.text('You can edit this visit from anywhere.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('missing visit details provide retry and disable editing', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      FakeGeoLocatorService(testPosition(-37.8136, 144.9631)),
      visits: RecordingVisitService(initialIds: {1}),
    );
    expect(find.text('Visited'), findsOneWidget);
    expect(find.text('Retry visit details'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Edit Visit'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Retry visit details'));
    await tester.pumpAndSettle();
    expect(find.text('Retry visit details'), findsOneWidget);
  });

  testWidgets('shows place title and distance when not visited', (
    tester,
  ) async {
    final controller = MapController(
      geoLocatorService: FakeGeoLocatorService(
        testPosition(-37.8136, 144.9631),
      ),
      visitService: RecordingVisitService(),
      visitedRegionService: FakeVisitedRegionService(),
    );
    await controller.setUserId('user-1');

    final place = testPlace(id: 501, name: 'Yarra Bend Park');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceDetailsSheet(place: place, mapController: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yarra Bend Park'), findsOneWidget);
    expect(find.textContaining('m away'), findsWidgets);
    expect(find.text('Mark as Visited'), findsOneWidget);

    controller.disposeController();
    controller.dispose();
  });

  testWidgets('shows login message when marking visited without user id', (
    tester,
  ) async {
    final controller = MapController(
      geoLocatorService: FakeGeoLocatorService(
        testPosition(-37.8136, 144.9631),
      ),
      visitService: RecordingVisitService(),
      visitedRegionService: FakeVisitedRegionService(),
    );

    final place = testPlace(id: 502);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceDetailsSheet(place: place, mapController: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark as Visited'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Please log in'), findsOneWidget);

    controller.disposeController();
    controller.dispose();
  });
}

ElevatedButton _visitButton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Mark as Visited'),
    );

Future<MapController> _pumpDetails(
  WidgetTester tester,
  FakeGeoLocatorService geo, {
  RecordingVisitService? visits,
}) async {
  final controller = MapController(
    geoLocatorService: geo,
    visitService: visits ?? RecordingVisitService(),
    visitedRegionService: FakeVisitedRegionService(),
  );
  await controller.setUserId('user-1');
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PlaceDetailsSheet(
          place: testPlace(location: const LatLng(-37.8136, 144.9631)),
          mapController: controller,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() {
    controller.disposeController();
    controller.dispose();
  });
  return controller;
}
