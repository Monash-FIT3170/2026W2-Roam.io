import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/party/party_tile_style.dart';

void main() {
  test('a tile with no owning team has no fill', () {
    expect(partyTileFillColor(null), const Color(0x00000000));
  });

  test('team A and team B tiles render distinct, visible fill colours', () {
    final teamAColor = partyTileFillColor('A');
    final teamBColor = partyTileFillColor('B');

    expect(teamAColor.a, greaterThan(0));
    expect(teamBColor.a, greaterThan(0));
    expect(teamAColor, isNot(equals(teamBColor)));
  });

  test('stroke colors and widths match team ownership', () {
    expect(partyTileStrokeColor(null), const Color(0x00000000));
    expect(partyTileStrokeColor('A'), const Color(0xFF0288D1));
    expect(partyTileStrokeColor('B'), const Color(0xFFE53935));

    expect(partyTileStrokeWidth(null), 0);
    expect(partyTileStrokeWidth('A'), 2);
    expect(partyTileStrokeWidth('B'), 2);
  });
}
