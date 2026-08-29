import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/fog/fog_atlas.dart';
import 'package:roam_io/features/map/fog/fog_dissolve.dart';
import 'package:roam_io/features/map/fog/fog_field.dart';
import 'package:roam_io/features/map/fog/fog_projection.dart';

const LatLng _anchor = LatLng(-37.8136, 144.9631);
const FogProjection _projection = FogProjection(anchor: _anchor);
const Size _size = Size(400, 800);
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

  group('FogField', () {
    test('covers the viewport with sprites', () {
      final batch = _build(atlas);

      expect(batch.isEmpty, isFalse);
      expect(batch.transforms, hasLength(batch.rects.length));
      expect(batch.transforms, hasLength(batch.colors.length));
    });

    test('is deterministic across builds', () {
      // Clouds must be identical frame to frame and across restarts. Anything
      // less and the field visibly reshuffles itself while standing still.
      final first = _snapshot(_build(atlas));
      final second = _snapshot(
        FogField(projection: _projection).build(
          camera: _camera,
          size: _size,
          atlas: atlas,
          elapsed: Duration.zero,
          dissolves: const <FogDissolve>[],
        ),
      );

      expect(first, equals(second));
    });

    test('uses only deterministic quarter-turn rotations', () {
      final batch = _build(atlas);

      for (final transform in batch.transforms) {
        final quarterTurns = _rotationOf(transform) / (math.pi / 2.0);
        expect(quarterTurns, closeTo(quarterTurns.roundToDouble(), 1e-10));
      }

      expect(
        batch.transforms.map((transform) {
          final turns = (_rotationOf(transform) / (math.pi / 2.0)).round();
          return (turns % 4 + 4) % 4;
        }).toSet(),
        hasLength(4),
      );
    });

    test('leaves no gaps in the viewport at any zoom', () {
      // The property that actually matters: no hole in the cloud field through
      // which unexplored map shows at full brightness. Measured by sampling
      // points rather than summing sprite area, because sprite size relative to
      // the viewport changes by an order of magnitude across this zoom range —
      // an area sum is dominated by the off-screen padding ring at high zoom
      // and by a handful of samples at low.
      for (final zoom in <double>[14.5, 15.2, 16.0, 17.5, 19.0]) {
        final batch = FogField(projection: _projection).build(
          camera: CameraPosition(target: _anchor, zoom: zoom),
          size: _size,
          atlas: atlas,
          elapsed: Duration.zero,
          dissolves: const <FogDissolve>[],
        );

        expect(
          _uncoveredFraction(batch, zoom),
          0.0,
          reason: 'fog gapped at zoom $zoom',
        );
      }
    });

    test('keeps enough sprites on screen for the field to look varied', () {
      // One or two enormous puffs would defeat the per-cell rotation entirely.
      for (final zoom in <double>[14.5, 16.0, 17.5, 19.0]) {
        final batch = FogField(projection: _projection).build(
          camera: CameraPosition(target: _anchor, zoom: zoom),
          size: _size,
          atlas: atlas,
          elapsed: Duration.zero,
          dissolves: const <FogDissolve>[],
        );

        expect(
          _visibleCount(batch, zoom),
          greaterThanOrEqualTo(6),
          reason: 'too few visible sprites at zoom $zoom',
        );
      }
    });

    test('never exceeds the instance ceiling', () {
      final batch = FogField(projection: _projection).build(
        camera: const CameraPosition(target: _anchor, zoom: 21.0),
        size: const Size(2000, 2000),
        atlas: atlas,
        elapsed: Duration.zero,
        dissolves: const <FogDissolve>[],
      );

      expect(batch.length, lessThanOrEqualTo(FogField.maxInstancesPerLayer));
    });

    test('drifts downwind as time passes', () {
      final atRest = _build(atlas, elapsed: Duration.zero);
      final later = _build(atlas, elapsed: const Duration(seconds: 30));

      expect(_snapshot(atRest), isNot(equals(_snapshot(later))));
    });

    test('parallax layer is larger and fainter than the main layer', () {
      // Compared on batch means, not on .first: the two layers hash to
      // different instances, so index 0 is not a like-for-like sprite.
      final main = _build(atlas, elapsed: const Duration(seconds: 10));
      final parallax = _build(
        atlas,
        elapsed: const Duration(seconds: 10),
        parallax: true,
      );

      expect(_meanScale(parallax), greaterThan(_meanScale(main)));
      expect(_meanOpacity(parallax), lessThan(_meanOpacity(main)));
    });

    group('dissipation', () {
      test('thins sprites over the unlocking region as it progresses', () {
        final dissolve = _dissolveOverViewport();

        final start = _build(atlas, dissolves: <FogDissolve>[dissolve]);
        final midway = _build(
          atlas,
          elapsed: const Duration(milliseconds: 900),
          dissolves: <FogDissolve>[dissolve],
        );

        expect(_totalOpacity(midway), lessThan(_totalOpacity(start)));
      });

      test('clears the region entirely by the end', () {
        final dissolve = _dissolveOverViewport();

        final finished = _build(
          atlas,
          elapsed: const Duration(milliseconds: 1400),
          dissolves: <FogDissolve>[dissolve],
        );

        expect(_totalOpacity(finished), closeTo(0.0, 0.05));
      });

      test('leaves sprites outside the region untouched', () {
        final elsewhere = FogDissolve(
          regionId: 'far',
          worldCentre: const Offset(500000, 500000),
          regionBounds: const Rect.fromLTWH(499000, 499000, 2000, 2000),
          wind: const Offset(9, -3.5),
          startedAt: Duration.zero,
        );

        final without = _build(atlas, elapsed: const Duration(seconds: 1));
        final with_ = _build(
          atlas,
          elapsed: const Duration(seconds: 1),
          dissolves: <FogDissolve>[elsewhere],
        );

        expect(_snapshot(with_), equals(_snapshot(without)));
      });
    });
  });
}

FogFieldBatch _build(
  FogAtlas atlas, {
  Duration elapsed = Duration.zero,
  List<FogDissolve> dissolves = const <FogDissolve>[],
  bool parallax = false,
}) {
  return FogField(projection: _projection).build(
    camera: _camera,
    size: _size,
    atlas: atlas,
    elapsed: elapsed,
    dissolves: dissolves,
    parallax: parallax,
  );
}

/// A dissolve whose bounds swallow the whole test viewport.
FogDissolve _dissolveOverViewport() {
  return FogDissolve(
    regionId: 'region',
    worldCentre: Offset.zero,
    regionBounds: const Rect.fromLTWH(-600, -900, 1200, 1800),
    wind: const Offset(9, -3.5),
    startedAt: Duration.zero,
  );
}

double _totalOpacity(FogFieldBatch batch) {
  return batch.colors.fold<double>(0.0, (sum, color) => sum + color.a);
}

double _meanOpacity(FogFieldBatch batch) {
  if (batch.isEmpty) return 0.0;
  return _totalOpacity(batch) / batch.length;
}

double _meanScale(FogFieldBatch batch) {
  if (batch.isEmpty) return 0.0;
  final total = List<int>.generate(batch.length, (i) => i).fold<double>(
    0.0,
    (sum, i) => sum + _scaleOf(batch.transforms[i]) * batch.rects[i].width,
  );
  return total / batch.length;
}

Rect _viewportFor(double zoom) {
  final mapScale = FogProjection.scaleForZoom(zoom);
  return Rect.fromCenter(
    center: Offset.zero,
    width: _size.width / mapScale,
    height: _size.height / mapScale,
  );
}

int _visibleCount(FogFieldBatch batch, double zoom) {
  final viewport = _viewportFor(zoom);
  var count = 0;

  for (var i = 0; i < batch.length; i++) {
    if (viewport.contains(_centreOf(batch.transforms[i], batch.rects[i]))) {
      count++;
    }
  }

  return count;
}

/// Fraction of the viewport not reached by any sprite.
///
/// Each sprite is treated as the circle inscribed in its square, which is
/// pessimistic — the real artwork fills its corners too — so passing this means
/// the field genuinely has no gaps.
double _uncoveredFraction(FogFieldBatch batch, double zoom) {
  const samplesPerAxis = 24;
  final viewport = _viewportFor(zoom);

  final centres = <Offset>[];
  final radii = <double>[];
  for (var i = 0; i < batch.length; i++) {
    if (batch.colors[i].a < 0.05) continue;
    centres.add(_centreOf(batch.transforms[i], batch.rects[i]));
    radii.add(_scaleOf(batch.transforms[i]) * batch.rects[i].width / 2.0);
  }

  var uncovered = 0;

  for (var y = 0; y < samplesPerAxis; y++) {
    for (var x = 0; x < samplesPerAxis; x++) {
      final point = Offset(
        viewport.left + viewport.width * (x + 0.5) / samplesPerAxis,
        viewport.top + viewport.height * (y + 0.5) / samplesPerAxis,
      );

      var covered = false;
      for (var i = 0; i < centres.length; i++) {
        if ((point - centres[i]).distance <= radii[i]) {
          covered = true;
          break;
        }
      }

      if (!covered) uncovered++;
    }
  }

  return uncovered / (samplesPerAxis * samplesPerAxis);
}

/// Recovers a sprite's world-space centre from its RSTransform.
///
/// RSTransform stores tx/ty pre-multiplied by the anchor, so the centre has to
/// be transformed back out rather than read off directly.
Offset _centreOf(RSTransform transform, Rect rect) {
  final anchor = rect.center;
  return Offset(
    transform.scos * anchor.dx - transform.ssin * anchor.dy + transform.tx,
    transform.ssin * anchor.dx + transform.scos * anchor.dy + transform.ty,
  );
}

List<String> _snapshot(FogFieldBatch batch) {
  return <String>[
    for (var i = 0; i < batch.length; i++)
      '${batch.transforms[i].scos.toStringAsFixed(5)},'
          '${batch.transforms[i].ssin.toStringAsFixed(5)},'
          '${batch.transforms[i].tx.toStringAsFixed(5)},'
          '${batch.transforms[i].ty.toStringAsFixed(5)},'
          '${batch.colors[i].a.toStringAsFixed(5)},'
          '${batch.rects[i]}',
  ];
}

/// RSTransform stores scale*cos and scale*sin, so the angle comes back out
/// with atan2 and the scale with the magnitude.
double _rotationOf(RSTransform transform) {
  return math.atan2(transform.ssin, transform.scos);
}

double _scaleOf(RSTransform transform) {
  return math.sqrt(
    transform.scos * transform.scos + transform.ssin * transform.ssin,
  );
}

/// A tiny opaque atlas. Goldens and field tests must not depend on the 2MB
/// artwork — it would make them slow and couple them to art revisions.
Future<FogAtlas> _syntheticAtlas() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  canvas.drawRect(
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
