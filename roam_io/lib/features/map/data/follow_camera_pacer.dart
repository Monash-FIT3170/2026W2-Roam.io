/*
 * Description:
 *   Paces the camera that follows the user's location.
 *
 *   Two location sources drive it and neither is smooth on its own. The map's
 *   own stream reports a fix once the user has covered the GPS distance filter,
 *   seconds apart at walking pace, and journey tracking republishes its latest
 *   route point on every notification — once a second while its elapsed timer
 *   runs, whether or not the point has changed.
 *
 *   Animating on each of those is what makes a followed map stutter: an
 *   animation restarted at the same target eases from a standstill, and one
 *   given the default length covers the ground in a few hundred milliseconds
 *   and then sits still for the rest of the gap. This decides which fixes are
 *   worth moving for and stretches each move across the gap it expects until
 *   the next one, so the camera is still arriving as that fix lands.
 */

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Decides whether the follow camera moves for a fix, and for how long.
class FollowCameraPacer {
  /// Minimum movement, in metres, worth re-animating for.
  ///
  /// Below the GPS distance filter, so a genuine move always passes and a fix
  /// republished by a second source does not.
  static const double movementThresholdMetres = 2.0;

  /// Floor on the animation, so closely spaced fixes — a drive — do not crawl.
  static const Duration minAnimation = Duration(milliseconds: 450);

  /// Ceiling on the animation, so the camera does not trail far behind the user
  /// on the first fix after a long stationary gap.
  ///
  /// Set above the cadence of a walk — a 5m distance filter at walking pace is
  /// a fix every three seconds or so — because that is the case the pacing
  /// exists for. Anything shorter leaves the camera finished and waiting for
  /// most of the gap, which is the stutter this is here to remove. What it
  /// costs is bounded by how far the user travels inside the window: at the
  /// zoom the map follows at, five metres is a few pixels.
  static const Duration maxAnimation = Duration(seconds: 3);

  LatLng? _target;
  DateTime? _movedAt;

  /// The target of the last move this paced, if it still holds.
  LatLng? get target => _target;

  /// How long the camera should take to reach [location], or null when the fix
  /// is not worth moving for.
  ///
  /// The gap since the last move is the only estimate available of the gap
  /// until the next, and it tracks travel speed for free: fixes arrive once the
  /// user has covered the distance filter, so walking spaces them out and
  /// driving packs them together.
  Duration? durationFor(LatLng location, {DateTime? now}) {
    final previous = _target;
    if (previous != null &&
        _metresBetween(previous, location) < movementThresholdMetres) {
      return null;
    }

    final movedAt = now ?? DateTime.now();
    final sinceLastMove = _movedAt == null
        ? null
        : movedAt.difference(_movedAt!);

    _target = location;
    _movedAt = movedAt;

    if (sinceLastMove == null) return minAnimation;

    return Duration(
      microseconds: sinceLastMove.inMicroseconds.clamp(
        minAnimation.inMicroseconds,
        maxAnimation.inMicroseconds,
      ),
    );
  }

  /// Forgets the pacing, so the next fix moves the camera and is animated from
  /// scratch rather than against a gap measured before the interruption.
  ///
  /// Used when something else takes the camera — the user panning away, or a
  /// recentre — after which the last target says nothing about where the camera
  /// actually is.
  void reset() {
    _target = null;
    _movedAt = null;
  }

  static double _metresBetween(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }
}
