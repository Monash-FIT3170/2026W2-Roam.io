import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/hazards/data/hazard_controller.dart';
import 'package:roam_io/features/hazards/data/hazard_repository.dart';
import 'package:roam_io/features/hazards/domain/hazard_category.dart';
import 'package:roam_io/features/hazards/domain/hazard_report.dart';
import 'package:roam_io/features/journeys/data/journey_controller.dart';
import 'package:roam_io/features/map/data/map_controller.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';
import 'package:roam_io/features/map/data/places_service.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/widgets/roammate_overlay.dart';
import 'package:roam_io/features/roammate/services/roammate_voice_service.dart';

import '../../../support/map_test_doubles.dart';

class _FakePlacesService extends PlacesService {
  _FakePlacesService([
    this._places = const [],
    this._placesByRegion = const {},
  ]);
  final List<PlaceOfInterest> _places;
  final Map<String, List<PlaceOfInterest>> _placesByRegion;

  @override
  Future<List<PlaceOfInterest>> getPlacesForRegion({
    required String regionId,
  }) async {
    if (_placesByRegion.containsKey(regionId)) {
      return _placesByRegion[regionId]!;
    }
    return _places;
  }
}

RegionPolygon _createRegion({required String id, required String name}) {
  return RegionPolygon(
    id: id,
    name: name,
    areaSquareMetres: 1000.0,
    geometry: const {},
  );
}

PlaceOfInterest _createPlace({required int id, required String name}) {
  return testPlace(id: id, name: name);
}

class _FakeSpeechEngine implements RoammateSpeechEngine {
  final List<String> spokenMessages = [];

  @override
  Future<void> speak(String text) async {
    spokenMessages.add(text);
  }

  @override
  Future<void> stop() async {}
}

class _TestJourneyController extends ChangeNotifier
    implements JourneyController {
  bool _isTracking = false;
  double _distanceMeters = 0.0;
  final List<String> _unlockedTileIds = [];

  @override
  bool get isTracking => _isTracking;

  @override
  double get distanceMeters => _distanceMeters;

  @override
  List<String> get unlockedTileIds => List.unmodifiable(_unlockedTileIds);

  @override
  Future<void> startTracking() async {
    _isTracking = true;
    notifyListeners();
  }

  @override
  Future<void> stopTracking() async {
    _isTracking = false;
    notifyListeners();
  }

  void unlockTile(String tileId) {
    _unlockedTileIds.add(tileId);
    notifyListeners();
  }

  void updateDistance(double meters) {
    _distanceMeters = meters;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHazardController extends HazardController {
  _TestHazardController({List<HazardReport> initialReports = const []})
    : _testReports = initialReports,
      super(repository: HazardRepository(firestore: FakeFirebaseFirestore()));

  List<HazardReport> _testReports;

  @override
  List<HazardReport> get activeReports => List.unmodifiable(_testReports);

  void updateReports(List<HazardReport> reports) {
    _testReports = reports;
    notifyListeners();
  }
}

HazardReport _createHazard({
  required String id,
  required HazardCategory category,
  required double latitude,
  required double longitude,
  String? description,
}) {
  final now = DateTime.now();
  return HazardReport(
    id: id,
    reporterId: 'reporter_1',
    category: category,
    latitude: latitude,
    longitude: longitude,
    description: description,
    createdAt: now,
    lastConfirmedAt: now,
    expiresAt: now.add(const Duration(hours: 2)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MapController mapController;
  late _TestHazardController hazardController;
  late _TestJourneyController journeyController;
  late _FakeSpeechEngine speechEngine;
  late RoammateVoiceService voiceService;

  setUp(() {
    mapController = MapController(
      geoLocatorService: FakeGeoLocatorService(
        testPosition(-37.8136, 144.9631),
      ),
      visitService: RecordingVisitService(),
      visitedRegionService: FakeVisitedRegionService(),
    );
    // Set user position near Melbourne CBD
    mapController.center = const LatLng(-37.8136, 144.9631);
    hazardController = _TestHazardController();
    journeyController = _TestJourneyController();
    speechEngine = _FakeSpeechEngine();
    voiceService = RoammateVoiceService(speechEngine: speechEngine);
  });

  tearDown(() {
    mapController.disposeController();
    mapController.dispose();
    hazardController.dispose();
    journeyController.dispose();
  });

  Widget buildTestWidget({
    void Function(HazardReport report)? onHazardSelected,
    void Function(PlaceOfInterest place)? onPlaceSelected,
    JourneyController? journeyController,
    double proximityRadiusMeters = 500.0,
    AuthProvider? authProvider,
    PlacesService? placesService,
    Duration tileDwellDuration = const Duration(milliseconds: 3500),
    Duration autoCollapseDuration = const Duration(seconds: 5),
    Duration recommendationAutoCollapseDuration = const Duration(seconds: 8),
    Duration tileAnnouncementCooldown = const Duration(minutes: 3),
    double maxSpeedMpsForPopup = 25.0 / 3.6,
  }) {
    Widget child = MaterialApp(
      home: Scaffold(
        body: RoammateOverlay(
          mapController: mapController,
          hazardController: hazardController,
          journeyController: journeyController,
          onHazardSelected: onHazardSelected,
          onPlaceSelected: onPlaceSelected,
          voiceService: voiceService,
          placesService: placesService ?? _FakePlacesService(),
          proximityRadiusMeters: proximityRadiusMeters,
          tileDwellDuration: tileDwellDuration,
          autoCollapseDuration: autoCollapseDuration,
          recommendationAutoCollapseDuration:
              recommendationAutoCollapseDuration,
          tileAnnouncementCooldown: tileAnnouncementCooldown,
          maxSpeedMpsForPopup: maxSpeedMpsForPopup,
        ),
      ),
    );

    if (authProvider != null) {
      child = ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: child,
      );
    }

    return child;
  }

  testWidgets(
    'does not show hazard section when no active hazards are nearby',
    (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Open details
      await tester.tap(find.byIcon(Icons.smart_toy_rounded));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Locations in this tile'), findsOneWidget);
      expect(find.textContaining('Hazard'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    },
  );

  testWidgets('filters out hazards outside the proximity radius', (
    tester,
  ) async {
    // Hazard ~2.5km away
    hazardController.updateReports([
      _createHazard(
        id: 'far_hazard',
        category: HazardCategory.flooding,
        latitude: -37.8350,
        longitude: 144.9631,
      ),
    ]);

    await tester.pumpWidget(buildTestWidget());
    await tester.pump(const Duration(milliseconds: 100));

    // Open details
    await tester.tap(find.byIcon(Icons.smart_toy_rounded));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Locations in this tile'), findsOneWidget);
    expect(find.textContaining('Flooding'), findsNothing);
  });

  testWidgets(
    'displays single hazard card within 500m and tapping animates and triggers callback',
    (tester) async {
      // ~100m away
      final report = _createHazard(
        id: 'hazard_pothole_1',
        category: HazardCategory.pothole,
        latitude: -37.8145,
        longitude: 144.9631,
        description: 'Deep crater in right lane',
      );
      hazardController.updateReports([report]);

      HazardReport? selectedReport;
      await tester.pumpWidget(
        buildTestWidget(onHazardSelected: (r) => selectedReport = r),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Open details
      await tester.tap(find.byIcon(Icons.smart_toy_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Hazard card is visible
      expect(find.text('Pothole'), findsOneWidget);
      expect(find.text('Deep crater in right lane'), findsOneWidget);
      expect(find.textContaining('away'), findsOneWidget);

      // Tap hazard card
      await tester.tap(find.text('Pothole'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Callback invoked
      expect(selectedReport?.id, 'hazard_pothole_1');
      // Details dismissed
      expect(find.text('Locations in this tile'), findsNothing);
    },
  );

  testWidgets(
    'displays collapsible summary for multiple hazards and orders by distance',
    (tester) async {
      // Hazard A is ~200m away
      final reportFar = _createHazard(
        id: 'hazard_far',
        category: HazardCategory.crash,
        latitude: -37.8154,
        longitude: 144.9631,
        description: 'Multi-vehicle crash',
      );
      // Hazard B is ~80m away
      final reportClose = _createHazard(
        id: 'hazard_close',
        category: HazardCategory.roadworks,
        latitude: -37.8143,
        longitude: 144.9631,
        description: 'Lane closed for resurfacing',
      );

      // Add in reverse order
      hazardController.updateReports([reportFar, reportClose]);

      HazardReport? selectedReport;
      await tester.pumpWidget(
        buildTestWidget(onHazardSelected: (r) => selectedReport = r),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Open details
      await tester.tap(find.byIcon(Icons.smart_toy_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Header summary is shown
      expect(find.text('2 Hazards Nearby'), findsOneWidget);
      expect(find.textContaining('Closest'), findsOneWidget);

      // By default list is collapsed
      expect(find.text('Lane closed for resurfacing'), findsNothing);

      // Tap summary to expand
      await tester.tap(find.text('2 Hazards Nearby'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Both hazards are visible now
      expect(find.text('Roadworks'), findsOneWidget);
      expect(find.text('Lane closed for resurfacing'), findsOneWidget);
      expect(find.text('Crash'), findsOneWidget);
      expect(find.text('Multi-vehicle crash'), findsOneWidget);

      // Closer hazard appears first
      final roadworksPos = tester.getTopLeft(find.text('Roadworks')).dy;
      final crashPos = tester.getTopLeft(find.text('Crash')).dy;
      expect(roadworksPos, lessThan(crashPos));

      // Tapping an item triggers callback and closes details
      await tester.tap(find.text('Crash'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(selectedReport?.id, 'hazard_far');
      expect(find.text('Locations in this tile'), findsNothing);
    },
  );

  testWidgets(
    'announces hazard voice alert once per hazard when TTS is enabled',
    (tester) async {
      final authProvider = _TestAuthProvider(voiceEnabled: true);

      final report = _createHazard(
        id: 'hazard_tts_1',
        category: HazardCategory.slipperySurface,
        latitude: -37.8140,
        longitude: 144.9631,
      );
      hazardController.updateReports([report]);

      await tester.pumpWidget(buildTestWidget(authProvider: authProvider));
      await tester.pump(const Duration(milliseconds: 100));

      expect(speechEngine.spokenMessages.length, 1);
      expect(
        speechEngine.spokenMessages.first,
        contains('Caution: Slippery surface reported'),
      );

      // Second pump / controller update with same hazard does not speak again
      hazardController.updateReports([report]);
      await tester.pump(const Duration(milliseconds: 100));

      expect(speechEngine.spokenMessages.length, 1);
      authProvider.dispose();
    },
  );

  testWidgets(
    'auto-expands and displays banner with locations and hazards count after dwell time',
    (tester) async {
      final region = _createRegion(id: 'clayton_1', name: 'Monash Clayton');
      final place1 = _createPlace(id: 1, name: 'Campus Centre');
      final place2 = _createPlace(id: 2, name: 'Matheson Library');
      final fakePlaces = _FakePlacesService([place1, place2]);

      final hazard = _createHazard(
        id: 'hazard_1',
        category: HazardCategory.roadworks,
        latitude: -37.8136,
        longitude: 144.9631,
      );
      hazardController.updateReports([hazard]);

      mapController.currentRegion = region;

      await tester.pumpWidget(
        buildTestWidget(
          placesService: fakePlaces,
          tileDwellDuration: const Duration(milliseconds: 300),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Initially within dwell time: card is NOT yet open
      expect(find.textContaining('Entered Monash Clayton'), findsNothing);

      // Advance beyond dwell time (300ms)
      await tester.pump(const Duration(milliseconds: 300));
      // Advance scale animation
      await tester.pump(const Duration(milliseconds: 400));

      // Banner is visible with correct location and hazard counts
      expect(
        find.text('Entered Monash Clayton • 2 locations, 1 hazard'),
        findsOneWidget,
      );
      // Detail content is visible
      expect(find.text('Locations in this tile'), findsOneWidget);
      expect(find.text('Campus Centre'), findsOneWidget);
      expect(find.text('Matheson Library'), findsOneWidget);
      expect(find.text('Roadworks'), findsOneWidget);
    },
  );

  testWidgets(
    'suppresses tile entry notification when travelling fast (> 25 km/h)',
    (tester) async {
      final region = _createRegion(id: 'cbd_1', name: 'Melbourne CBD');
      mapController.currentRegion = region;
      // Set speed to 30 km/h (≈ 8.33 m/s > 6.94 m/s threshold)
      mapController.setPositionForTesting(
        testPosition(-37.8136, 144.9631, speed: 30.0 / 3.6),
      );

      await tester.pumpWidget(
        buildTestWidget(tileDwellDuration: const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Advance beyond dwell time
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 400));

      // Banner and details should NOT be shown
      expect(find.textContaining('Entered Melbourne CBD'), findsNothing);
      expect(find.text('Locations in this tile'), findsNothing);
    },
  );

  testWidgets(
    'enforces cooldown so re-entering the same tile within 3 minutes does not re-trigger',
    (tester) async {
      final regionA = _createRegion(id: 'tile_a', name: 'Tile Alpha');
      final regionB = _createRegion(id: 'tile_b', name: 'Tile Beta');

      mapController.currentRegion = regionA;

      await tester.pumpWidget(
        buildTestWidget(
          tileDwellDuration: const Duration(milliseconds: 200),
          tileAnnouncementCooldown: const Duration(minutes: 3),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Dwell in Tile Alpha
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      // Tile Alpha banner shown
      expect(find.textContaining('Entered Tile Alpha'), findsOneWidget);

      // Close details
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Entered Tile Alpha'), findsNothing);

      // Move to Tile Beta
      mapController.currentRegion = regionB;
      mapController.notifyListeners();
      await tester.pump(const Duration(milliseconds: 50));

      // Dwell in Tile Beta
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Entered Tile Beta'), findsOneWidget);

      // Close details
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Entered Tile Beta'), findsNothing);

      // Move BACK to Tile Alpha within cooldown
      mapController.currentRegion = regionA;
      mapController.notifyListeners();
      await tester.pump(const Duration(milliseconds: 50));

      // Dwell in Tile Alpha again
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));

      // Should NOT pop up again because cooldown is 3 minutes
      expect(find.textContaining('Entered Tile Alpha'), findsNothing);
    },
  );

  testWidgets('auto-collapses after autoCollapseDuration if untouched', (
    tester,
  ) async {
    final region = _createRegion(
      id: 'tile_collapse',
      name: 'Auto Collapse Tile',
    );
    mapController.currentRegion = region;

    await tester.pumpWidget(
      buildTestWidget(
        tileDwellDuration: const Duration(milliseconds: 200),
        autoCollapseDuration: const Duration(seconds: 2),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Dwell and open
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Entered Auto Collapse Tile'), findsOneWidget);

    // Advance 2s auto-collapse timer
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));

    // Card should be auto-collapsed now
    expect(find.textContaining('Entered Auto Collapse Tile'), findsNothing);
    expect(find.text('Locations in this tile'), findsNothing);
  });

  testWidgets(
    'cancels auto-collapse when user touches or interacts with the card',
    (tester) async {
      final region = _createRegion(id: 'tile_touch', name: 'Interactive Tile');
      mapController.currentRegion = region;

      await tester.pumpWidget(
        buildTestWidget(
          tileDwellDuration: const Duration(milliseconds: 200),
          autoCollapseDuration: const Duration(seconds: 2),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Dwell and open
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Entered Interactive Tile'), findsOneWidget);

      // User touches/taps on the card
      await tester.tap(find.text('Locations in this tile'));
      await tester.pump();

      // Advance beyond the 2s auto-collapse timer
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));

      // Card should STILL be open because user interaction cancelled auto-collapse!
      expect(find.textContaining('Entered Interactive Tile'), findsOneWidget);
      expect(find.text('Locations in this tile'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the banner close button (✕) dismisses the banner and collapses card immediately',
    (tester) async {
      final region = _createRegion(id: 'tile_close', name: 'Closable Tile');
      mapController.currentRegion = region;

      await tester.pumpWidget(
        buildTestWidget(tileDwellDuration: const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Dwell and open
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Entered Closable Tile'), findsOneWidget);

      // Tap (✕) button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Entered Closable Tile'), findsNothing);
      expect(find.text('Locations in this tile'), findsNothing);
    },
  );

  testWidgets(
    'cancels dwell timer if user leaves tile before dwell duration finishes',
    (tester) async {
      final region = _createRegion(id: 'tile_quick', name: 'Quick Step Tile');
      mapController.currentRegion = region;

      await tester.pumpWidget(
        buildTestWidget(tileDwellDuration: const Duration(milliseconds: 500)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Only 200ms into dwell (not yet 500ms), user exits tile
      await tester.pump(const Duration(milliseconds: 200));
      mapController.currentRegion = null;
      mapController.notifyListeners();
      await tester.pump(const Duration(milliseconds: 50));

      // Now advance remaining 400ms
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Never popped up
      expect(find.textContaining('Entered Quick Step Tile'), findsNothing);
      expect(find.text('Locations in this tile'), findsNothing);
    },
  );

  testWidgets(
    'first tile unlock during active journey triggers recommendation for highest-rated unvisited place and speaks via voice',
    (tester) async {
      final authProvider = _TestAuthProvider(voiceEnabled: true);
      final places = [
        testPlace(
          id: 101,
          name: 'Corner Cafe',
          rating: 4.1,
          location: const LatLng(-37.8130, 144.9630),
        ),
        testPlace(
          id: 102,
          name: 'State Library',
          rating: 4.9,
          location: const LatLng(-37.8120, 144.9620),
        ),
        testPlace(
          id: 103,
          name: 'Bus Stop 12',
          category: PlaceCategory.publicTransport,
          rating: 5.0,
          location: const LatLng(-37.8110, 144.9610),
        ),
      ];
      final placesService = _FakePlacesService([], {'tile_1': places});
      mapController.currentRegion = _createRegion(
        id: 'tile_1',
        name: 'Carlton',
      );

      await tester.pumpWidget(
        buildTestWidget(
          journeyController: journeyController,
          authProvider: authProvider,
          placesService: placesService,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Journey is not tracking yet -> unlocking tile does not trigger recommendation
      journeyController.unlockTile('tile_1');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Roammate suggests:'), findsNothing);

      // Start tracking
      journeyController.startTracking();
      // Allow async fetch & build
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      // Recommendation should be visible for State Library (highest unvisited rating 4.9, public transport excluded)
      expect(
        find.textContaining('Roammate suggests: State Library ★ 4.9'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);

      // Verify voice announcement was triggered
      expect(speechEngine.spokenMessages.length, 1);
      expect(speechEngine.spokenMessages.first, contains('State Library'));
      expect(speechEngine.spokenMessages.first, contains('rated 4.9'));
      expect(speechEngine.spokenMessages.first, contains('Carlton'));
    },
  );

  testWidgets(
    'tapping recommendation banner navigates to location and triggers onPlaceSelected without stopping journey tracking',
    (tester) async {
      final library = testPlace(
        id: 201,
        name: 'Matheson Library',
        rating: 4.8,
        location: const LatLng(-37.9100, 145.1300),
      );
      final placesService = _FakePlacesService([], {
        'tile_uni': [library],
      });

      PlaceOfInterest? selectedPlace;
      await tester.pumpWidget(
        buildTestWidget(
          journeyController: journeyController,
          placesService: placesService,
          onPlaceSelected: (p) => selectedPlace = p,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      journeyController.startTracking();
      journeyController.unlockTile('tile_uni');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Matheson Library'), findsOneWidget);

      // Tap recommendation banner
      await tester.tap(find.textContaining('Matheson Library'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Callback invoked with selected place
      expect(selectedPlace?.id, 201);
      expect(selectedPlace?.name, 'Matheson Library');

      // Banner is dismissed
      expect(find.textContaining('Roammate suggests:'), findsNothing);

      // Journey is STILL tracking!
      expect(journeyController.isTracking, isTrue);
    },
  );

  testWidgets(
    'subsequent 1 km distance milestone triggers next unvisited recommendation',
    (tester) async {
      final placeA = testPlace(
        id: 301,
        name: 'First Stop Coffee',
        rating: 4.9,
        location: const LatLng(-37.8130, 144.9630),
      );
      final placeB = testPlace(
        id: 302,
        name: 'Second Stop Park',
        rating: 4.7,
        location: const LatLng(-37.8140, 144.9640),
      );
      final placesService = _FakePlacesService([], {
        'tile_1': [placeA, placeB],
      });

      await tester.pumpWidget(
        buildTestWidget(
          journeyController: journeyController,
          placesService: placesService,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // First unlock triggers placeA
      journeyController.startTracking();
      journeyController.unlockTile('tile_1');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('First Stop Coffee'), findsOneWidget);

      // Dismiss first banner via (✕) close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('First Stop Coffee'), findsNothing);

      // Progress distance by 500m (not yet 1000m milestone)
      journeyController.updateDistance(500.0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Roammate suggests:'), findsNothing);

      // Reach 1,000m milestone!
      journeyController.updateDistance(1005.0);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      // Second recommendation should pop up with placeB
      expect(find.textContaining('Second Stop Park'), findsOneWidget);
    },
  );

  testWidgets(
    'does not trigger recommendation if all places in unlocked tiles are already visited',
    (tester) async {
      final visitedPlace = testPlace(
        id: 401,
        name: 'Already Seen Monument',
        rating: 5.0,
      );
      final placesService = _FakePlacesService([], {
        'tile_done': [visitedPlace],
      });

      await mapController.setUserId('test-user');
      await mapController.markPlaceAsVisited(visitedPlace);

      await tester.pumpWidget(
        buildTestWidget(
          journeyController: journeyController,
          placesService: placesService,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      journeyController.startTracking();
      journeyController.unlockTile('tile_done');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      // No recommendation banner shown (no generic spam)
      expect(find.textContaining('Roammate suggests:'), findsNothing);
    },
  );

  testWidgets(
    'auto-collapses recommendation banner after recommendationAutoCollapseDuration unless user interacts',
    (tester) async {
      final place = testPlace(id: 501, name: 'Quiet Garden', rating: 4.5);
      final placesService = _FakePlacesService([], {
        'tile_garden': [place],
      });

      await tester.pumpWidget(
        buildTestWidget(
          journeyController: journeyController,
          placesService: placesService,
          recommendationAutoCollapseDuration: const Duration(seconds: 2),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      journeyController.startTracking();
      journeyController.unlockTile('tile_garden');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Quiet Garden'), findsOneWidget);

      // User touches the card to cancel auto-collapse
      await tester.tap(find.text('Locations in this tile'));
      await tester.pump();

      // Advance past 2s
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));

      // Card is still open because user interaction cancelled auto-collapse!
      expect(find.textContaining('Quiet Garden'), findsOneWidget);

      // Now close with ✕ button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Quiet Garden'), findsNothing);
    },
  );

  testWidgets('auto-collapses recommendation banner if left untouched', (
    tester,
  ) async {
    final place = testPlace(id: 601, name: 'Fleeting View', rating: 4.6);
    final placesService = _FakePlacesService([], {
      'tile_view': [place],
    });

    await tester.pumpWidget(
      buildTestWidget(
        journeyController: journeyController,
        placesService: placesService,
        recommendationAutoCollapseDuration: const Duration(seconds: 2),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    journeyController.startTracking();
    journeyController.unlockTile('tile_view');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Fleeting View'), findsOneWidget);

    // Advance past 2s untouched
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));

    // Card collapsed automatically
    expect(find.textContaining('Fleeting View'), findsNothing);
  });
}

class _DummyAuthRepository implements AuthRepository {
  @override
  Stream<firebase_auth.User?> authStateChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAuthProvider extends AuthProvider {
  _TestAuthProvider({this.voiceEnabled = true})
    : super(authRepository: _DummyAuthRepository());
  final bool voiceEnabled;

  @override
  bool get roammateVoiceEnabled => voiceEnabled;
}
