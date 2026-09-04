/*
 * Author: Amarprit Singh
 * Last Updated: 29 August 2026
 * Description:
 *   The fog a Journey preview draws, and the fog composited onto the picture
 *   stored with an activity. Both come from here, so a shared journey shows the
 *   same clouds as the map it was recorded on rather than a black sheet.
 */

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/map/fog/fog_atlas.dart';
import 'package:roam_io/features/map/fog/fog_projection.dart';
import 'package:roam_io/features/map/fog/static_fog.dart';

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

  group('StaticFog', () {
    test('clouds the frame and clears the explored region', () async {
      final fog = StaticFog(
        anchor: _anchor,
        clearedRegions: [_regionAroundAnchor()],
      );

      final image = await _render(fog, atlas);
      final pixels = await _readPixels(image);

      expect(
        _alphaAt(pixels, image, 150, 150),
        lessThan(10),
        reason: 'ground the traveller explored must be left showing',
      );
      expect(
        _alphaAt(pixels, image, 5, 5),
        greaterThan(200),
        reason: 'the rest of the frame must be under cloud',
      );

      image.dispose();
    });

    test('clouds everything for a journey that explored nothing', () async {
      final fog = StaticFog(anchor: _anchor, clearedRegions: const []);

      final image = await _render(fog, atlas);
      final pixels = await _readPixels(image);

      expect(_alphaAt(pixels, image, 150, 150), greaterThan(200));
      expect(fog.clearedRegionIds, isEmpty);

      image.dispose();
    });

    test('draws the same frame twice', () async {
      // The preview on screen and the picture captured from it are painted
      // separately, so an animated field would store clouds that no longer
      // match the card they came from.
      final fog = StaticFog(
        anchor: _anchor,
        clearedRegions: [_regionAroundAnchor()],
      );

      final first = await _render(fog, atlas);
      final second = await _render(fog, atlas);
      final firstPixels = await _readPixels(first);
      final secondPixels = await _readPixels(second);

      expect(
        firstPixels.buffer.asUint8List(),
        secondPixels.buffer.asUint8List(),
      );

      first.dispose();
      second.dispose();
    });

    test('reads the camera target back out of a settled viewport', () async {
      // Lite-mode maps never report a camera, so the fog derives one from the
      // region they say is visible. It has to land back on the centre.
      final fog = StaticFog(anchor: _anchor, clearedRegions: const []);
      final southwest = _projection.worldToLatLng(const Offset(-160, 90));
      final northeast = _projection.worldToLatLng(const Offset(160, -90));

      final centre = fog.centreOf(
        LatLngBounds(southwest: southwest, northeast: northeast),
      );

      expect(centre.latitude, closeTo(_anchor.latitude, 1e-9));
      expect(centre.longitude, closeTo(_anchor.longitude, 1e-9));
    });
  });
}

Future<ui.Image> _render(StaticFog fog, FogAtlas atlas) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  fog
      .painterFor(camera: _camera, atlas: atlas, isNight: false)
      .paint(canvas, _size);

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    _size.width.toInt(),
    _size.height.toInt(),
  );
  picture.dispose();

  return image;
}

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

Future<ByteData> _readPixels(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!;
}

int _alphaAt(ByteData pixels, ui.Image image, int x, int y) {
  final offset = (y * image.width + x) * 4;
  return pixels.getUint8(offset + 3);
}

/// A tiny opaque atlas, so these assertions do not depend on the artwork.
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
