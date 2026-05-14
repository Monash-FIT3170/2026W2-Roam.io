import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/map_controller.dart';
import 'package:roam_io/features/map/data/place_details_sheet.dart';

import '../../../support/map_test_doubles.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  testWidgets('shows place title and distance when not visited', (tester) async {
    final controller = MapController(
      geoLocatorService: FakeGeoLocatorService(testPosition(-37.8136, 144.9631)),
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
      geoLocatorService: FakeGeoLocatorService(testPosition(-37.8136, 144.9631)),
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
