import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/auth/screens/change_password_screen.dart';

import '../../../support/fake_firebase_user.dart';

void main() {
  testWidgets('validates new password length and confirmation match', (
    tester,
  ) async {
    final user = FakeFirebaseUser(uid: 'u1', email: 'a@b.com');
    final repo = _ChangePasswordRepository(user);
    final provider = AuthProvider(authRepository: repo);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: const ChangePasswordScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'oldpass12');
    await tester.enterText(find.byType(TextFormField).at(1), 'short');
    await tester.enterText(find.byType(TextFormField).at(2), 'short');
    await tester.tap(find.text('Update password'));
    await tester.pump();

    expect(
      find.text('New password must be at least 8 characters.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).at(1), 'longenough');
    await tester.enterText(find.byType(TextFormField).at(2), 'different');
    await tester.tap(find.text('Update password'));
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    provider.dispose();
  });
}

class _ChangePasswordRepository implements AuthRepository {
  _ChangePasswordRepository(this._user);

  final firebase_auth.User _user;

  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield _user;
  }

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
