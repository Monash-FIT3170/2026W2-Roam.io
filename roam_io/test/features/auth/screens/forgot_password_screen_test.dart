import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/auth/screens/forgot_password_screen.dart';

void main() {
  testWidgets('requires email before submitting', (tester) async {
    final repo = _ForgotPasswordRepository();
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: const ForgotPasswordScreen(),
        ),
      ),
    );

    await tester.tap(find.text('Send reset email'));
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(repo.sendResetCalls, 0);
    provider.dispose();
  });
}

class _ForgotPasswordRepository implements AuthRepository {
  int sendResetCalls = 0;

  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield null;
  }

  @override
  firebase_auth.User? get currentUser => null;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    sendResetCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
