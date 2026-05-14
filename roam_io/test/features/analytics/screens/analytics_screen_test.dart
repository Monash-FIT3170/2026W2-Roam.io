/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 14/05/2026
 * Description:
 *   Regression tests for analytics screen profile-driven stat values.
 */

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/analytics/screens/analytics_screen.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/map/data/visit.dart';
import 'package:roam_io/features/map/data/visit_service.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

void main() {
  testWidgets('shows current profile XP instead of placeholder XP', (
    tester,
  ) async {
    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 12345)),
    );
    await provider.refreshCurrentUser();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: AnalyticsScreen(visitService: _FakeVisitService()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('XP Count'), findsOneWidget);
    expect(find.text('12,345'), findsOneWidget);
    expect(find.text('2,450'), findsNothing);

    provider.dispose();
  });
}

ProfileModel _buildProfile({required int xp}) {
  return ProfileModel(
    uid: 'user-1',
    username: 'traveller',
    displayName: 'Traveller',
    email: 'traveller@example.com',
    createdAt: DateTime(2026, 5, 1, 10),
    updatedAt: DateTime(2026, 5, 1, 11),
    xp: xp,
    level: ProfileModel.levelFromXp(xp),
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._profile);

  final ProfileModel _profile;
  final _FakeUser _user = _FakeUser(
    uid: 'user-1',
    email: 'traveller@example.com',
  );

  @override
  Stream<firebase_auth.User?> authStateChanges() =>
      Stream<firebase_auth.User?>.value(_user);

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Future<ProfileModel?> getCurrentUserProfile() async => _profile;

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVisitService implements VisitService {
  @override
  Stream<List<Visit>> watchRecentVisits(String userId, {int limit = 5}) {
    return Stream<List<Visit>>.value(const <Visit>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements firebase_auth.User {
  _FakeUser({required this.uid, required this.email});

  @override
  final String uid;

  @override
  final String? email;

  @override
  bool get emailVerified => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
