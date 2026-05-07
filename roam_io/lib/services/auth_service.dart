/*
 * Author: Alvin Liong
 * Last Modified: 1/05/2026
 * Description:
 *   Provides Firebase Authentication operations used by the authentication
 *   repository and app-level auth state.
 */

import 'package:firebase_auth/firebase_auth.dart';

/// Wraps Firebase Authentication calls behind a small app-specific API.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  /// Stream used by UI/provider layers to react to login/logout changes.
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  /// Currently signed-in Firebase user (null if signed out).
  User? get currentUser => _firebaseAuth.currentUser;

  /// Creates a new account with email and password.
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs in an existing account with email and password.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sends verification email to the currently signed-in user.
  Future<void> sendEmailVerification() async {
    final user = currentUser;
    if (user == null) return;
    await user.sendEmailVerification();
  }

  /// Sends a password reset email to the provided address.
  Future<void> sendPasswordResetEmail({required String email}) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Re-authenticates the current user and applies a new password.
  ///
  /// Firebase requires recent authentication for sensitive actions, so we:
  /// 1) re-authenticate using current password
  /// 2) apply the new password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No logged in user found.',
      );
    }

    // Firebase requires recent authentication before password changes.
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Updates the Firebase Auth display name for the current user.
  Future<void> updateDisplayName(String displayName) async {
    await currentUser?.updateDisplayName(displayName);
  }

  /// Refreshes cached user data (e.g., updated emailVerified state).
  Future<void> reloadCurrentUser() async {
    await currentUser?.reload();
  }

  /// Ends the current authenticated session on this device.
  Future<void> signOut() => _firebaseAuth.signOut();
}
