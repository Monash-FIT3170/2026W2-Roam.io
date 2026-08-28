import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/fog/fog_atlas.dart';
import 'package:roam_io/features/map/fog/fog_dissolve.dart';
import 'package:roam_io/features/map/fog/fog_field.dart';
import 'package:roam_io/features/map/fog/fog_geometry.dart';
import 'package:roam_io/features/map/fog/fog_painter.dart';
import 'package:roam_io/features/map/fog/fog_projection.dart';

const LatLng _anchor = LatLng(-37.8136, 144.9631);
const FogProjection _projection = FogProjection(anchor: _anchor);
const Size _size = Size(300, 300);
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

  group('FogPainter', () {
    test('covers the canvas where nothing is explored', () async {
      final image = await _render(geometry: _emptyGeometry(), atlas: atlas);
      final pixels = await _readPixels(image);

      expect(_alphaAt(pixels, image, 150, 150), greaterThan(200));
      expect(_alphaAt(pixels, image, 10, 10), greaterThan(200));

      image.dispose();
    });

    test('clears explored ground', () async {
      // The whole point of the rewrite: fog is the screen minus holes, so an
      // explored region must be genuinely transparent, not merely lighter.
      final geometry = _emptyGeometry()..add(_regionAroundAnchor());

      final image = await _render(geometry: geometry, atlas: atlas);
      final pixels = await _readPixels(image);

      expect(
        _alphaAt(pixels, image, 150, 150),
        lessThan(10),
        reason: 'centre of the explored region must be clear',
      );
      expect(
        _alphaAt(pixels, image, 5, 5),
        greaterThan(200),
        reason: 'unexplored corner must stay fogged',
      );

      image.dispose();
    });

    test('feathers the edge of a hole rather than cutting it', () async {
      // A hard edge reads as a cut-out; the soft ramp is what makes cloud meet
      // clear sky. Scanning the transition rather than sampling one pixel: a
      // hard edge would step from opaque to clear in a pixel or two, a
      // feathered one spreads that step over the blur radius.
      final geometry = _emptyGeometry()..add(_regionAroundAnchor());

      final image = await _render(geometry: geometry, atlas: atlas);
      final pixels = await _readPixels(image);

      var partial = 0;
      for (var y = 0; y < 150; y++) {
        final alpha = _alphaAt(pixels, image, 150, y);
        if (alpha > 20 && alpha < 235) partial++;
      }

      expect(
        partial,
        greaterThan(8),
        reason: 'expected a soft ramp down the column into the cleared region',
      );

      image.dispose();
    });

    test('renders nothing without an atlas', () async {
      final image = await _render(geometry: _emptyGeometry(), atlas: null);
      final pixels = await _readPixels(image);

      // Fail-open. A sprite that failed to load must leave the map visible, not
      // hide it behind a wash with no clouds in it.
      expect(_alphaAt(pixels, image, 150, 150), 0);

      image.dispose();
    });

    test('a dissolving region is not punched out instantly', () async {
      final region = _regionAroundAnchor();
      final geometry = _emptyGeometry()..add(region);

      final dissolve = FogDissolve(
        regionId: region.id,
        worldCentre: Offset.zero,
        regionBounds: geometry.boundsFor(region.id)!,
        wind: const Offset(9, -3.5),
        startedAt: Duration.zero,
      );

      final atStart = await _render(
        geometry: geometry,
        atlas: atlas,
        dissolves: <FogDissolve>[dissolve],
      );
      final startPixels = await _readPixels(atStart);

      expect(
        _alphaAt(startPixels, atStart, 150, 150),
        greaterThan(100),
        reason: 'the region must still be fogged when the tear begins',
      );

      atStart.dispose();
    });

    test('a dissolving region is fully clear by the end', () async {
      final region = _regionAroundAnchor();
      final geometry = _emptyGeometry()..add(region);

      final dissolve = FogDissolve(
        regionId: region.id,
        worldCentre: Offset.zero,
        regionBounds: geometry.boundsFor(region.id)!,
        wind: const Offset(9, -3.5),
        startedAt: Duration.zero,
      );

      final atEnd = await _render(
        geometry: geometry,
        atlas: atlas,
        dissolves: <FogDissolve>[dissolve],
        elapsed: const Duration(milliseconds: 1400),
      );
      final endPixels = await _readPixels(atEnd);

      expect(_alphaAt(endPixels, atEnd, 150, 150), lessThan(10));

      atEnd.dispose();
    });
  });
}

FogGeometry _emptyGeometry() => FogGeometry(projection: _projection);

/// A region roughly filling the middle of the 300x300 canvas.
RegionPolygon _regionAroundAnchor() {
  final southWest = _projection.worldToLatLng(const Offset(-100, 100));
  final northEast = _projection.worldToLatLng(const Offset(100, -100));

  return RegionPolygon(
    id: 'centre',
    name: 'Centre',
    areaSquareMetres: 1000,
    geometry: <String, dynamic>{
      'type': 'Polygon',
      'coordinates': <dynamic>[
        <dynamic>[
          <double>[southWest.longitude, southWest.latitude],
          <double>[northEast.longitude, southWest.latitude],
          <double>[northEast.longitude, northEast.latitude],
          <double>[southWest.longitude, northEast.latitude],
          <double>[southWest.longitude, southWest.latitude],
        ],
      ],
    },
  );
}

Future<ui.Image> _render({
  required FogGeometry geometry,
  required FogAtlas? atlas,
  List<FogDissolve> dissolves = const <FogDissolve>[],
  Duration elapsed = Duration.zero,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  FogPainter(
    projection: _projection,
    geometry: geometry,
    field: FogField(projection: _projection),
    camera: _camera,
    elapsed: elapsed,
    dissolves: dissolves,
    atlas: atlas,
    userSpeedMetresPerSecond: 0.0,
  ).paint(canvas, _size);

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    _size.width.toInt(),
    _size.height.toInt(),
  );
  picture.dispose();

  return image;
}

Future<ByteData> _readPixels(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!;
}

int _alphaAt(ByteData pixels, ui.Image image, int x, int y) {
  final offset = (y * image.width + x) * 4;
  return pixels.getUint8(offset + 3);
}

/// A tiny opaque atlas. Painter tests must not depend on the 2MB artwork — it
/// would make them slow and couple pixel assertions to art revisions.
Future<FogAtlas> _syntheticAtlas() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 128, 64),
    ui.Paint()..color = const Color(0xFFFFFFFF),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(128, 64);
  picture.dispose();

  return FogAtlas(
    image: image,
    sprites: const <Rect>[
      Rect.fromLTWH(0, 0, 64, 64),
      Rect.fromLTWH(64, 0, 64, 64),
    ],
  );
}
