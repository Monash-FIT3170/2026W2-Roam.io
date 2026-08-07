/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Represents the search-safe public profile fields used by Find People.
 */

/// Public profile fields exposed for people search.
class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    this.photoUrl,
    this.xp,
    this.level,
  });

  final String uid;
  final String username;
  final String displayName;
  final String? photoUrl;
  final int? xp;
  final int? level;

  factory PublicProfile.fromMap(Map<String, dynamic> map) {
    return PublicProfile(
      uid: (map['uid'] ?? '') as String,
      username: (map['username'] ?? '') as String,
      displayName: (map['displayName'] ?? '') as String,
      photoUrl: map['photoUrl'] as String?,
      xp: (map['xp'] as num?)?.toInt(),
      level: (map['level'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap({
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return <String, dynamic>{
      'uid': uid,
      'username': username,
      'usernameSearch': normalizeUsernameSearchText(username),
      'displayName': displayName,
      'displayNameSearch': normalizeSearchText(displayName),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
      if (xp != null) 'xp': xp,
      if (level != null) 'level': level,
    };
  }
}

/// Normalizes display names for case-insensitive prefix search.
String normalizeSearchText(String value) {
  return value.trim().toLowerCase();
}

/// Normalizes usernames for search without changing display storage.
String normalizeUsernameSearchText(String value) {
  final normalized = normalizeSearchText(value);
  if (normalized.startsWith('@')) {
    return normalized.substring(1);
  }
  return normalized;
}
