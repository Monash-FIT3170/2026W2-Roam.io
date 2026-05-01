/// App-level profile entity stored in Firestore at `profiles/{uid}`.
///
/// This model keeps profile data mapping consistent between:
/// - Dart objects in the app, and
/// - Firestore documents in the backend.
class ProfileModel {
  const ProfileModel({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
    this.darkModeEnabled = false,
  });

  final String uid;
  final String username;
  final String displayName;
  final String email;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool darkModeEnabled;

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
    return <String, dynamic>{
      'uid': uid,
      'username': username,
      'displayName': displayName,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'darkModeEnabled': darkModeEnabled,
    };
  }

  /// Creates a profile model from Firestore document data.
  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      uid: (map['uid'] ?? '') as String,
      username: (map['username'] ?? '') as String,
      displayName: (map['displayName'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      createdAt:
          DateTime.tryParse((map['createdAt'] ?? '') as String) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((map['updatedAt'] ?? '') as String) ??
          DateTime.now(),
      darkModeEnabled: (map['darkModeEnabled'] ?? false) as bool,
    );
  }
}
