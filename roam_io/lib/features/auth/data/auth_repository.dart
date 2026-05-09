import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';

import '../../profile/domain/profile_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/storage_service.dart';

/// Repository that orchestrates auth + profile workflows.
///
/// Why this layer exists:
/// - UI/provider code calls one stable API.
/// - Multi-step backend flows live in one place.
/// - Service implementations can change without rewriting UI logic.
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

  /// Registration flow:
  /// 1) create Firebase Auth account
  /// 2) create Firestore profile document
  /// 3) send verification email
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

  /// Email/password sign in.
  Future<void> signIn({required String email, required String password}) async {
    await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Initiates forgot-password email flow.
  Future<void> sendPasswordResetEmail(String email) {
    return _authService.sendPasswordResetEmail(email: email);
  }

  /// Resends verification email for current user.
  Future<void> sendVerificationEmail() => _authService.sendEmailVerification();

  /// Refreshes current user state from Firebase (useful for emailVerified).
  Future<void> reloadCurrentUser() => _authService.reloadCurrentUser();

  /// Changes password after user re-authentication.
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

  /// Loads signed-in user's profile from Firestore.
  Future<ProfileModel?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return _profileService.getProfile(user.uid);
  }

  /// Persists the signed-in user's dark mode preference.
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

  /// Updates the signed-in user's XP.
  Future<void> updateXp(int newXp) async {
    final user = currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No logged in user found.',
      );
    }

    await _profileService.updateXp(user.uid, newXp);
  }

  /// Adds XP to the signed-in user's current XP.
  Future<void> addXp(int xpToAdd) async {
    final user = currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No logged in user found.',
      );
    }

    await _profileService.addXp(user.uid, xpToAdd);
  }

  /// Signs out from Firebase.
  Future<void> signOut() => _authService.signOut();
}

enum ProfilePhotoUploadResult { updated, unchanged }
