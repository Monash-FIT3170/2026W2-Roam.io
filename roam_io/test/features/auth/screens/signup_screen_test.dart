/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 17/05/2026
 * Description:
 *   Widget tests for signup form username and password validation rules.
 */

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/auth/screens/signup_screen.dart';

void main() {
  testWidgets('keeps registration failures visible below the submit button', (
    tester,
  ) async {
    final provider = AuthProvider(authRepository: _SignupAuthRepository());
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: const SignupScreen(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'user');
    await tester.enterText(find.byType(TextFormField).at(1), 'Name');
    await tester.enterText(find.byType(TextFormField).at(2), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'password12');
    await tester.ensureVisible(find.text('Sign up'));
    await tester.pumpAndSettle();
    final buttonPosition = tester.getTopLeft(find.byType(FilledButton));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    final error = find.text('An account with this email already exists.');
    expect(error, findsOneWidget);
    expect(tester.getTopLeft(find.byType(FilledButton)), buttonPosition);
    expect(
      tester.getTopLeft(error).dy,
      greaterThan(tester.getBottomLeft(find.byType(FilledButton)).dy),
    );
    await tester.ensureVisible(error);
    await tester.pump(const Duration(seconds: 6));
    expect(error, findsOneWidget);
    expect(tester.takeException(), isNull);
    provider.dispose();
  });

  testWidgets('validates username length', (tester) async {
    final repo = _SignupAuthRepository();
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: const SignupScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'ab');
    await tester.enterText(find.byType(TextFormField).at(1), 'Name');
    await tester.enterText(find.byType(TextFormField).at(2), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'password12');
    await tester.ensureVisible(find.text('Sign up'));
    await tester.pumpAndSettle();
    final buttonPosition = tester.getTopLeft(find.byType(FilledButton));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(FilledButton)), buttonPosition);

    expect(
      find.text('Username must be at least 3 characters.'),
      findsOneWidget,
    );
    provider.dispose();
  });

  testWidgets('validates password minimum length', (tester) async {
    final repo = _SignupAuthRepository();
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: const SignupScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'user');
    await tester.enterText(find.byType(TextFormField).at(1), 'Name');
    await tester.enterText(find.byType(TextFormField).at(2), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'short');
    await tester.ensureVisible(find.text('Sign up'));
    await tester.pumpAndSettle();
    final buttonPosition = tester.getTopLeft(find.byType(FilledButton));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(FilledButton)), buttonPosition);

    expect(
      find.text('Password must be at least 8 characters.'),
      findsOneWidget,
    );
    provider.dispose();
  });
}

class _SignupAuthRepository implements AuthRepository {
  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    throw firebase_auth.FirebaseAuthException(code: 'email-already-in-use');
  }

  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield null;
  }

  @override
  firebase_auth.User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
