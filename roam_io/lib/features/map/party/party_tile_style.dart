import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';

final Color _teamAFillColor = AppColors.teamA.withValues(alpha: 0.38);
final Color _teamBFillColor = AppColors.teamB.withValues(alpha: 0.38);

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
      return AppColors.teamA;
    case 'B':
      return AppColors.teamB;
    default:
      throw ArgumentError.value(owningTeam, 'owningTeam');
  }
}

/// Stroke width for a Party Mode tile border (2px when owned, 0 when unowned).
int partyTileStrokeWidth(String? owningTeam) {
  return owningTeam != null ? 2 : 0;
}
