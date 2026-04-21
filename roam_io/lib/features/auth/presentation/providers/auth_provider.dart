import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/auth_repository.dart';
import '../../../profile/domain/profile_model.dart';

enum AuthViewState { loading, authenticated, unauthenticated }

/// App-level auth state holder for UI layers.
///
/// This provider exposes:
/// - current auth/session state
/// - loading/error flags
/// - auth actions used by future screens
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

  AuthViewState get viewState => _viewState;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;
  ProfileModel? get currentProfile => _currentProfile;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmailVerified => _currentUser?.emailVerified ?? false;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

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

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _runAuthAction(() async {
      await _authRepository.signIn(email: email, password: password);
      await refreshCurrentUser();
    });
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _runAuthAction(() => _authRepository.sendPasswordResetEmail(email));
  }

  Future<void> sendVerificationEmail() async {
    await _runAuthAction(_authRepository.sendVerificationEmail);
  }

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
      _errorMessage = e.message ?? e.code;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
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
}
