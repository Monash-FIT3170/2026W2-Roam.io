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
  });

  final String uid;
  final String username;
  final String displayName;
  final String email;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Converts this profile to a Firestore-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'username': username,
      'displayName': displayName,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Creates a profile model from Firestore document data.
  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      uid: (map['uid'] ?? '') as String,
      username: (map['username'] ?? '') as String,
      displayName: (map['displayName'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      createdAt: DateTime.tryParse((map['createdAt'] ?? '') as String) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((map['updatedAt'] ?? '') as String) ?? DateTime.now(),
    );
  }
}
