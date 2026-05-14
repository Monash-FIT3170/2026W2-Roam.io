import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('shows email validation error when fields are empty', (
    tester,
  ) async {
    final repo = _MinimalAuthRepository();
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: const LoginScreen(),
        ),
      ),
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    provider.dispose();
  });

  testWidgets('shows invalid email message for malformed email', (tester) async {
    final repo = _MinimalAuthRepository();
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: const LoginScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'bad');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret12');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    provider.dispose();
  });

  testWidgets('shows busy indicator while sign-in is in progress', (
    tester,
  ) async {
    final completer = Completer<void>();
    final repo = _BlockingSignInRepository(completer.future);
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: const LoginScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password12');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete();
    await tester.pumpAndSettle();
    provider.dispose();
  });
}

class _MinimalAuthRepository implements AuthRepository {
  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield null;
  }

  @override
  firebase_auth.User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BlockingSignInRepository implements AuthRepository {
  _BlockingSignInRepository(this._block);

  final Future<void> _block;

  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield null;
  }

  @override
  firebase_auth.User? get currentUser => null;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _block;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
