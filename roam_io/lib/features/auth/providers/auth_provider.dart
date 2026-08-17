/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Manages authentication, profile XP, level-up state, and Settings account
 *   edit actions exposed to the widget tree. XP awards return an explicit
 *   XpAwardResult so callers never treat a failed write as success.
 */

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../data/auth_repository.dart';
import '../../profile/domain/profile_model.dart';
import '../../profile/domain/xp_award_result.dart';
import '../../profile/domain/xp_event.dart';
import '../../social/domain/social_privacy_settings.dart';

/// High-level authentication state used by auth gates and account screens.
enum AuthViewState { loading, authenticated, unauthenticated }

/// Provides authentication and profile state to UI layers.
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository() {
    _authStateSub = _authRepository.authStateChanges().listen(_handleAuthState);
  }

  final AuthRepository _authRepository;
  StreamSubscription<User?>? _authStateSub;

  AuthViewState _viewState = AuthViewState.loading;
  bool _isBusy = false;
  String? _errorMessage;
  User? _currentUser;
  ProfileModel? _currentProfile;
  ProfilePhotoUploadResult? _lastProfilePhotoUploadResult;
  int? _pendingLevelUp;
  String? _pendingUnlockToastMessage;

  AuthViewState get viewState => _viewState;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;
  ProfileModel? get currentProfile => _currentProfile;
  ProfilePhotoUploadResult? get lastProfilePhotoUploadResult =>
      _lastProfilePhotoUploadResult;
  bool get wasLastProfilePhotoUploadUnchanged =>
      _lastProfilePhotoUploadResult == ProfilePhotoUploadResult.unchanged;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmailVerified => _currentUser?.emailVerified ?? false;
  bool get darkModeEnabled => _currentProfile?.darkModeEnabled ?? false;
  SocialPrivacySettings get socialPrivacy =>
      _currentProfile?.privacy ?? const SocialPrivacySettings();
  int? get pendingLevelUp => _pendingLevelUp;

  /// Clears the current user-facing error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clears a pending level-up notification after the app displays it.
  void clearPendingLevelUp() {
    _pendingLevelUp = null;
    notifyListeners();
  }

  /// Stages unlock XP toast copy to show inside the level-up celebration overlay.
  void stageUnlockToast(String message) {
    _pendingUnlockToastMessage = message;
  }

  /// Returns and clears a staged unlock toast, if any.
  String? takePendingUnlockToast() {
    final message = _pendingUnlockToastMessage;
    _pendingUnlockToastMessage = null;
    return message;
  }

  /// Registers a new user and refreshes the current Firebase/profile state.
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    await _runAuthAction(() async {
      await _authRepository.signUp(
        email: email,
        password: password,
        username: username,
        displayName: displayName,
      );
      await refreshCurrentUser();
    });
  }

  /// Signs in a user and refreshes their Firebase/profile state.
  Future<void> signIn({required String email, required String password}) async {
    await _runAuthAction(() async {
      await _authRepository.signIn(email: email, password: password);
      await refreshCurrentUser();
    });
  }

  /// Sends a password reset email through the repository.
  Future<void> sendPasswordResetEmail(String email) async {
    await _runAuthAction(() => _authRepository.sendPasswordResetEmail(email));
  }

  /// Sends a verification email to the current user.
  Future<void> sendVerificationEmail() async {
    await _runAuthAction(_authRepository.sendVerificationEmail);
  }

  /// Reloads the current Firebase user and profile from the backend.
  Future<void> refreshCurrentUser() async {
    await _runAuthAction(() async {
      await _authRepository.reloadCurrentUser();
      final user = _authRepository.currentUser;
      _currentUser = user;
      if (user != null) {
        _currentProfile = await _authRepository.getCurrentUserProfile();
      } else {
        _currentProfile = null;
      }
      _viewState = user == null
          ? AuthViewState.unauthenticated
          : AuthViewState.authenticated;
    });
  }

  /// Changes the current user's password through the repository.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _runAuthAction(
      () => _authRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );
  }

  /// Updates the display name and refreshes user/profile state.
  Future<void> updateDisplayName(String displayName) async {
    await _runAuthAction(() async {
      await _authRepository.updateDisplayName(displayName);
      _currentProfile = _currentProfile?.copyWith(
        displayName: displayName,
        updatedAt: DateTime.now(),
      );
    });
  }

  /// Updates the username and refreshes local profile state.
  Future<void> updateUsername(String username) async {
    await _runAuthAction(() async {
      await _authRepository.updateUsername(username);
      _currentProfile = _currentProfile?.copyWith(
        username: username,
        updatedAt: DateTime.now(),
      );
    });
  }

  /// Requests a verified account email change through Firebase Auth.
  Future<void> requestEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {
    await _runAuthAction(
      () => _authRepository.requestEmailChange(
        currentPassword: currentPassword,
        newEmail: newEmail,
      ),
    );
  }

  /// Persists the user's dark mode preference and updates local profile state.
  Future<void> updateDarkModePreference(bool enabled) async {
    await _runAuthAction(() async {
      await _authRepository.updateDarkModePreference(enabled);
      _currentProfile = _currentProfile?.copyWith(
        darkModeEnabled: enabled,
        updatedAt: DateTime.now(),
      );
    });
  }

  /// Persists private-account settings and updates local profile state.
  Future<void> updateSocialPrivacy(SocialPrivacySettings privacy) async {
    await _runAuthAction(() async {
      await _authRepository.updateSocialPrivacy(privacy);
      _currentProfile = _currentProfile?.copyWith(
        privacy: privacy,
        updatedAt: DateTime.now(),
      );
    });
  }

  /// Uploads a new profile picture and refreshes the current profile.
  Future<void> uploadProfilePicture(XFile image) async {
    _lastProfilePhotoUploadResult = null;
    await _runAuthAction(() async {
      _lastProfilePhotoUploadResult = await _authRepository
          .uploadProfilePicture(image: image);
      _currentProfile = await _authRepository.getCurrentUserProfile();
    });
  }

  /// Updates the signed-in user's XP and local level state immediately.
  Future<bool> updateXp(int newXp) async {
    var didLevelUp = false;
    await _runAuthAction(() async {
      final oldLevel = _currentProfile?.level ?? 1;
      await _authRepository.updateXp(newXp);
      final newLevel = ProfileModel.levelFromXp(newXp);
      final currentProfile = _currentProfile;
      _currentProfile = currentProfile == null
          ? await _authRepository.getCurrentUserProfile()
          : currentProfile.copyWith(xp: newXp, level: newLevel);

      if (newLevel > oldLevel) {
        _pendingLevelUp = newLevel;
        didLevelUp = true;
      }
    });
    return didLevelUp;
  }

  /// Awards XP and updates local profile/level state only when the canonical
  /// Firestore write succeeds. Does not use [_runAuthAction] so callers receive
  /// an explicit [XpAwardResult] instead of a swallowed false-success.
  Future<XpAwardResult> addXp(
    int xpToAdd, {
    XpEventSource source = XpEventSource.unknown,
    String? sourceId,
  }) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authRepository.addXp(
        xpToAdd,
        source: source,
        sourceId: sourceId,
      );

      if (!result.succeeded) {
        _errorMessage =
            'We could not save your XP right now. Please try again.';
        return result;
      }

      final currentProfile = _currentProfile;
      _currentProfile = currentProfile == null
          ? await _authRepository.getCurrentUserProfile()
          : currentProfile.copyWith(xp: result.newXp, level: result.newLevel);

      if (result.didLevelUp) {
        _pendingLevelUp = result.newLevel;
      }

      return result;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyAuthMessage(e);
      return XpAwardResult.failed(amount: xpToAdd);
    } on FirebaseException catch (e) {
      _errorMessage = _friendlyFirestoreMessage(e);
      return XpAwardResult.failed(amount: xpToAdd);
    } catch (e) {
      _errorMessage = e.toString();
      return XpAwardResult.failed(amount: xpToAdd);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Signs out and clears local authentication/profile state.
  Future<void> signOut() async {
    await _runAuthAction(() async {
      await _authRepository.signOut();
      _currentProfile = null;
      _currentUser = null;
      _viewState = AuthViewState.unauthenticated;
    });
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyAuthMessage(e);
    } on FirebaseException catch (e) {
      _errorMessage = _friendlyFirestoreMessage(e);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      // Always release the busy flag so screens can re-enable controls.
      _isBusy = false;
      notifyListeners();
    }
  }

  void _handleAuthState(User? user) {
    _currentUser = user;
    _viewState = user == null
        ? AuthViewState.unauthenticated
        : AuthViewState.authenticated;
    if (user == null) {
      _currentProfile = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    super.dispose();
  }

  String _friendlyAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again shortly.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      case 'requires-recent-login':
        return 'For security, please log in again before changing account details.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  String _friendlyFirestoreMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'unavailable':
        return 'Service is temporarily unavailable. Please try again.';
      default:
        return 'We could not save your data right now. Please try again.';
    }
  }
}
