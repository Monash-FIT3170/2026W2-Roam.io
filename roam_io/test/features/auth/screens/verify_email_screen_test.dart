import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/auth/screens/verify_email_screen.dart';

import '../../../support/fake_firebase_user.dart';

void main() {
  testWidgets('shows signed-in email and primary actions', (tester) async {
    final user = FakeFirebaseUser(
      uid: 'u1',
      email: 'who@example.com',
      emailVerified: false,
    );
    final repo = _VerifyEmailRepository(user);
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: const VerifyEmailScreen(),
        ),
      ),
    );

    expect(find.textContaining('who@example.com'), findsOneWidget);
    expect(find.text('Resend verification email'), findsOneWidget);
    expect(find.text('I have verified, refresh'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    provider.dispose();
  });
}

class _VerifyEmailRepository implements AuthRepository {
  _VerifyEmailRepository(this._user);

  final firebase_auth.User _user;

  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield _user;
  }

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> sendVerificationEmail() async {}

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
