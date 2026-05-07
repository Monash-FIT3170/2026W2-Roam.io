/*
 * Author: Alvin Liong
 * Last Modified: 4/05/2026
 * Description:
 *   Provides Firestore profile document operations for account details,
 *   preferences, and profile photo metadata.
 */

import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/profile/domain/profile_model.dart';

/// Owns reads and writes for Firestore documents in the `profiles` collection.
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
    String? photoUrl,
  }) {
    final data = <String, dynamic>{
      'username': username,
      'displayName': displayName,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (photoUrl != null) {
      data['photoUrl'] = photoUrl;
    }
    return _profiles.doc(uid).update(data);
  }

  /// Updates the user's saved dark mode preference.
  Future<void> updateDarkModePreference({
    required String uid,
    required bool enabled,
  }) {
    return _profiles.doc(uid).update(<String, dynamic>{
      'darkModeEnabled': enabled,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Stores the user's profile photo URL and content hash.
  Future<void> updateProfilePhoto({
    required String uid,
    required String photoUrl,
    required String photoHash,
  }) {
    return _profiles.doc(uid).update(<String, dynamic>{
      'photoUrl': photoUrl,
      'photoHash': photoHash,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Stores a content hash for an existing profile photo.
  Future<void> updateProfilePhotoHash({
    required String uid,
    required String photoHash,
  }) {
    return _profiles.doc(uid).update(<String, dynamic>{
      'photoHash': photoHash,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Reads a profile by uid. Returns null when not found.
  Future<ProfileModel?> getProfile(String uid) async {
    final doc = await _profiles.doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return ProfileModel.fromMap(data);
  }

  /// Updates the display name shown in profile surfaces.
  Future<void> updateDisplayName(String uid, String displayName) async {
    await _profiles.doc(uid).update(<String, dynamic>{
      'displayName': displayName,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
