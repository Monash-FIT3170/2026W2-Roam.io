import 'dart:math' as math;

/// App-level profile entity stored in Firestore at `profiles/{uid}`.
///
/// This model keeps profile data mapping consistent between:
/// - Dart objects in the app, and
/// - Firestore documents in the backend.
class ProfileModel {
  /// Maximum level a user can reach.
  static const int maxLevel = 100;

  /// Base XP requirement for the first level-up.
  static const int baseXpPerLevel = 100;

  /// Growth rate used to scale XP requirements for each subsequent level.
  static const double xpGrowthRate = 1.12;

  /// Returns the XP required to progress from [level] to [level + 1].
  static int xpForLevel(int level) {
    if (level <= 1) {
      return baseXpPerLevel;
    }

    return math.max(
      baseXpPerLevel,
      (baseXpPerLevel * math.pow(xpGrowthRate, level - 1)).round(),
    );
  }

  /// Returns the cumulative XP required to reach [level].
  ///
  /// Level 1 is the starting point and requires 0 total XP.
  static int totalXpToReachLevel(int level) {
    if (level <= 1) return 0;

    var total = 0;
    for (var currentLevel = 1;
        currentLevel < math.min(level, maxLevel);
        currentLevel += 1) {
      total += xpForLevel(currentLevel);
    }

    return total;
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
    this.darkModeEnabled = false,
    this.xp = 0,
    this.level = 1,
  });

  final String uid;
  final String username;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String? photoHash;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool darkModeEnabled;
  final int xp;
  final int level;

  ProfileModel copyWith({
    String? uid,
    String? username,
    String? displayName,
    String? email,
    String? photoUrl,
    String? photoHash,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
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
      createdAt:
          DateTime.tryParse((map['createdAt'] ?? '') as String) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((map['updatedAt'] ?? '') as String) ??
          DateTime.now(),
      darkModeEnabled: (map['darkModeEnabled'] ?? false) as bool,
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      level: (map['level'] as num?)?.toInt() ??
          levelFromXp((map['xp'] as num?)?.toInt() ?? 0),
    );
  }
}
