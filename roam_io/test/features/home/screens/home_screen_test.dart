/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Widget tests for the real Firestore-backed Home activity feed and Comment
 *   navigation.
 */

import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/activity_feed/data/activity_feed_service.dart';
import 'package:roam_io/features/activity_feed/data/comment_service.dart';
import 'package:roam_io/features/activity_feed/models/activity_comment.dart';
import 'package:roam_io/features/activity_feed/models/activity_feed_item.dart';
import 'package:roam_io/features/activity_feed/screens/activity_detail_screen.dart';
import 'package:roam_io/features/activity_feed/screens/comments_screen.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/home/screens/home_screen.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/features/social/data/follow_service.dart';

void main() {
  testWidgets('starts without stub cards or old Journeys/Quests tabs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = await _pumpHome(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('No activities yet'), findsOneWidget);
    expect(find.text('Journeys'), findsNothing);
    expect(find.text('Quests'), findsNothing);

    await harness.dispose();
  });

  testWidgets('renders newly inserted own activity without restart', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final firestore = FakeFirebaseFirestore();
    final harness = await _pumpHome(tester, firestore: firestore);

    expect(find.text('No activities yet'), findsOneWidget);

    await _seedActivity(
      firestore,
      activityId: 'activity-1',
      ownerId: 'user-1',
      displayName: 'Traveller',
      username: 'traveller',
      title: 'Traveller Activity 1',
      createdAt: DateTime(2026, 8, 10),
    );
    await tester.pumpAndSettle();

    expect(find.text('No activities yet'), findsNothing);
    expect(find.text('Traveller Activity 1'), findsOneWidget);

    await _seedActivity(
      firestore,
      activityId: 'activity-2',
      ownerId: 'user-1',
      displayName: 'Traveller',
      username: 'traveller',
      title: 'Traveller Activity 2',
      createdAt: DateTime(2026, 8, 11),
    );
    await tester.pumpAndSettle();

    expect(find.text('Traveller Activity 2'), findsOneWidget);
    expect(find.text('Traveller Activity 1'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Traveller Activity 2')).dy,
      lessThan(tester.getTopLeft(find.text('Traveller Activity 1')).dy),
    );

    await harness.dispose();
  });

  testWidgets(
    'activity stream error shows load failure instead of empty feed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final harness = await _pumpHome(
        tester,
        firestore: FakeFirebaseFirestore(),
        activityFeedService: _FailingActivityFeedService(),
      );

      expect(
        find.text('Could not load activities. Try again.'),
        findsOneWidget,
      );
      expect(find.text('No activities yet'), findsNothing);

      await harness.dispose();
    },
  );

  testWidgets('does not recreate Home activity stream on rebuild', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final firestore = FakeFirebaseFirestore();
    await _seedPublicProfile(firestore, uid: 'user-1');
    final activityFeedService = _CountingActivityFeedService();
    final harness = await _pumpHome(
      tester,
      firestore: firestore,
      activityFeedService: activityFeedService,
    );

    expect(activityFeedService.watchHomeCalls, 1);

    await tester.pump();

    expect(activityFeedService.watchHomeCalls, 1);

    await harness.dispose();
  });

  testWidgets('overflow opens persisted activity detail with Home engagement', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final firestore = FakeFirebaseFirestore();
    await _seedActivity(
      firestore,
      activityId: 'activity-1',
      ownerId: 'user-1',
      displayName: 'Traveller',
      username: 'traveller',
      title: 'Traveller Activity 1',
    );
    final harness = await _pumpHome(tester, firestore: firestore);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byType(ActivityDetailScreen), findsOneWidget);
    expect(find.text('Traveller Activity 1'), findsOneWidget);
    expect(find.text('Journey route map'), findsOneWidget);
    expect(find.text('Kudos'), findsOneWidget);
    expect(find.text('0 comments'), findsOneWidget);
    expect(find.text('Share'), findsNothing);

    await harness.dispose();
  });

  testWidgets('Comment opens Comments page and count updates after post', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final firestore = FakeFirebaseFirestore();
    await _seedActivity(
      firestore,
      activityId: 'activity-1',
      ownerId: 'user-1',
      displayName: 'Traveller',
      username: 'traveller',
      title: 'Traveller Activity 1',
    );
    final harness = await _pumpHome(tester, firestore: firestore);

    expect(find.text('0 comments').first, findsOneWidget);

    await tester.tap(find.text('0 comments').first);
    await tester.pumpAndSettle();

    expect(find.byType(CommentsScreen), findsOneWidget);
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('Write a comment...'), findsOneWidget);
    expect(find.text('No comments yet'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Nice work');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Send'));
    await tester.pumpAndSettle();

    expect(find.text('Nice work'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('1 comment'), findsWidgets);

    await harness.dispose();
  });

  testWidgets('Home includes own and accepted followed persisted activities', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final firestore = FakeFirebaseFirestore();
    await _seedActivity(
      firestore,
      activityId: 'own-activity',
      ownerId: 'user-1',
      displayName: 'Traveller',
      username: 'traveller',
      title: 'My persisted activity',
    );
    await _seedActivity(
      firestore,
      activityId: 'followed-activity',
      ownerId: 'followed-user',
      displayName: 'Sanjevan Test',
      username: 'sanjevanr_test',
      title: "Sanjevan's Test Activity",
    );
    await _seedActivity(
      firestore,
      activityId: 'hidden-activity',
      ownerId: 'not-followed',
      displayName: 'Hidden',
      username: 'hidden',
      title: 'Hidden activity',
    );
    final followService = FollowService(firestore: firestore);
    await followService.follow(
      followerId: 'user-1',
      followeeId: 'followed-user',
    );
    await firestore
        .collection('follow_requests')
        .doc('user-1_not-followed')
        .set({
          'requesterId': 'user-1',
          'targetId': 'not-followed',
          'status': 'pending',
          'createdAt': DateTime(2026, 8, 10).toIso8601String(),
          'updatedAt': DateTime(2026, 8, 10).toIso8601String(),
        });

    final harness = await _pumpHome(
      tester,
      firestore: firestore,
      followService: followService,
    );

    expect(find.text('My persisted activity'), findsOneWidget);
    expect(find.text("Sanjevan's Test Activity"), findsOneWidget);
    expect(find.text('Hidden activity'), findsNothing);

    await harness.dispose();
  });

  testWidgets('Home removes followed activity reactively after unfollow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final firestore = FakeFirebaseFirestore();
    await _seedActivity(
      firestore,
      activityId: 'followed-activity',
      ownerId: 'followed-user',
      displayName: 'Sanjevan Test',
      username: 'sanjevanr_test',
      title: "Sanjevan's Test Activity",
    );
    final followService = FollowService(firestore: firestore);
    await followService.follow(
      followerId: 'user-1',
      followeeId: 'followed-user',
    );
    final harness = await _pumpHome(
      tester,
      firestore: firestore,
      followService: followService,
    );
    expect(find.text("Sanjevan's Test Activity"), findsOneWidget);

    await followService.unfollow(
      followerId: 'user-1',
      followeeId: 'followed-user',
    );
    await tester.pumpAndSettle();

    expect(find.text("Sanjevan's Test Activity"), findsNothing);

    await harness.dispose();
  });
}

Future<_HomeHarness> _pumpHome(
  WidgetTester tester, {
  FakeFirebaseFirestore? firestore,
  FollowService? followService,
  ActivityFeedService? activityFeedService,
  _FakeAuthRepository? authRepository,
}) async {
  final resolvedFirestore = firestore ?? FakeFirebaseFirestore();
  final auth = AuthProvider(
    authRepository: authRepository ?? _FakeAuthRepository(),
  );
  await auth.refreshCurrentUser();
  final comments = _FakeCommentService();
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            activityFeedService:
                activityFeedService ??
                ActivityFeedService(firestore: resolvedFirestore),
            followService:
                followService ?? FollowService(firestore: resolvedFirestore),
            commentService: comments,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _HomeHarness(auth: auth, comments: comments);
}

Future<void> _seedPublicProfile(
  FakeFirebaseFirestore firestore, {
  required String uid,
}) {
  return firestore.collection('public_profiles').doc(uid).set({
    'uid': uid,
    'username': 'traveller',
    'usernameSearch': 'traveller',
    'displayName': 'Traveller',
    'displayNameSearch': 'traveller',
    'photoUrl': 'https://example.com/avatar.png',
    'createdAt': DateTime(2026, 8, 10).toIso8601String(),
    'updatedAt': DateTime(2026, 8, 10).toIso8601String(),
  });
}

Future<void> _seedActivity(
  FakeFirebaseFirestore firestore, {
  required String activityId,
  required String ownerId,
  required String displayName,
  required String username,
  required String title,
  DateTime? createdAt,
}) {
  return firestore.collection('activities').doc(activityId).set({
    'activityId': activityId,
    'ownerId': ownerId,
    'profileId': ownerId,
    'displayName': displayName,
    'username': username,
    'title': title,
    'kind': 'exploration',
    'showMapPreview': true,
    'createdAt': (createdAt ?? DateTime(2026, 8, 10)).toIso8601String(),
    'metrics': [
      {'label': 'XP Gained', 'value': '+120 XP'},
    ],
  });
}

class _FailingActivityFeedService extends ActivityFeedService {
  _FailingActivityFeedService() : super(firestore: FakeFirebaseFirestore());

  @override
  Stream<List<ActivityFeedItem>> watchHomeActivitiesForUser({
    required String userId,
    required Stream<List<String>> followedUserIds,
  }) {
    return Stream<List<ActivityFeedItem>>.error(StateError('query failed'));
  }
}

class _CountingActivityFeedService extends ActivityFeedService {
  _CountingActivityFeedService() : super(firestore: FakeFirebaseFirestore());

  var watchHomeCalls = 0;

  @override
  Stream<List<ActivityFeedItem>> watchHomeActivitiesForUser({
    required String userId,
    required Stream<List<String>> followedUserIds,
  }) {
    watchHomeCalls += 1;
    return Stream<List<ActivityFeedItem>>.value(const <ActivityFeedItem>[]);
  }
}

class _HomeHarness {
  const _HomeHarness({required this.auth, required this.comments});

  final AuthProvider auth;
  final _FakeCommentService comments;

  Future<void> dispose() async {
    auth.dispose();
    await comments.dispose();
  }
}

class _FakeCommentService implements CommentService {
  final List<ActivityComment> _comments = <ActivityComment>[];
  final StreamController<List<ActivityComment>> _controller =
      StreamController<List<ActivityComment>>.broadcast();

  @override
  Stream<List<ActivityComment>> watchComments(String activityId) {
    return Stream<List<ActivityComment>>.multi((controller) {
      controller.add(List<ActivityComment>.from(_comments));
      final subscription = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<int> watchCommentCount(String activityId) {
    return Stream<int>.multi((controller) {
      controller.add(_comments.length);
      final subscription = _controller.stream.listen(
        (list) => controller.add(list.length),
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<ActivityComment> addComment({
    required String activityId,
    required String activityOwnerId,
    required String authorId,
    required String authorDisplayName,
    required String text,
    String? authorUsername,
    String? authorPhotoUrl,
  }) async {
    final comment = ActivityComment(
      id: 'c${_comments.length + 1}',
      activityId: activityId,
      authorId: authorId,
      authorDisplayName: authorDisplayName,
      text: text.trim(),
      createdAt: DateTime(2026, 8, 6),
    );
    _comments.insert(0, comment);
    _controller.add(List<ActivityComment>.from(_comments));
    return comment;
  }

  @override
  Future<ActivityComment> replyToComment({
    required String activityId,
    required String activityOwnerId,
    required ActivityComment parentComment,
    required String authorId,
    required String authorDisplayName,
    required String text,
    String? authorUsername,
    String? authorPhotoUrl,
  }) {
    return addComment(
      activityId: activityId,
      activityOwnerId: activityOwnerId,
      authorId: authorId,
      authorDisplayName: authorDisplayName,
      text: text,
      authorUsername: authorUsername,
      authorPhotoUrl: authorPhotoUrl,
    );
  }

  Future<void> dispose() => _controller.close();
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    String uid = 'user-1',
    String username = 'traveller',
    String displayName = 'Traveller',
  }) : _user = _FakeUser(uid),
       _profile = ProfileModel(
         uid: uid,
         email: 't@example.com',
         username: username,
         displayName: displayName,
         createdAt: DateTime(2026, 1, 1),
         updatedAt: DateTime(2026, 1, 1),
         xp: 100,
       );

  final firebase_auth.User _user;
  final ProfileModel _profile;

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

class _FakeUser extends Fake implements firebase_auth.User {
  _FakeUser(this._uid);

  final String _uid;

  @override
  String get uid => _uid;
}
