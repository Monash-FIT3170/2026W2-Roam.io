import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/follow_camera_pacer.dart';

const LatLng _start = LatLng(-37.8136, 144.9631);
final DateTime _t0 = DateTime(2026, 8, 30, 9);

void main() {
  group('FollowCameraPacer', () {
    test('the first fix moves the camera at the shortest animation', () {
      final pacer = FollowCameraPacer();

      expect(
        pacer.durationFor(_start, now: _t0),
        FollowCameraPacer.minAnimation,
        reason: 'nothing has been observed yet to pace against',
      );
    });

    test('a republished fix is not worth re-animating for', () {
      // Journey tracking republishes its latest route point once a second while
      // its elapsed timer runs. Re-animating restarts the easing from a
      // standstill, which is what the followed map used to stutter on.
      final pacer = FollowCameraPacer()..durationFor(_start, now: _t0);

      expect(pacer.durationFor(_start, now: _t0.add(_seconds(1))), isNull);
      expect(
        pacer.durationFor(
          _metresNorthOf(_start, 1.0),
          now: _t0.add(_seconds(2)),
        ),
        isNull,
        reason: 'a metre is GPS noise, not travel',
      );
    });

    test('animates across the gap it expects until the next fix', () {
      final pacer = FollowCameraPacer()..durationFor(_start, now: _t0);

      pacer.durationFor(_metresNorthOf(_start, 10), now: _t0.add(_seconds(2)));

      expect(
        pacer.durationFor(
          _metresNorthOf(_start, 20),
          now: _t0.add(_seconds(4)),
        ),
        _seconds(2),
      );
    });

    test('closely spaced fixes do not crawl', () {
      // Driving packs fixes together; the animation must not outlast the gap it
      // is covering or the camera falls further behind with every one.
      final pacer = FollowCameraPacer()..durationFor(_start, now: _t0);

      pacer.durationFor(_metresNorthOf(_start, 10), now: _t0.add(_seconds(1)));

      expect(
        pacer.durationFor(
          _metresNorthOf(_start, 20),
          now: _t0.add(const Duration(milliseconds: 1100)),
        ),
        FollowCameraPacer.minAnimation,
      );
    });

    test('a long stationary gap does not leave the camera trailing', () {
      final pacer = FollowCameraPacer()..durationFor(_start, now: _t0);

      expect(
        pacer.durationFor(
          _metresNorthOf(_start, 10),
          now: _t0.add(const Duration(minutes: 5)),
        ),
        FollowCameraPacer.maxAnimation,
      );
    });

    test('a reset moves for the next fix wherever it lands', () {
      // The user panning away or recentring takes the camera somewhere the last
      // target says nothing about, so holding onto it would skip the move that
      // brings the camera back.
      final pacer = FollowCameraPacer()..durationFor(_start, now: _t0);

      pacer.reset();

      expect(pacer.durationFor(_start, now: _t0.add(_seconds(3))), isNotNull);
      expect(pacer.target, _start);
    });
  });
}

Duration _seconds(int value) => Duration(seconds: value);

/// A point [metres] north of [origin]. One degree of latitude is close enough
/// to 111,320m for a threshold measured in single metres.
LatLng _metresNorthOf(LatLng origin, double metres) {
  return LatLng(origin.latitude + metres / 111320.0, origin.longitude);
}
