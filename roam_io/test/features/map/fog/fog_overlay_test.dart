import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/fog/fog_atlas.dart';
import 'package:roam_io/features/map/fog/fog_controller.dart';
import 'package:roam_io/features/map/fog/fog_overlay.dart';
import 'package:roam_io/features/map/fog/fog_painter.dart';
import 'package:roam_io/features/map/fog/fog_palette.dart';
import 'package:roam_io/features/map/fog/fog_projection.dart';

const LatLng _anchor = LatLng(-37.8136, 144.9631);
const CameraPosition _camera = CameraPosition(
  target: _anchor,
  zoom: kReferenceZoom,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FogAtlas atlas;

  setUpAll(() async {
    atlas = await _syntheticAtlas();
  });

  tearDownAll(() => atlas.dispose());

  group('FogOverlay', () {
    testWidgets('draws nothing until the viewport has loaded', (tester) async {
      // Fail-open. A failed Firestore read or spatial API call must leave the
      // map visible rather than hiding it behind cloud the user cannot clear.
      final controller = FogController()
        ..setAnchor(_anchor)
        ..updateCamera(_camera);

      await _pump(tester, controller, atlas: atlas);

      expect(_fogPaintFinder, findsNothing);

      controller.dispose();
    });

    testWidgets('draws once ready, even with nothing explored', (tester) async {
      // A brand new account legitimately has zero cleared regions. Readiness is
      // tracked explicitly for exactly this case — inferring it from an empty
      // hole set would leave new users with no fog at all.
      final controller = FogController()
        ..setAnchor(_anchor)
        ..updateCamera(_camera)
        ..markViewportLoaded();

      await _pump(tester, controller, atlas: atlas);

      expect(_fogPaintFinder, findsOneWidget);

      controller.dispose();
    });

    testWidgets('lets map gestures through', (tester) async {
      final controller = FogController()
        ..setAnchor(_anchor)
        ..updateCamera(_camera)
        ..markViewportLoaded();

      await _pump(tester, controller, atlas: atlas);

      // The overlay covers the whole map, so anything but IgnorePointer would
      // swallow every pan, pinch and marker tap.
      final ignorePointer = tester.widget<IgnorePointer>(
        find
            .ancestor(of: _fogPaintFinder, matching: find.byType(IgnorePointer))
            .first,
      );

      expect(ignorePointer.ignoring, isTrue);
    });

    testWidgets('stops ticking when the map tab is not selected', (
      tester,
    ) async {
      // MainShellScreen keeps every page mounted in an IndexedStack with
      // maintainAnimation: true, so without gating this would animate clouds
      // nobody can see for as long as the app is open.
      final controller = FogController()
        ..setAnchor(_anchor)
        ..updateCamera(_camera)
        ..markViewportLoaded();

      await _pump(tester, controller, atlas: atlas, isActive: false);
      await tester.pump(const Duration(seconds: 1));

      expect(controller.clock, Duration.zero);

      controller.dispose();
    });

    testWidgets('advances its clock while active', (tester) async {
      final controller = FogController()
        ..setAnchor(_anchor)
        ..updateCamera(_camera)
        ..markViewportLoaded();

      await _pump(tester, controller, atlas: atlas);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.clock, greaterThan(Duration.zero));

      controller.dispose();
    });

    testWidgets('paints every frame while the camera is moving', (
      tester,
    ) async {
      // The symptom this guards: clouds visibly trailing the map during a pan.
      // Movement used to run through a gate whose interval was the vsync period
      // itself, so a frame arriving fractionally early was dropped whole and
      // the fog painted at roughly half the map's rate.
      final controller = FogController()
        ..setAnchor(_anchor)
        ..updateCamera(_camera, isMoving: true)
        ..markViewportLoaded();

      await _pump(tester, controller, atlas: atlas);

      // 8ms apart: a 120Hz display, where the old gate dropped exactly half.
      expect(await _paintedFrames(tester, controller, frames: 5), 5);

      controller.dispose();
    });

    testWidgets('paces itself down once the camera settles', (tester) async {
      // The other half of the same trade: idle clouds drift slowly enough that
      // painting every vsync is wasted work.
      final controller = FogController()
        ..setAnchor(_anchor)
        ..updateCamera(_camera)
        ..markViewportLoaded();

      await _pump(tester, controller, atlas: atlas);

      expect(await _paintedFrames(tester, controller, frames: 5), lessThan(3));

      controller.dispose();
    });

    testWidgets('sheds the parallax cloud layer while the camera moves', (
      tester,
    ) async {
      // Two cloud layers at roughly 4x full-screen overdraw each are the
      // overlay's whole fill-rate cost, so the fainter one gives way to a
      // moving camera — ramped, because cutting it dead pops the fog's density.
      final controller = FogController()
        ..setAnchor(_anchor)
        ..updateCamera(_camera, isMoving: true)
        ..markViewportLoaded();

      await _pump(tester, controller, atlas: atlas);
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        _fogPainter(tester).motionEase,
        greaterThan(0.0),
        reason: 'the layer must fade rather than vanish on the first frame',
      );

      await tester.pump(FogPalette.motionEaseOut);
      expect(_fogPainter(tester).motionEase, 0.0);

      controller.setCameraMoving(false);
      await tester.pump(FogPalette.motionEaseIn);

      expect(
        _fogPainter(tester).motionEase,
        1.0,
        reason: 'the layer must come back once the map settles',
      );

      controller.dispose();
    });

    testWidgets('keeps animating after the app returns to the foreground', (
      tester,
    ) async {
      // Ticker.start resets elapsed to zero, so a _lastPaint carried across the
      // pause sits in the future and gates every frame after it — the fog
      // frozen for as long as the app had previously been open.
      final controller = FogController()
        ..setAnchor(_anchor)
        ..updateCamera(_camera)
        ..markViewportLoaded();

      await _pump(tester, controller, atlas: atlas);
      await tester.pump(const Duration(seconds: 2));

      final beforePause = controller.clock;
      expect(beforePause, greaterThan(Duration.zero));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.clock, isNot(beforePause));

      controller.dispose();
    });

    testWidgets('switches the cloud palette when app brightness changes', (
      tester,
    ) async {
      final controller = FogController()
        ..setAnchor(_anchor)
        ..updateCamera(_camera)
        ..markViewportLoaded();

      await _pump(tester, controller, atlas: atlas, theme: ThemeData.light());
      expect(_fogPainter(tester).isNight, isFalse);

      await _pump(tester, controller, atlas: atlas, theme: ThemeData.dark());
      expect(_fogPainter(tester).isNight, isTrue);

      controller.dispose();
    });

    testWidgets('shows Skip only while fog return is active', (tester) async {
      final completed = <Set<String>>[];
      final controller = FogController()
        ..setAnchor(_anchor)
        ..updateCamera(_camera)
        ..markViewportLoaded()
        ..addClearedRegion(_region('a'));
      controller.onFogReturnCompleted = (ids) => completed.add(ids);
      controller.startFogReturn(<String>{'a'});

      await _pump(tester, controller, atlas: atlas);
      final skip = find.byKey(
        const ValueKey<String>('skip-fog-return-animation'),
      );
      expect(skip, findsOneWidget);

      await tester.tap(skip);
      await tester.pump();

      expect(skip, findsNothing);
      expect(controller.returnTransition, isNull);
      expect(controller.geometry!.contains('a'), isFalse);
      expect(completed, hasLength(1));

      controller.dispose();
    });
  });

  group('FogController', () {
    test('is not ready before an anchor exists', () {
      final controller = FogController()..markViewportLoaded();

      expect(controller.isReady, isFalse);

      controller.dispose();
    });

    test('keeps the first anchor so world coordinates stay stable', () {
      // Re-anchoring mid-session would silently invalidate every cached path.
      final controller = FogController()
        ..setAnchor(_anchor)
        ..setAnchor(const LatLng(0, 0));

      expect(controller.projection!.anchor, _anchor);

      controller.dispose();
    });

    test('adds cleared regions once', () {
      final controller = FogController()..setAnchor(_anchor);

      controller
        ..addClearedRegion(_region('a'))
        ..addClearedRegion(_region('a'))
        ..addClearedRegion(_region('b'));

      expect(controller.geometry!.length, 2);

      controller.dispose();
    });

    test('starting a dissolve registers the region and the animation', () {
      final controller = FogController()..setAnchor(_anchor);

      controller.startDissolve(region: _region('a'), userLatLng: _anchor);

      expect(controller.dissolveSet.contains('a'), isTrue);
      expect(
        controller.geometry!.contains('a'),
        isTrue,
        reason: 'the hole must exist so it can ramp in behind the clouds',
      );

      controller.dispose();
    });

    test('a repeated unlock does not stack two bursts', () {
      final controller = FogController()..setAnchor(_anchor);

      controller
        ..startDissolve(region: _region('a'), userLatLng: _anchor)
        ..startDissolve(region: _region('a'), userLatLng: _anchor);

      expect(controller.dissolveSet.active, hasLength(1));

      controller.dispose();
    });

    test('completed dissolves are pruned into permanent holes', () {
      final controller = FogController()..setAnchor(_anchor);

      controller.startDissolve(region: _region('a'), userLatLng: _anchor);
      expect(controller.pruneCompletedDissolves(), isFalse);

      controller.tick(const Duration(seconds: 5));

      expect(controller.pruneCompletedDissolves(), isTrue);
      expect(controller.dissolveSet.isEmpty, isTrue);
      expect(controller.geometry!.contains('a'), isTrue);

      controller.dispose();
    });

    test('fog return batches regions and reports completion once', () {
      final completed = <Set<String>>[];
      final controller = FogController()
        ..setAnchor(_anchor)
        ..addClearedRegions(<RegionPolygon>[_region('a'), _region('b')])
        ..onFogReturnCompleted = (ids) => completed.add(ids);

      controller.startFogReturn(<String>{'a', 'b'});
      expect(controller.returnTransition?.regionIds, <String>{'a', 'b'});
      expect(controller.returnTransition?.duration, const Duration(seconds: 6));
      expect(controller.pruneCompletedFogReturn(), isFalse);

      controller.tick(const Duration(seconds: 5));
      expect(controller.pruneCompletedFogReturn(), isFalse);

      controller.tick(const Duration(seconds: 6));
      expect(controller.pruneCompletedFogReturn(), isTrue);
      expect(controller.geometry!.contains('a'), isFalse);
      expect(controller.geometry!.contains('b'), isFalse);
      expect(completed, <Set<String>>[
        <String>{'a', 'b'},
      ]);
      expect(controller.pruneCompletedFogReturn(), isFalse);
      expect(completed, hasLength(1));

      controller.dispose();
    });

    test('skipping fog return applies final state and completes once', () {
      final completed = <Set<String>>[];
      final controller = FogController()
        ..setAnchor(_anchor)
        ..addClearedRegions(<RegionPolygon>[_region('a'), _region('b')]);
      controller.onFogReturnCompleted = (ids) => completed.add(ids);
      controller.startFogReturn(<String>{'a', 'b'});

      expect(controller.skipFogReturnAnimation(), isTrue);
      expect(controller.returnTransition, isNull);
      expect(controller.geometry!.contains('a'), isFalse);
      expect(controller.geometry!.contains('b'), isFalse);
      expect(completed, hasLength(1));
      expect(controller.skipFogReturnAnimation(), isFalse);
      expect(completed, hasLength(1));

      controller.dispose();
    });

    test('ignores a non-finite speed rather than corrupting the wind', () {
      final controller = FogController()..setUserSpeed(double.nan);

      expect(controller.userSpeedMetresPerSecond, 0.0);

      controller.dispose();
    });

    test('reset clears holes and readiness for an account switch', () {
      final controller = FogController()
        ..setAnchor(_anchor)
        ..markViewportLoaded()
        ..addClearedRegion(_region('a'));

      expect(controller.isReady, isTrue);

      controller.reset();

      expect(controller.isReady, isFalse);
      expect(controller.geometry!.length, 0);

      controller.dispose();
    });
  });
}

final Finder _fogPaintFinder = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is FogPainter,
);

FogPainter _fogPainter(WidgetTester tester) {
  return tester.widget<CustomPaint>(_fogPaintFinder).painter! as FogPainter;
}

/// How many of [frames] vsyncs the overlay actually painted.
///
/// Counted off the controller's clock, which only advances on a frame the
/// overlay did not pace away.
Future<int> _paintedFrames(
  WidgetTester tester,
  FogController controller, {
  required int frames,
  Duration interval = const Duration(milliseconds: 8),
}) async {
  var painted = 0;
  var previous = controller.clock;

  for (var i = 0; i < frames; i++) {
    await tester.pump(interval);
    if (controller.clock != previous) painted++;
    previous = controller.clock;
  }

  return painted;
}

Future<void> _pump(
  WidgetTester tester,
  FogController controller, {
  required FogAtlas atlas,
  bool isActive = true,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      themeAnimationDuration: Duration.zero,
      home: Stack(
        children: <Widget>[
          FogOverlay(
            controller: controller,
            isActive: isActive,
            atlasOverride: atlas,
          ),
        ],
      ),
    ),
  );
}

RegionPolygon _region(String id) {
  return RegionPolygon(
    id: id,
    name: 'Region $id',
    areaSquareMetres: 1000,
    geometry: const <String, dynamic>{
      'type': 'Polygon',
      'coordinates': <dynamic>[
        <dynamic>[
          <double>[144.90, -37.90],
          <double>[145.00, -37.90],
          <double>[145.00, -37.80],
          <double>[144.90, -37.80],
          <double>[144.90, -37.90],
        ],
      ],
    },
  );
}

/// A tiny opaque atlas. Widget tests must not load the real 2MB artwork: it
/// would dominate their runtime and couple them to art revisions.
Future<FogAtlas> _syntheticAtlas() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 64, 32),
    ui.Paint()..color = const Color(0xFFFFFFFF),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 32);
  picture.dispose();

  return FogAtlas(
    image: image,
    sprites: const <Rect>[
      Rect.fromLTWH(0, 0, 32, 32),
      Rect.fromLTWH(32, 0, 32, 32),
    ],
  );
}
