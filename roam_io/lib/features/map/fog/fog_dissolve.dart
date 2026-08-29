/*
 * Description:
 *   Tracks regions that are mid-dissipation.
 *
 *   When a region unlocks, its fog does not simply stop being drawn. For about
 *   1.4 seconds the sprites over it are given an escape velocity away from the
 *   user and biased downwind, while the hole feathers in behind them, so the
 *   map is revealed as the clouds physically leave rather than before or after.
 */

import 'dart:ui';

import 'fog_palette.dart';

/// One region in the middle of blowing away.
class FogDissolve {
  FogDissolve({
    required this.regionId,
    required this.worldCentre,
    required this.regionBounds,
    required this.wind,
    required this.startedAt,
    this.duration = FogPalette.dissolveDuration,
  });

  /// SA1 id of the unlocking region.
  final String regionId;

  /// Tear origin in world space — the user's position, not the region centroid,
  /// so clouds part from where the user actually is.
  final Offset worldCentre;

  /// World-space bounds of the unlocking region, used to decide which sprites
  /// are caught in the burst.
  final Rect regionBounds;

  /// Approximate region radius in world units, used to scale escape distance.
  double get worldRadius =>
      (regionBounds.longestSide / 2.0).clamp(1.0, double.infinity);

  /// Whether a sprite at [worldPosition] is caught in this burst.
  ///
  /// Padded past the region bounds so sprites straddling the boundary leave
  /// with the rest rather than sitting on the newly cleared edge.
  bool affects(Offset worldPosition) {
    return regionBounds.inflate(worldRadius * 0.5).contains(worldPosition);
  }

  /// Wind direction at the moment of unlock, so the burst matches the resting
  /// drift instead of reading as a separate effect.
  final Offset wind;

  final Duration startedAt;
  final Duration duration;

  /// Linear progress in [0, 1].
  double progressAt(Duration now) {
    final elapsed = (now - startedAt).inMicroseconds;
    final total = duration.inMicroseconds;
    if (total <= 0) return 1.0;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  bool isCompleteAt(Duration now) => progressAt(now) >= 1.0;

  /// Eased progress for sprite motion.
  ///
  /// Fast out, slow in: clouds are shoved and then coast, which reads as being
  /// caught by a gust rather than animated on a curve.
  static double easeOut(double t) {
    final inverted = 1.0 - t.clamp(0.0, 1.0);
    return 1.0 - inverted * inverted * inverted;
  }

  /// How far through its escape a sprite at [worldPosition] is.
  ///
  /// Sprites nearest the user leave first, so the tear opens outward from the
  /// blue dot instead of the whole region fading at once.
  double spriteProgress(Offset worldPosition, double t) {
    if (worldRadius <= 0) return t;

    final distance = (worldPosition - worldCentre).distance;
    final normalised = (distance / worldRadius).clamp(0.0, 1.0);

    // Stagger start times across the radius, then compress so the last sprite
    // still finishes by t == 1.
    const stagger = 0.35;
    final start = normalised * stagger;
    final span = 1.0 - stagger;

    return ((t - start) / span).clamp(0.0, 1.0);
  }

  /// Displacement applied to a sprite at [worldPosition] for progress [t].
  Offset escapeOffset(Offset worldPosition, double t) {
    final progress = easeOut(spriteProgress(worldPosition, t));
    if (progress <= 0) return Offset.zero;

    final delta = worldPosition - worldCentre;
    final direction = delta.distance < 1e-6
        ? const Offset(1.0, 0.0)
        : delta / delta.distance;

    final windDirection = wind.distance < 1e-6
        ? Offset.zero
        : wind / wind.distance;

    final heading = direction + windDirection * FogPalette.dissolveWindBias;
    final normalisedHeading = heading.distance < 1e-6
        ? direction
        : heading / heading.distance;

    return normalisedHeading *
        (worldRadius * FogPalette.dissolveEscapeDistance * progress);
  }

  /// Opacity multiplier for a sprite at [worldPosition].
  double spriteOpacity(Offset worldPosition, double t) {
    return 1.0 - easeOut(spriteProgress(worldPosition, t));
  }
}

/// Owns the set of in-flight dissolves.
class FogDissolveSet {
  final List<FogDissolve> _active = <FogDissolve>[];

  List<FogDissolve> get active => List.unmodifiable(_active);

  bool get isEmpty => _active.isEmpty;

  bool get isNotEmpty => _active.isNotEmpty;

  bool contains(String regionId) {
    return _active.any((dissolve) => dissolve.regionId == regionId);
  }

  /// Starts a dissolve, replacing any existing one for the same region so a
  /// repeated unlock cannot stack two bursts.
  void start(FogDissolve dissolve) {
    _active.removeWhere((existing) => existing.regionId == dissolve.regionId);
    _active.add(dissolve);
  }

  /// Removes finished dissolves and reports their region ids so the caller can
  /// promote them to permanent holes.
  List<String> pruneCompleted(Duration now) {
    final completed = <String>[];

    _active.removeWhere((dissolve) {
      if (dissolve.isCompleteAt(now)) {
        completed.add(dissolve.regionId);
        return true;
      }
      return false;
    });

    return completed;
  }

  void clear() => _active.clear();
}
