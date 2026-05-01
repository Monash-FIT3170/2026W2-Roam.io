import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/profile/domain/profile_model.dart';

/// Thin wrapper for Firestore profile operations.
///
/// This service owns reads/writes to the `profiles` collection so higher layers
/// do not depend on Firestore APIs directly.
class ProfileService {
  ProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection('profiles');

  /// Creates/replaces profile document at `profiles/{uid}`.
  Future<void> createProfile(ProfileModel profile) {
    return _profiles.doc(profile.uid).set(profile.toMap());
  }

  /// Updates editable profile fields and refreshes `updatedAt`.
  Future<void> updateProfile({
    required String uid,
    required String username,
    required String displayName,
  }) {
    return _profiles.doc(uid).update(
      <String, dynamic>{
        'username': username,
        'displayName': displayName,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Reads a profile by uid. Returns null when not found.
  Future<ProfileModel?> getProfile(String uid) async {
    final doc = await _profiles.doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return ProfileModel.fromMap(data);
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .update({'displayName': displayName});
  }

}

