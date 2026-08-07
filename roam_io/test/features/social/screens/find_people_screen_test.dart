/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Widget tests for Find People search results and relationship actions.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/features/social/data/friendship_service.dart';
import 'package:roam_io/features/social/domain/friend_relationship.dart';
import 'package:roam_io/features/social/domain/friend_request.dart';
import 'package:roam_io/features/social/domain/public_profile.dart';
import 'package:roam_io/features/social/screens/find_people_screen.dart';
import 'package:roam_io/features/social/screens/other_user_profile_screen.dart';
import 'package:roam_io/shared/widgets/app_toast.dart';

import '../../../support/fake_firebase_user.dart';

void main() {
  testWidgets('empty search page renders no instructional placeholder', (
    tester,
  ) async {
    final service = FriendshipService(firestore: FakeFirebaseFirestore());

    await _pumpFindPeople(tester, service);

    expect(find.text('Search results'), findsNothing);
    expect(find.text('Type at least 2 characters.'), findsNothing);
    expect(find.text('Start typing'), findsNothing);
    expect(find.text('No people found.'), findsNothing);
  });

  testWidgets('one-character query searches without showing placeholder', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = FriendshipService(firestore: firestore);
    await service.upsertPublicProfile(
      uid: 'jacob',
      username: 'jacob_delapaz',
      displayName: 'Jacob de la Paz',
    );

    await _pumpFindPeople(tester, service);
    await tester.enterText(find.byType(TextField), 'j');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Type at least 2 characters.'), findsNothing);
    expect(find.text('Jacob de la Paz'), findsOneWidget);
    expect(find.text('@jacob_delapaz'), findsOneWidget);
  });

  testWidgets('search renders result rows and sends a request reactively', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = FriendshipService(firestore: firestore);
    await service.upsertPublicProfile(
      uid: 'other-user',
      username: 'nathan',
      displayName: 'Nathan Nunes',
    );

    await _pumpFindPeople(tester, service);
    await tester.enterText(find.byType(TextField), 'nath');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Nathan Nunes'), findsOneWidget);
    expect(find.text('@nathan'), findsOneWidget);
    expect(find.text('Add Friend'), findsOneWidget);
    expect(find.text('Search results'), findsNothing);

    await tester.tap(find.text('Add Friend'));
    await tester.pumpAndSettle();

    expect(find.text('Request Sent'), findsOneWidget);
    expect(find.byType(OtherUserProfileScreen), findsNothing);
  });

  testWidgets('search shows no-result state', (tester) async {
    final service = FriendshipService(firestore: FakeFirebaseFirestore());

    await _pumpFindPeople(tester, service);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('No people found.'), findsOneWidget);
  });

  testWidgets('clearing search removes existing results', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = FriendshipService(firestore: firestore);
    await service.upsertPublicProfile(
      uid: 'other-user',
      username: 'nathan',
      displayName: 'Nathan Nunes',
    );

    await _pumpFindPeople(tester, service);
    await tester.enterText(find.byType(TextField), 'nath');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Nathan Nunes'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    expect(find.text('Nathan Nunes'), findsNothing);
    expect(find.text('Type at least 2 characters.'), findsNothing);
    expect(find.text('No people found.'), findsNothing);
  });

  testWidgets('search failure does not show the global failure toast', (
    tester,
  ) async {
    await _pumpFindPeople(tester, _ThrowingSearchFriendshipService());

    await tester.enterText(find.byType(TextField), 'fail');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Could not search people right now.'), findsNothing);
    expect(find.text('No people found.'), findsNothing);
    expect(find.byType(AppToastBanner), findsNothing);
  });

  testWidgets('relationship stream failure does not hide profile result', (
    tester,
  ) async {
    await _pumpFindPeople(
      tester,
      const _RelationshipErrorFriendshipService(
        PublicProfile(
          uid: 'jacob',
          username: 'jacob_delapaz',
          displayName: 'Jacob de la Paz',
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'jacob');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Jacob de la Paz'), findsOneWidget);
    expect(find.text('@jacob_delapaz'), findsOneWidget);
  });

  testWidgets('tapping profile content opens selected read-only profile', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = FriendshipService(firestore: firestore);
    await service.upsertPublicProfile(
      uid: 'other-user',
      username: 'nathan',
      displayName: 'Nathan Nunes',
      xp: 140,
      level: 2,
    );

    await _pumpFindPeople(tester, service);
    await tester.enterText(find.byType(TextField), 'nath');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nathan Nunes'));
    await tester.pumpAndSettle();

    expect(find.byType(OtherUserProfileScreen), findsOneWidget);
    expect(find.text('Nathan Nunes'), findsOneWidget);
    expect(find.text('@nathan'), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('Activity and stats are not public yet.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(FindPeopleScreen), findsOneWidget);
    expect(find.text('Nathan Nunes'), findsOneWidget);
  });

  testWidgets('incoming request can be accepted from result row', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = FriendshipService(firestore: firestore);
    final pairKey = FriendshipService.pairKeyFor('current-user', 'other-user');
    final now = DateTime(2026, 8, 7);
    await service.upsertPublicProfile(
      uid: 'other-user',
      username: 'alex',
      displayName: 'Alex Friend',
    );
    await firestore
        .collection(FriendshipService.friendRequestsCollection)
        .doc(pairKey)
        .set(
          FriendRequest(
            id: pairKey,
            pairKey: pairKey,
            senderId: 'other-user',
            recipientId: 'current-user',
            status: FriendRequestStatus.pending,
            createdAt: now,
            updatedAt: now,
          ).toMap(),
        );

    await _pumpFindPeople(tester, service);
    await tester.enterText(find.byType(TextField), 'alex');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.text('Friends'), findsOneWidget);
  });
}

class _ThrowingSearchFriendshipService implements FriendshipService {
  @override
  Future<List<PublicProfile>> searchUsers({
    required String query,
    required String currentUserId,
    int limit = 20,
  }) async {
    throw Exception('simulated search failure');
  }

  @override
  Stream<FriendRelationship> watchRelationship({
    required String currentUserId,
    required String otherUserId,
  }) {
    return Stream<FriendRelationship>.value(const FriendRelationship.none());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RelationshipErrorFriendshipService implements FriendshipService {
  const _RelationshipErrorFriendshipService(this.profile);

  final PublicProfile profile;

  @override
  Future<List<PublicProfile>> searchUsers({
    required String query,
    required String currentUserId,
    int limit = 20,
  }) async {
    return [profile];
  }

  @override
  Stream<FriendRelationship> watchRelationship({
    required String currentUserId,
    required String otherUserId,
  }) {
    return Stream<FriendRelationship>.error(Exception('relationship failed'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpFindPeople(
  WidgetTester tester,
  FriendshipService service,
) async {
  final auth = AuthProvider(authRepository: _FindPeopleAuthRepository());
  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: FindPeopleScreen(friendshipService: service),
      ),
    ),
  );
  await tester.pump();
}

class _FindPeopleAuthRepository implements AuthRepository {
  _FindPeopleAuthRepository()
    : _user = FakeFirebaseUser(
        uid: 'current-user',
        email: 'current@test.com',
        emailVerified: true,
      ),
      _profile = ProfileModel(
        uid: 'current-user',
        username: 'current',
        displayName: 'Current User',
        email: 'current@test.com',
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
