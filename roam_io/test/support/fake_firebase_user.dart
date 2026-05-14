import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// Minimal [firebase_auth.User] for widget and provider tests.
class FakeFirebaseUser implements firebase_auth.User {
  FakeFirebaseUser({
    required this.uid,
    required this.email,
    this.emailVerified = true,
  });

  @override
  final String uid;

  @override
  final String? email;

  @override
  final bool emailVerified;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
