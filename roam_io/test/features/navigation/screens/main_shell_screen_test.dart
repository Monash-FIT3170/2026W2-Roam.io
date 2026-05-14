import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/journeys/screens/journeys_screen.dart';
import 'package:roam_io/features/navigation/screens/main_shell_screen.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

import '../../../support/fake_firebase_user.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  testWidgets('starts on map tab and switches to journeys when tapped', (
    tester,
  ) async {
    final repo = _MainShellAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => AuthProvider(authRepository: repo),
          child: const MainShellScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(JourneysScreen, skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('JOURNEYS'));
    await tester.pumpAndSettle();

    expect(find.text('32 XP earned'), findsOneWidget);
  });
}

class _MainShellAuthRepository implements AuthRepository {
  _MainShellAuthRepository()
    : _user = FakeFirebaseUser(
        uid: 'shell-user',
        email: 'shell@test.com',
        emailVerified: true,
      ),
      _profile = ProfileModel(
        uid: 'shell-user',
        username: 'shell',
        displayName: 'Shell User',
        email: 'shell@test.com',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );

  final firebase_auth.User _user;
  final ProfileModel _profile;

  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield _user;
  }

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<ProfileModel?> getCurrentUserProfile() async => _profile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
