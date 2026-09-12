import 'package:flutter/material.dart';

const Color _teamAFillColor = Color(0x604FC3F7);
const Color _teamBFillColor = Color(0x60E57373);

/// Fill colour for a Party Mode tile, keyed by its owning team ('A'/'B'), or
/// no fill (transparent) when no team has crossed the claim gate.
Color partyTileFillColor(String? owningTeam) {
  switch (owningTeam) {
    case null:
      return const Color(0x00000000);
    case 'A':
      return _teamAFillColor;
    case 'B':
      return _teamBFillColor;
    default:
      throw ArgumentError.value(owningTeam, 'owningTeam');
  }
}

/// Stroke colour for a Party Mode tile border, or transparent when unowned.
Color partyTileStrokeColor(String? owningTeam) {
  switch (owningTeam) {
    case null:
      return const Color(0x00000000);
    case 'A':
      return const Color(0xFF0288D1);
    case 'B':
      return const Color(0xFFE53935);
    default:
      throw ArgumentError.value(owningTeam, 'owningTeam');
  }
}

/// Stroke width for a Party Mode tile border (2px when owned, 0 when unowned).
int partyTileStrokeWidth(String? owningTeam) {
  return owningTeam != null ? 2 : 0;
}
