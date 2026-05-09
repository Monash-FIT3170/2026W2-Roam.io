/// App-level profile entity stored in Firestore at `profiles/{uid}`.
///
/// This model keeps profile data mapping consistent between:
/// - Dart objects in the app, and
/// - Firestore documents in the backend.
class ProfileModel {
  /// Placeholder XP threshold to determine level progression.
  static const int xpPerLevel = 100;

  /// Converts earned XP into a profile level.
  ///
  /// For now, every `xpPerLevel` XP increases the level by 1.
  static int levelFromXp(int xp) => (xp ~/ xpPerLevel) + 1;

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
