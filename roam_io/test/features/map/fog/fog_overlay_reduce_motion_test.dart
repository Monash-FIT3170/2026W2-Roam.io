/*
 * Description:
 *   Reduce Motion behaviour for the fog overlay: ambient wind drift stops, and
 *   unlock dissolves and fog returns resolve at once instead of animating.
 */

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/fog/fog_atlas.dart';
import 'package:roam_io/features/map/fog/fog_controller.dart';
import 'package:roam_io/features/map/fog/fog_overlay.dart';
import 'package:roam_io/features/map/fog/fog_painter.dart';
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

  FogController readyController() => FogController()
    ..setAnchor(_anchor)
    ..updateCamera(_camera)
    ..markViewportLoaded();

  group('FogOverlay with Reduce Motion', () {
    testWidgets('does not drift the clouds', (tester) async {
      final controller = readyController();
      await _pump(tester, controller, atlas: atlas, reduceMotion: true);

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(_fogPainter(tester).windOffset, Offset.zero);
      controller.dispose();
    });

    testWidgets('still drifts the clouds when motion is allowed', (
      tester,
    ) async {
      final controller = readyController();
      await _pump(tester, controller, atlas: atlas, reduceMotion: false);

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(_fogPainter(tester).windOffset, isNot(Offset.zero));
      controller.dispose();
    });

    testWidgets('clears an unlock dissolve immediately and keeps the hole', (
      tester,
    ) async {
      final controller = readyController();
      await _pump(tester, controller, atlas: atlas, reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 100));

      controller.startDissolve(region: _region('a'), userLatLng: _anchor);
      expect(controller.dissolveSet.contains('a'), isTrue);

      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.dissolveSet.isEmpty, isTrue);
      expect(controller.geometry!.contains('a'), isTrue);
      controller.dispose();
    });

    testWidgets('keeps an unlock dissolve running when motion is allowed', (
      tester,
    ) async {
      final controller = readyController();
      await _pump(tester, controller, atlas: atlas, reduceMotion: false);
      await tester.pump(const Duration(milliseconds: 100));

      controller.startDissolve(region: _region('a'), userLatLng: _anchor);
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.dissolveSet.contains('a'), isTrue);
      controller.dispose();
    });

    testWidgets('completes a fog return without the Skip button', (
      tester,
    ) async {
      final completed = <Set<String>>[];
      final controller = readyController()..addClearedRegion(_region('a'));
      controller.onFogReturnCompleted = completed.add;
      controller.startFogReturn(<String>{'a'});

      await _pump(tester, controller, atlas: atlas, reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(controller.returnTransition, isNull);
      expect(controller.geometry!.contains('a'), isFalse);
      expect(completed, hasLength(1));
      expect(
        find.byKey(const ValueKey<String>('skip-fog-return-animation')),
        findsNothing,
      );
      controller.dispose();
    });
  });
}

Future<void> _pump(
  WidgetTester tester,
  FogController controller, {
  required FogAtlas atlas,
  required bool reduceMotion,
}) {
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: Stack(
          children: <Widget>[
            FogOverlay(
              controller: controller,
              isActive: true,
              atlasOverride: atlas,
            ),
          ],
        ),
      ),
    ),
  );
}

FogPainter _fogPainter(WidgetTester tester) {
  final paint = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is FogPainter,
  );
  return tester.widget<CustomPaint>(paint).painter! as FogPainter;
}

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
