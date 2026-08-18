import 'dart:math' as math;

import '../../../theme/app_theme_mode.dart';

/*
 * Author: Alvin Liong
 * Last Modified: 4/05/2026
 * Description:
 *   Represents a user profile and maps profile data to and from Firestore.
 */

/// App-level profile entity stored in Firestore at `profiles/{uid}`.
class ProfileModel {
  /// Maximum level a user can reach.
  static const int maxLevel = 100;

  /// Base XP requirement for the first level-up.
  static const int baseXpPerLevel = 100;

  /// Returns the XP required to progress from [level] to [level + 1].
  static int xpForLevel(int level) {
    if (level <= 1) {
      return baseXpPerLevel;
    }

    return baseXpPerLevel * (2 * level - 1);
  }

  /// Returns the cumulative XP required to reach [level].
  ///
  /// Level 1 is the starting point and requires 0 total XP.
  static int totalXpToReachLevel(int level) {
    if (level <= 1) return 0;

    final effectiveLevel = math.min(level, maxLevel);
    final offset = effectiveLevel - 1;
    return baseXpPerLevel * offset * offset;
  }

  /// Converts earned XP into a profile level.
  static int levelFromXp(int xp) {
    if (xp < 0) return 1;

    var accumulatedXp = 0;
    for (var currentLevel = 1; currentLevel < maxLevel; currentLevel += 1) {
      final requiredXp = xpForLevel(currentLevel);
      if (xp < accumulatedXp + requiredXp) {
        return currentLevel;
      }
      accumulatedXp += requiredXp;
    }

    return maxLevel;
  }

  const ProfileModel({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.photoHash,
    required this.createdAt,
    required this.updatedAt,
    AppThemeMode themeMode = AppThemeMode.light,
    bool? darkModeEnabled,
    this.xp = 0,
    this.level = 1,
  }) : themeMode = darkModeEnabled == null
           ? themeMode
           : (darkModeEnabled ? AppThemeMode.dark : AppThemeMode.light);

  final String uid;
  final String username;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String? photoHash;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AppThemeMode themeMode;
  final int xp;
  final int level;

  /// Compatibility view for older callers while profiles migrate to the
  /// three-way [themeMode] preference.
  bool get darkModeEnabled => themeMode == AppThemeMode.dark;

  /// Creates a profile copy with selected fields replaced.
  ProfileModel copyWith({
    String? uid,
    String? username,
    String? displayName,
    String? email,
    String? photoUrl,
    String? photoHash,
    DateTime? createdAt,
    DateTime? updatedAt,
    AppThemeMode? themeMode,
    bool? darkModeEnabled,
    int? xp,
    int? level,
  }) {
    return ProfileModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      photoHash: photoHash ?? this.photoHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      themeMode: darkModeEnabled == null
          ? (themeMode ?? this.themeMode)
          : (darkModeEnabled ? AppThemeMode.dark : AppThemeMode.light),
      xp: xp ?? this.xp,
      level: level ?? this.level,
    );
  }

  /// Converts this profile to a Firestore-friendly map.
  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'uid': uid,
      'username': username,
      'displayName': displayName,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'themeMode': themeMode.storageValue,
      // Retained for compatibility with clients that predate Dynamic mode.
      'darkModeEnabled': darkModeEnabled,
      'xp': xp,
      'level': level,
    };
    if (photoUrl != null) {
      data['photoUrl'] = photoUrl;
    }
    if (photoHash != null) {
      data['photoHash'] = photoHash;
    }
    return data;
  }

  /// Creates a profile model from Firestore document data.
  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      uid: (map['uid'] ?? '') as String,
      username: (map['username'] ?? '') as String,
      displayName: (map['displayName'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      photoUrl: map['photoUrl'] as String?,
      photoHash: map['photoHash'] as String?,
      // Older or partial profile documents may not have valid timestamps.
      createdAt:
          DateTime.tryParse((map['createdAt'] ?? '') as String) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((map['updatedAt'] ?? '') as String) ??
          DateTime.now(),
      // Older profile documents only contain the boolean preference.
      themeMode: AppThemeMode.fromStorage(
        map['themeMode'],
        legacyDarkModeEnabled: map['darkModeEnabled'] == true,
      ),
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      level:
          (map['level'] as num?)?.toInt() ??
          levelFromXp((map['xp'] as num?)?.toInt() ?? 0),
    );
  }
}
