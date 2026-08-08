/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   View-model for public profile statistics shown by You and external
 *   profiles. Following/Followers always render a numeric count (empty = 0);
 *   they never use an em dash. Other nullable stats still distinguish loading
 *   or query failure with an em dash. Following/Followers may carry optional
 *   tap callbacks for connection lists.
 */

import 'package:flutter/foundation.dart';

/// Public profile statistics shown beneath identity/progression.
class ProfileStats {
  const ProfileStats({
    required this.following,
    required this.followers,
    required this.tiles,
    required this.xpGained,
    required this.journeys,
    required this.sidequests,
    this.onFollowingTap,
    this.onFollowersTap,
  });

  /// Following count. Null is displayed as 0 (never an em dash).
  final int? following;

  /// Followers count. Null is displayed as 0 (never an em dash).
  final int? followers;

  /// Null means loading or query failure — not a real count of zero.
  final int? tiles;
  final int xpGained;
  final int journeys;
  final int sidequests;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onFollowersTap;

  List<ProfileStatItem> toItems() {
    return <ProfileStatItem>[
      ProfileStatItem(
        label: 'Following',
        value: _formatNumber(following ?? 0),
        onTap: onFollowingTap,
      ),
      ProfileStatItem(
        label: 'Followers',
        value: _formatNumber(followers ?? 0),
        onTap: onFollowersTap,
      ),
      ProfileStatItem(label: 'Tiles', value: _formatOptional(tiles)),
      ProfileStatItem(label: 'XP Gained', value: _formatNumber(xpGained)),
      ProfileStatItem(label: 'Journeys', value: _formatNumber(journeys)),
      ProfileStatItem(label: 'Sidequests', value: _formatNumber(sidequests)),
    ];
  }
}

/// Single formatted profile statistic for presentation.
class ProfileStatItem {
  const ProfileStatItem({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
}

String _formatOptional(int? value) {
  if (value == null) return '—';
  return _formatNumber(value);
}

String _formatNumber(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index += 1) {
    final fromEnd = raw.length - index;
    buffer.write(raw[index]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
