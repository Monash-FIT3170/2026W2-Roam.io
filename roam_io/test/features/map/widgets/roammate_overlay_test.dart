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
import 'package:roam_io/features/map/data/map_controller.dart';
import 'package:roam_io/features/map/widgets/roammate_overlay.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/features/roammate/services/roammate_voice_service.dart';

import '../../../support/map_test_doubles.dart';

class _FakeSpeechEngine implements RoammateSpeechEngine {
  final List<String> spokenMessages = [];

  @override
  Future<void> speak(String text) async {
    spokenMessages.add(text);
  }

  @override
  Future<void> stop() async {}
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
    speechEngine = _FakeSpeechEngine();
    voiceService = RoammateVoiceService(speechEngine: speechEngine);
  });

  tearDown(() {
    mapController.disposeController();
    mapController.dispose();
    hazardController.dispose();
  });

  Widget buildTestWidget({
    void Function(HazardReport report)? onHazardSelected,
    double proximityRadiusMeters = 500.0,
    AuthProvider? authProvider,
  }) {
    Widget child = MaterialApp(
      home: Scaffold(
        body: RoammateOverlay(
          mapController: mapController,
          hazardController: hazardController,
          onHazardSelected: onHazardSelected,
          voiceService: voiceService,
          proximityRadiusMeters: proximityRadiusMeters,
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
