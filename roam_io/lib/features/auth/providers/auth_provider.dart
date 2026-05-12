/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Manages authentication, profile XP, level-up state, and account actions
 *   exposed to the widget tree.
 */

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../data/auth_repository.dart';
import '../../profile/domain/profile_model.dart';

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
      await _authRepository.reloadCurrentUser();

      final user = _authRepository.currentUser;
      _currentUser = user;
      _currentProfile = user == null
          ? null
          : await _authRepository.getCurrentUserProfile();
      _viewState = user == null
          ? AuthViewState.unauthenticated
          : AuthViewState.authenticated;
    });
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

  /// Adds XP and updates local profile/level-up state after the write succeeds.
  Future<bool> addXp(int xpToAdd) async {
    var didLevelUp = false;
    await _runAuthAction(() async {
      final currentProfile = _currentProfile;
      final currentXp = currentProfile?.xp ?? 0;
      final oldLevel =
          currentProfile?.level ?? ProfileModel.levelFromXp(currentXp);
      final newXp = currentXp + xpToAdd;
      final newLevel = ProfileModel.levelFromXp(newXp);

      await _authRepository.addXp(xpToAdd);
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
        return 'For security, please log in again before changing your password.';
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
