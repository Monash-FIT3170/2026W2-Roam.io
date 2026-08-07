/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   View-model for public profile statistics shown by You and external
 *   profiles. Nullable counts distinguish real zero from still-loading or
 *   failed Firestore queries (rendered as an em dash).
 */

/// Public profile statistics shown beneath identity/progression.
class ProfileStats {
  const ProfileStats({
    required this.following,
    required this.followers,
    required this.tiles,
    required this.xpGained,
    required this.journeys,
    required this.sidequests,
  });

  /// Null means loading or query failure — not a real count of zero.
  final int? following;
  final int? followers;
  final int? tiles;
  final int xpGained;
  final int journeys;
  final int sidequests;

  List<ProfileStatItem> toItems() {
    return <ProfileStatItem>[
      ProfileStatItem(label: 'Following', value: _formatOptional(following)),
      ProfileStatItem(label: 'Followers', value: _formatOptional(followers)),
      ProfileStatItem(label: 'Tiles', value: _formatOptional(tiles)),
      ProfileStatItem(label: 'XP Gained', value: _formatNumber(xpGained)),
      ProfileStatItem(label: 'Journeys', value: _formatNumber(journeys)),
      ProfileStatItem(label: 'Sidequests', value: _formatNumber(sidequests)),
    ];
  }
}

/// Single formatted profile statistic for presentation.
class ProfileStatItem {
  const ProfileStatItem({required this.label, required this.value});

  final String label;
  final String value;
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
