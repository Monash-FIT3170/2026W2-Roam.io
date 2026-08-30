import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/fog/fog_palette.dart';
import 'package:roam_io/features/map/fog/fog_wind.dart';

void main() {
  group('FogWind', () {
    test('the first advance only establishes the baseline', () {
      final wind = FogWind()..advance(const Duration(seconds: 10));

      expect(wind.offset, Offset.zero);
    });

    test('accumulates downwind as frames pass', () {
      final wind = FogWind()
        ..advance(Duration.zero)
        ..advance(const Duration(seconds: 2));

      expect(wind.offset, FogPalette.windVelocity * 2.0);
    });

    test('a hold pins the clouds and releasing resumes from there', () {
      // Deriving the offset from absolute elapsed time instead would jump the
      // field forward by everything the hold skipped the moment it lifted.
      final wind = FogWind()
        ..advance(Duration.zero)
        ..advance(const Duration(seconds: 1));

      final held = wind.offset;

      wind
        ..advance(const Duration(seconds: 30), isHeld: true)
        ..advance(const Duration(seconds: 60), isHeld: true);
      expect(wind.offset, held);

      wind.advance(const Duration(seconds: 61));
      expect(wind.offset, held + FogPalette.windVelocity);
    });

    test('travelling quickens the wind without turning it', () {
      final resting = FogWind()
        ..advance(Duration.zero)
        ..advance(const Duration(seconds: 1));
      final travelling = FogWind()
        ..advance(Duration.zero)
        ..advance(const Duration(seconds: 1), userSpeedMetresPerSecond: 5.0);

      expect(travelling.offset.distance, greaterThan(resting.offset.distance));
      expect(
        travelling.offset.direction,
        closeTo(resting.offset.direction, 1e-9),
      );
    });

    test('a drive does not turn the fog into a blur', () {
      final velocity = FogWind.velocityAt(30.0);

      expect(
        velocity.distance,
        closeTo(
          FogPalette.windVelocity.distance + FogPalette.windSpeedCeiling,
          1e-9,
        ),
      );
    });

    test('a ticker restart resets the timing without moving the clouds', () {
      // Ticker.start resets elapsed to zero, so the next delta would otherwise
      // be the whole previous session, negated.
      final wind = FogWind()
        ..advance(Duration.zero)
        ..advance(const Duration(seconds: 30));

      final beforeRestart = wind.offset;

      wind
        ..resetTiming()
        ..advance(Duration.zero);
      expect(wind.offset, beforeRestart);

      wind.advance(const Duration(seconds: 1));
      expect(wind.offset, beforeRestart + FogPalette.windVelocity);
    });
  });
}
