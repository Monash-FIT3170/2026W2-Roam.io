/*
 * Description:
 *   Integrates the fog's ambient wind drift one frame at a time.
 *
 *   Deriving the offset from absolute elapsed time is the obvious alternative
 *   and is wrong in two ways. The term coupled to the user's own speed
 *   multiplies the whole elapsed time, so a new GPS fix would retroactively
 *   shift clouds that had already drifted — a jump that grows the longer the
 *   map stays open. And Ticker.start resets elapsed to zero, so coming back to
 *   the map tab would snap the field back to where it began.
 *
 *   Accumulating keeps every change local to the frame it happens on, which is
 *   also what lets the drift be held for the length of a journey and picked up
 *   again afterwards without the clouds jumping.
 */

import 'dart:ui';

import 'fog_palette.dart';

/// The fog's accumulated wind displacement, in reference-zoom world units.
class FogWind {
  Offset _offset = Offset.zero;
  Duration? _lastAdvance;

  /// Displacement applied to every sprite in the main cloud layer.
  Offset get offset => _offset;

  /// Advances the drift to [elapsed] on the overlay's ticker clock.
  ///
  /// [isHeld] pins the clouds where they are while still tracking the clock, so
  /// releasing the hold resumes from the current frame rather than integrating
  /// everything that was skipped. The first call after construction or
  /// [resetTiming] only establishes the baseline.
  void advance(
    Duration elapsed, {
    double userSpeedMetresPerSecond = 0.0,
    bool isHeld = false,
  }) {
    final previous = _lastAdvance;
    _lastAdvance = elapsed;
    if (previous == null || isHeld) return;

    final seconds =
        (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds <= 0) return;

    _offset += velocityAt(userSpeedMetresPerSecond) * seconds;
  }

  /// Drops the timing baseline without moving the clouds.
  ///
  /// Called whenever the ticker restarts: Ticker.start resets elapsed to zero,
  /// so the next delta would otherwise be the whole previous session, negated.
  void resetTiming() {
    _lastAdvance = null;
  }

  /// Wind velocity in world units per second at a given travel speed.
  ///
  /// The speed-coupled term runs downwind rather than in its own direction, so
  /// travelling quickens the existing wind instead of turning it.
  static Offset velocityAt(double userSpeedMetresPerSecond) {
    final base = FogPalette.windVelocity;
    final magnitude = base.distance;
    if (magnitude < 1e-6) return base;

    final boost =
        (userSpeedMetresPerSecond.abs() * FogPalette.windSpeedCoupling).clamp(
          0.0,
          FogPalette.windSpeedCeiling,
        );

    return base + (base / magnitude) * boost;
  }
}
