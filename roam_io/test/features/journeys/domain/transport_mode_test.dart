import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';

void main() {
  test('new journey options are walk, drive, bus, train, and tram', () {
    expect(TransportMode.journeyOptions, [
      TransportMode.walk,
      TransportMode.drive,
      TransportMode.bus,
      TransportMode.train,
      TransportMode.tram,
    ]);
  });

  test('public transport modes retain the transit XP multiplier', () {
    expect(TransportMode.bus.xpMultiplier, 0.5);
    expect(TransportMode.train.xpMultiplier, 0.5);
    expect(TransportMode.tram.xpMultiplier, 0.5);
  });

  test('journey route colours correspond to transport mode', () {
    expect(TransportMode.walk.routeColor, const Color(0xFFD946EF));
      expect(TransportMode.drive.routeColor, const Color(0xFF5B21B6));
    expect(TransportMode.bus.routeColor, const Color(0xFFF97316));
    expect(TransportMode.train.routeColor, const Color(0xFF2563EB));
    expect(TransportMode.tram.routeColor, const Color(0xFF16A34A));
    expect(
      TransportMode.routeColorForWireValue('hoverboard'),
      const Color(0xFF5C734C),
    );
  });

  test('legacy journey modes still deserialize', () {
    expect(TransportMode.fromString('run'), TransportMode.run);
    expect(TransportMode.fromString('cycle'), TransportMode.cycle);
    expect(TransportMode.fromString('transit'), TransportMode.transit);
  });
}
