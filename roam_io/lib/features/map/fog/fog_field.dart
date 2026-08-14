/*
 * Description:
 *   Generates the scatter of cloud sprites for one frame as flat lists ready
 *   for Canvas.drawAtlas.
 *
 *   Sprites live on a grid in world space, so the field pans and rotates with
 *   the map for free. Each cell is hashed to derive its own rotation, scale,
 *   opacity, jitter and mirror flag, which is what stops the field reading as a
 *   repeated stamp. Hashing rather than storing means clouds are identical
 *   across frames and across app restarts while costing no memory.
 *
 *   Cell size snaps to a power of two chosen from the zoom, so on-screen
 *   density stays constant as the user pinches. Crossing a level cross-fades
 *   over a narrow band rather than popping, and outside that band only one
 *   level is generated.
 */

import 'dart:math' as math;
import 'dart:ui';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'fog_atlas.dart';
import 'fog_dissolve.dart';
import 'fog_palette.dart';
import 'fog_projection.dart';

/// Flat per-instance buffers for a single [Canvas.drawAtlas] call.
class FogFieldBatch {
  final List<RSTransform> transforms = <RSTransform>[];
  final List<Rect> rects = <Rect>[];
  final List<Color> colors = <Color>[];

  bool get isEmpty => transforms.isEmpty;

  int get length => transforms.length;

  void clear() {
    transforms.clear();
    rects.clear();
    colors.clear();
  }
}

/// Builds the cloud scatter for a camera, time and set of active dissolves.
class FogField {
  FogField({required this.projection});

  final FogProjection projection;

  /// Safety ceiling. Guards against a bad zoom producing an unbounded grid.
  static const int maxInstancesPerLayer = 512;

  /// Blend band for the level cross-fade. Outside it only one level generates.
  static const double _blendLow = 0.35;
  static const double _blendHigh = 0.65;

  final FogFieldBatch _batch = FogFieldBatch();

  /// Generates instances covering the viewport.
  ///
  /// [elapsed] drives wind drift and rotation. [parallax] generates the larger,
  /// slower, fainter secondary layer.
  FogFieldBatch build({
    required CameraPosition camera,
    required Size size,
    required FogAtlas atlas,
    required Duration elapsed,
    required List<FogDissolve> dissolves,
    double userSpeedMetresPerSecond = 0.0,
    bool parallax = false,
    Color spriteTint = FogPalette.spriteTint,
  }) {
    _batch.clear();
    if (atlas.isEmpty) return _batch;

    final mapScale = FogProjection.scaleForZoom(camera.zoom);
    final layerScale = parallax ? FogPalette.parallaxScaleFactor : 1.0;

    final spriteScreenSize =
        FogPalette.spriteScreenSize *
        layerScale *
        math.pow(mapScale, FogPalette.zoomScaleExponent).toDouble();
    final targetSpacing =
        spriteScreenSize / mapScale * FogPalette.gridSpacingFactor;

    // Level selection. Spacing halves as zoom rises, so the exact level is the
    // log2 of the desired spacing and the fractional part drives the blend.
    //
    // Note the direction of the dependency: sprite size is derived from the
    // level's cell size inside _generateLevel, not fixed here. Snapping cells
    // to a power of two while holding sprite size constant would let actual
    // spacing drift by up to 2x within a level, which is a 4x swing in on-
    // screen density — clouds visibly bunching and thinning during a pinch.
    // Tying the two together keeps coverage constant and turns the level change
    // into a scale change instead.
    final exactLevel = _log2(targetSpacing);
    final lowerLevel = exactLevel.floor();
    final fraction = exactLevel - lowerLevel;
    final upperWeight = _smoothstep(_blendLow, _blendHigh, fraction);
    final lowerWeight = 1.0 - upperWeight;

    final windOffset = _windOffset(elapsed, userSpeedMetresPerSecond, parallax);
    final worldBounds = projection.visibleWorldBounds(
      camera: camera,
      size: size,
    );

    if (lowerWeight > 0.01) {
      _generateLevel(
        level: lowerLevel,
        weight: lowerWeight,
        atlas: atlas,
        worldBounds: worldBounds,
        windOffset: windOffset,
        elapsed: elapsed,
        dissolves: dissolves,
        parallax: parallax,
        spriteTint: spriteTint,
      );
    }

    if (upperWeight > 0.01) {
      _generateLevel(
        level: lowerLevel + 1,
        weight: upperWeight,
        atlas: atlas,
        worldBounds: worldBounds,
        windOffset: windOffset,
        elapsed: elapsed,
        dissolves: dissolves,
        parallax: parallax,
        spriteTint: spriteTint,
      );
    }

    return _batch;
  }

  void _generateLevel({
    required int level,
    required double weight,
    required FogAtlas atlas,
    required Rect worldBounds,
    required Offset windOffset,
    required Duration elapsed,
    required List<FogDissolve> dissolves,
    required bool parallax,
    required Color spriteTint,
  }) {
    final cellSize = math.pow(2.0, level).toDouble();
    if (!cellSize.isFinite || cellSize <= 0) return;

    // Sprites overlap their cell by 1 / gridSpacingFactor, so coverage per cell
    // is identical at every level and rotated sprites never leave a gap.
    final spriteWorldSize = cellSize / FogPalette.gridSpacingFactor;

    // Sprites are placed after the wind offset, so enumerate the cells that
    // land on screen once shifted rather than the cells under it.
    final searchBounds = worldBounds
        .shift(-windOffset)
        .inflate(spriteWorldSize);

    final firstX = (searchBounds.left / cellSize).floor();
    final lastX = (searchBounds.right / cellSize).ceil();
    final firstY = (searchBounds.top / cellSize).floor();
    final lastY = (searchBounds.bottom / cellSize).ceil();

    final layerOpacity = parallax ? FogPalette.parallaxOpacityFactor : 1.0;

    for (var cellY = firstY; cellY <= lastY; cellY++) {
      for (var cellX = firstX; cellX <= lastX; cellX++) {
        if (_batch.length >= maxInstancesPerLayer) return;

        final random = _CellRandom.seeded(cellX, cellY, level, parallax);

        final jitterX = (random.next() - 0.5) * 2.0 * FogPalette.positionJitter;
        final jitterY = (random.next() - 0.5) * 2.0 * FogPalette.positionJitter;
        final quarterTurns = (random.next() * 4).floor();
        final scaleJitter =
            1.0 + (random.next() - 0.5) * 2.0 * FogPalette.scaleVariance;
        final opacityMix = random.next();
        final flipHorizontal = random.next() < 0.5;
        final flipVertical = random.next() < 0.5;

        // A coordinate colouring keeps direct neighbours on different artwork
        // while the independently hashed orientation/scale stops the pattern
        // itself from reading as a repeating strip. With the six production
        // sprites, horizontal neighbours advance by one variant and vertical
        // neighbours by two.
        final variant = atlas.variantCount <= 1
            ? 0
            : _positiveModulo(
                cellX + cellY * 2 + level * 3 + (parallax ? 1 : 0),
                atlas.variantCount,
              );

        // RSTransform cannot express reflection. The atlas contains a
        // horizontal mirror of every sprite; combining that with a half-turn
        // represents a vertical flip, while two flips reduce to a half-turn.
        final mirrored = flipHorizontal != flipVertical;
        final flipRotation = flipVertical ? math.pi : 0.0;
        final baseRotation = quarterTurns * math.pi / 2.0 + flipRotation;

        var position =
            Offset(
              (cellX + 0.5 + jitterX) * cellSize,
              (cellY + 0.5 + jitterY) * cellSize,
            ) +
            windOffset;

        var rotation = baseRotation;
        var scale = scaleJitter;
        var opacity =
            (FogPalette.opacityMin +
                opacityMix * (FogPalette.opacityMax - FogPalette.opacityMin)) *
            layerOpacity *
            weight;

        // Sprites over an unlocking region are shoved outward and thinned.
        for (final dissolve in dissolves) {
          if (!dissolve.affects(position)) continue;

          final progress = dissolve.progressAt(elapsed);
          final escape = dissolve.escapeOffset(position, progress);
          final spriteProgress = FogDissolve.easeOut(
            dissolve.spriteProgress(position, progress),
          );

          position += escape;
          rotation += FogPalette.dissolveSpin * spriteProgress;
          scale *= 1.0 + FogPalette.dissolveScaleGrowth * spriteProgress;
          opacity *= 1.0 - spriteProgress;
        }

        if (opacity <= 0.004) continue;

        final rect = atlas.rectFor(variant: variant, mirrored: mirrored);
        // RSTransform anchors in atlas coordinates, so the anchor is the rect's
        // absolute centre — not its half-size. Using half-size would misplace
        // every sprite whose rect does not start at the origin.
        final spriteScale = spriteWorldSize / rect.width * scale;

        _batch.transforms.add(
          RSTransform.fromComponents(
            rotation: rotation,
            scale: spriteScale,
            anchorX: rect.center.dx,
            anchorY: rect.center.dy,
            translateX: position.dx,
            translateY: position.dy,
          ),
        );
        _batch.rects.add(rect);
        _batch.colors.add(
          spriteTint.withValues(alpha: opacity.clamp(0.0, 1.0)),
        );
      }
    }
  }

  /// Wind displacement in world units for the elapsed time.
  static Offset _windOffset(
    Duration elapsed,
    double userSpeedMetresPerSecond,
    bool parallax,
  ) {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;

    final speedBoost =
        (userSpeedMetresPerSecond.abs() * FogPalette.windSpeedCoupling).clamp(
          0.0,
          FogPalette.windSpeedCeiling,
        );

    final base = FogPalette.windVelocity;
    final magnitude = base.distance;
    final direction = magnitude < 1e-6 ? Offset.zero : base / magnitude;

    final velocity = base + direction * speedBoost;
    final layerFactor = parallax ? FogPalette.parallaxSpeedFactor : 1.0;

    return velocity * seconds * layerFactor;
  }

  static double _log2(double value) {
    if (value <= 0 || !value.isFinite) return 0.0;
    return math.log(value) / math.ln2;
  }

  static double _smoothstep(double edge0, double edge1, double x) {
    if (edge1 <= edge0) return x >= edge1 ? 1.0 : 0.0;
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  static int _positiveModulo(int value, int modulus) {
    final remainder = value % modulus;
    return remainder < 0 ? remainder + modulus : remainder;
  }
}

/// Deterministic per-cell pseudo-random source.
///
/// Seeded from the cell coordinate and level so a cell always produces the same
/// cloud, every frame and across restarts, without storing anything.
class _CellRandom {
  _CellRandom(int seed) : _state = seed == 0 ? 0x9E3779B9 : seed;

  factory _CellRandom.seeded(int x, int y, int level, bool parallax) {
    var hash = 0x9E3779B9;
    hash = _mix(hash ^ (x & 0xFFFFFFFF), 0x85EBCA6B);
    hash = _mix(hash ^ (y & 0xFFFFFFFF), 0xC2B2AE35);
    hash = _mix(hash ^ (level & 0xFFFFFFFF), 0x27D4EB2F);
    if (parallax) hash = _mix(hash, 0x165667B1);
    return _CellRandom(hash);
  }

  int _state;

  /// Uniform value in [0, 1). Xorshift32 — fast, and quality is far beyond what
  /// scattering clouds needs.
  double next() {
    var state = _state;
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >>> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    _state = state & 0xFFFFFFFF;
    return _state / 0x100000000;
  }

  static int _mix(int value, int multiplier) {
    var hash = (value * multiplier) & 0xFFFFFFFF;
    hash ^= hash >>> 15;
    hash = (hash * 0x2545F491) & 0xFFFFFFFF;
    hash ^= hash >>> 13;
    return hash & 0xFFFFFFFF;
  }
}
