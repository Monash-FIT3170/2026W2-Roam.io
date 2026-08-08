/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Widget tests for the Social destination foundation.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/features/social/data/follow_service.dart';
import 'package:roam_io/features/social/data/friendship_service.dart';
import 'package:roam_io/features/social/screens/find_people_screen.dart';
import 'package:roam_io/features/social/screens/social_screen.dart';

import '../../../support/fake_firebase_user.dart';

void main() {
  testWidgets('shows the social foundation page without fake actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SocialScreen())),
    );

    expect(find.text('Social'), findsOneWidget);
    expect(find.text('Social hub'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('search icon opens Find People screen', (tester) async {
    final auth = AuthProvider(authRepository: _SocialAuthRepository());
    final firestore = FakeFirebaseFirestore();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: Scaffold(
            body: SocialScreen(
              friendshipService: FriendshipService(firestore: firestore),
              followService: FollowService(firestore: firestore),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Find people'));
    await tester.pumpAndSettle();

    expect(find.byType(FindPeopleScreen), findsOneWidget);
    expect(find.text('Find People'), findsOneWidget);
    expect(find.text('Search results'), findsNothing);
  });

  testWidgets('title and search action share the same header row', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SocialScreen())),
    );

    final titleCenter = tester.getCenter(find.text('Social'));
    final searchCenter = tester.getCenter(find.byTooltip('Find people'));

    expect((titleCenter.dy - searchCenter.dy).abs(), lessThan(18));
  });

  testWidgets('search icon uses standard foreground colour not primary green', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SocialScreen())),
    );

    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.search),
    );
    final theme = Theme.of(
      tester.element(find.widgetWithIcon(IconButton, Icons.search)),
    );

    expect(button.color, theme.colorScheme.onSurface);
    expect(button.color, isNot(theme.colorScheme.primary));
  });
}

class _SocialAuthRepository implements AuthRepository {
  _SocialAuthRepository()
    : _user = FakeFirebaseUser(
        uid: 'social-user',
        email: 'social@test.com',
        emailVerified: true,
      ),
      _profile = ProfileModel(
        uid: 'social-user',
        username: 'social',
        displayName: 'Social User',
        email: 'social@test.com',
        createdAt: DateTime(2026, 8, 7),
        updatedAt: DateTime(2026, 8, 7),
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
