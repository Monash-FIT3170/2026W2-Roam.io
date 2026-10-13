import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/map_controller.dart';
import 'package:roam_io/features/map/data/place_details_sheet.dart';
import 'package:roam_io/features/map/data/place_marker_manager.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';
import 'package:roam_io/features/map/data/places_service.dart';
import 'package:roam_io/features/map/data/visit_form_sheet.dart';
import 'package:roam_io/features/profile/domain/xp_reward_config.dart';
import 'package:roam_io/theme/app_theme.dart';

import '../../../support/map_test_doubles.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  });

  testWidgets('nearby place becomes visited on sheet and map only after save', (
    tester,
  ) async {
    final harness = await _open(tester);
    expect(harness.controller.markers.single.zIndexInt, 3);
    expect(find.text('In range'), findsOneWidget);
    await _tap(tester, find.text('Mark as Visited'));
    expect(find.byType(VisitFormSheet), findsOneWidget);
    expect(harness.controller.isPlaceVisited(1), isFalse);
    await _tap(tester, find.widgetWithText(ElevatedButton, 'Log Visit'));
    expect(find.byType(VisitFormSheet), findsNothing);
    expect(find.text('Visited'), findsOneWidget);
    expect(find.text('Edit Visit'), findsOneWidget);
    expect(harness.controller.markers.single.zIndexInt, 1);
    expect(harness.visits.markVisitedCallCount, 1);
    expect(harness.awards, [XpRewardConfig.visitXpReward]);
    // Reopening saved history never offers the create action or awards XP.
    await _tap(tester, find.text('Edit Visit'));
    expect(find.text('Save Changes'), findsOneWidget);
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Visited'), findsOneWidget);
    expect(harness.visits.markVisitedCallCount, 1);
    expect(harness.awards, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final lostLocation in [false, true]) {
    testWidgets(
      'save rechecks ${lostLocation ? 'unavailable location' : 'range after moving away'} and allows retry',
      (tester) async {
        final harness = await _open(tester);
        await _tap(tester, find.text('Mark as Visited'));
        harness.geo.setPosition(lostLocation ? null : testPosition(-38, 145));
        await _tap(tester, find.widgetWithText(ElevatedButton, 'Log Visit'));
        expect(find.byType(VisitFormSheet), findsOneWidget);
        expect(
          find.textContaining(
            lostLocation
                ? 'Could not check your location'
                : 'You need to be within 100m',
          ),
          findsOneWidget,
        );
        expect(harness.controller.isPlaceVisited(1), isFalse);
        expect(harness.visits.markVisitedCallCount, 0);
        expect(harness.awards, isEmpty);
        expect(harness.controller.markers.single.zIndexInt, 2);
        harness.geo.setPosition(testPosition(-37.8136, 144.9631));
        await _tap(tester, find.widgetWithText(ElevatedButton, 'Log Visit'));
        expect(find.text('Visited'), findsOneWidget);
        expect(harness.visits.markVisitedCallCount, 1);
        expect(harness.awards, [XpRewardConfig.visitXpReward]);
      },
    );
  }

  testWidgets('failed persistence and cancelled forms never show visited', (
    tester,
  ) async {
    final harness = await _open(tester);
    await _tap(tester, find.text('Mark as Visited'));
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Not visited'), findsOneWidget);
    expect(harness.visits.markVisitedCallCount, 0);
    await _tap(tester, find.text('Mark as Visited'));
    harness.visits.markVisitedError = StateError('offline');
    await _tap(tester, find.widgetWithText(ElevatedButton, 'Log Visit'));
    expect(find.byType(VisitFormSheet), findsOneWidget);
    expect(harness.controller.isPlaceVisited(1), isFalse);
    expect(
      find.text('Could not save your visit. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('StateError'), findsNothing);
    expect(harness.controller.markers.single.zIndexInt, 3);
    expect(harness.awards, isEmpty);
    harness.visits.markVisitedError = null;
    await _tap(tester, find.widgetWithText(ElevatedButton, 'Log Visit'));
    expect(find.text('Visited'), findsOneWidget);
    expect(harness.awards, hasLength(1));
  });

  testWidgets('full detail sheet scrolls on a small display with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _open(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Mark as Visited'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Mark as Visited').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

class _Harness {
  _Harness(this.controller, this.geo, this.visits, this.awards);
  final MapController controller;
  final FakeGeoLocatorService geo;
  final RecordingVisitService visits;
  final List<int> awards;
}

Future<_Harness> _open(WidgetTester tester, {double textScale = 1}) async {
  final geo = FakeGeoLocatorService(testPosition(-37.8136, 144.9631));
  final visits = RecordingVisitService();
  final manager = PlaceMarkerManager(placesService: _Places());
  manager.setVisibleRegionIds({'region-1'});
  await manager.loadPlacesForRegions(
    regionIds: {'region-1'},
    onPlaceTapped: (_) {},
  );
  final awards = <int>[];
  final controller = MapController(
    geoLocatorService: geo,
    visitService: visits,
    visitedRegionService: FakeVisitedRegionService(),
    placeMarkerManager: manager,
  );
  await controller.setUserId('user-1');
  controller.bindVisitXpAwarding((xp) async {
    awards.add(xp);
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => PlaceDetailsSheet.show(
              context: context,
              place: testPlace(),
              mapController: controller,
            ),
            child: const Text('Open location'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open location'));
  await tester.pumpAndSettle();
  addTearDown(() {
    controller.disposeController();
    controller.dispose();
  });
  return _Harness(controller, geo, visits, awards);
}

class _Places extends PlacesService {
  @override
  Future<Map<String, List<PlaceOfInterest>>> getPlacesForRegions({
    required List<String> regionIds,
  }) async => {
    'region-1': [testPlace(location: const LatLng(-37.8136, 144.9631))],
  };
}
