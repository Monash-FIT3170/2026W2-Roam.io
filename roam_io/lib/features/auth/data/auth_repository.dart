/*
 * Author: Alvin Liong
 * Last Modified: 4/05/2026
 * Description:
 *   Coordinates authentication, profile, and storage services for user account
 *   workflows.
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';

import '../../profile/domain/profile_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/storage_service.dart';

/// Orchestrates multi-step auth, profile, and profile photo workflows.
class AuthRepository {
  AuthRepository({
    AuthService? authService,
    ProfileService? profileService,
    StorageService? storageService,
  }) : _authService = authService ?? AuthService(),
       _profileService = profileService ?? ProfileService(),
       _storageService = storageService ?? StorageService();

  final AuthService _authService;
  final ProfileService _profileService;
  final StorageService _storageService;

  /// Exposes auth state changes for app-level auth gating.
  Stream<User?> authStateChanges() => _authService.authStateChanges();

  /// Currently authenticated user.
  User? get currentUser => _authService.currentUser;

  /// Creates a Firebase Auth account, profile document, and verification email.
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final credential = await _authService.signUpWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      // Firebase should return a user after account creation; surface a clear error if not.
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'User account was not created correctly.',
      );
    }

    final now = DateTime.now();
    final profile = ProfileModel(
      uid: user.uid,
      username: username,
      displayName: displayName,
      email: email,
      createdAt: now,
      updatedAt: now,
      darkModeEnabled: false,
    );
    await _profileService.createProfile(profile);
    await _authService.sendEmailVerification();
  }

  /// Signs in a user with email and password credentials.
  Future<void> signIn({required String email, required String password}) async {
    await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sends a password reset email to the requested address.
  Future<void> sendPasswordResetEmail(String email) {
    return _authService.sendPasswordResetEmail(email: email);
  }

  /// Resends the verification email for the current user.
  Future<void> sendVerificationEmail() => _authService.sendEmailVerification();

  /// Refreshes current user state from Firebase, including email verification.
  Future<void> reloadCurrentUser() => _authService.reloadCurrentUser();

  /// Changes the current user's password after re-authentication.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _authService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Updates the signed-in user's display name in Firestore and Firebase Auth.
  Future<void> updateDisplayName(String displayName) async {
    final user = currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No logged in user found.',
      );
    }

    await _profileService.updateDisplayName(user.uid, displayName);
    await _authService.updateDisplayName(displayName);
  }

  /// Loads the signed-in user's profile from Firestore.
  Future<ProfileModel?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return _profileService.getProfile(user.uid);
  }

  /// Persists the signed-in user's dark mode preference in Firestore.
  Future<void> updateDarkModePreference(bool enabled) async {
    final user = currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No logged in user found.',
      );
    }

    await _profileService.updateDarkModePreference(
      uid: user.uid,
      enabled: enabled,
    );
  }

  /// Uploads a profile image when it differs from the current stored photo.
  Future<ProfilePhotoUploadResult> uploadProfilePicture({
    required XFile image,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No authenticated user is available.',
      );
    }
    final imageBytes = await image.readAsBytes();
    final photoHash = sha256.convert(imageBytes).toString();
    final currentProfile = await getCurrentUserProfile();

    if (currentProfile?.photoHash == photoHash) {
      return ProfilePhotoUploadResult.unchanged;
    }

    final currentPhotoUrl = currentProfile?.photoUrl;
    if (currentProfile?.photoHash == null &&
        currentPhotoUrl != null &&
        currentPhotoUrl.isNotEmpty) {
      // Older profiles may have a photo URL but no stored hash yet.
      final currentPhotoHash = await _tryHashCurrentProfilePhoto(
        currentPhotoUrl,
      );
      if (currentPhotoHash == photoHash) {
        await _profileService.updateProfilePhotoHash(
          uid: user.uid,
          photoHash: photoHash,
        );
        return ProfilePhotoUploadResult.unchanged;
      }
    }

    final photoUrl = await _storageService.uploadProfilePhoto(
      uid: user.uid,
      bytes: imageBytes,
      filename: image.name,
    );

    await _profileService.updateProfilePhoto(
      uid: user.uid,
      photoUrl: photoUrl,
      photoHash: photoHash,
    );

    return ProfilePhotoUploadResult.updated;
  }

  Future<String?> _tryHashCurrentProfilePhoto(String photoUrl) async {
    try {
      final bytes = await _storageService.downloadBytesFromUrl(photoUrl);
      if (bytes == null) return null;
      return sha256.convert(bytes).toString();
    } catch (_) {
      return null;
    }
  }

  /// Signs out from Firebase.
  Future<void> signOut() => _authService.signOut();
}

/// Result of comparing a selected profile photo with the stored profile photo.
enum ProfilePhotoUploadResult { updated, unchanged }
