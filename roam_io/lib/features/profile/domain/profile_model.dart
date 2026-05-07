/*
 * Author: Alvin Liong
 * Last Modified: 4/05/2026
 * Description:
 *   Represents a user profile and maps profile data to and from Firestore.
 */

/// App-level profile entity stored in Firestore at `profiles/{uid}`.
class ProfileModel {
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

  /// Creates a profile copy with selected fields replaced.
  ProfileModel copyWith({
    String? uid,
    String? username,
    String? displayName,
    String? email,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? darkModeEnabled,
  }) {
    return ProfileModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
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
      // Older profile documents predate this optional preference field.
      darkModeEnabled: (map['darkModeEnabled'] ?? false) as bool,
    );
  }
}
