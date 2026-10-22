/*
 * Description:
 *   Larger Text and High Contrast layout checks for the signed-out auth
 *   screens. These show before a profile loads, so they are reached through
 *   the device text size and the OS contrast setting.
 */

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/auth/screens/forgot_password_screen.dart';
import 'package:roam_io/features/auth/screens/login_screen.dart';
import 'package:roam_io/features/auth/screens/signup_screen.dart';

import '../../../support/accessibility_harness.dart';

class _SignedOutRepository implements AuthRepository {
  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield null;
  }

  @override
  firebase_auth.User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final screens = <String, Widget Function()>{
    'login': () => const LoginScreen(),
    'signup': () => const SignupScreen(),
    'forgot password': () => const ForgotPasswordScreen(),
  };

  for (final screen in screens.entries) {
    testAccessibleLayouts('${screen.key} screen lays out', (
      tester,
      theme,
      scale,
    ) async {
      final provider = AuthProvider(authRepository: _SignedOutRepository());
      addTearDown(provider.dispose);

      await pumpAccessible(
        tester,
        ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: screen.value(),
        ),
        theme: theme,
        textScale: scale,
        largerText: true,
      );
    });
  }
}
