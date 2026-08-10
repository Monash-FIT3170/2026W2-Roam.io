/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Widget tests for CommentsScreen composer validation, empty state, and
 *   CommentService persistence (success clears input; failure does not
 *   fake-add). Notifications for comments are deferred.
 */

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/activity_feed/data/comment_like_service.dart';
import 'package:roam_io/features/activity_feed/data/comment_service.dart';
import 'package:roam_io/features/activity_feed/models/activity_comment.dart';
import 'package:roam_io/features/activity_feed/screens/comments_screen.dart';
import 'package:roam_io/features/activity_feed/widgets/comment_composer.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/theme/app_surfaces.dart';

void main() {
  testWidgets('empty and whitespace comments cannot submit', (tester) async {
    final comments = _FakeCommentService();
    final auth = AuthProvider(authRepository: _FakeAuthRepository());
    await auth.refreshCurrentUser();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: CommentsScreen(
            activityId: 'activity-1',
            activityOwnerId: 'owner-1',
            commentService: comments,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No comments yet'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Send'), findsOneWidget);
    final sendFinder = find.widgetWithText(TextButton, 'Send');
    expect(tester.widget<TextButton>(sendFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(tester.widget<TextButton>(sendFinder).onPressed, isNull);
    expect(comments.addCalls, 0);

    auth.dispose();
    await comments.dispose();
  });

  testWidgets('valid comment persists, appears, and clears input', (
    tester,
  ) async {
    final comments = _FakeCommentService();
    final auth = AuthProvider(authRepository: _FakeAuthRepository());
    await auth.refreshCurrentUser();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: CommentsScreen(
            activityId: 'activity-1',
            activityOwnerId: 'owner-1',
            commentService: comments,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No comments yet'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Great roam!');
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Send'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Send'));
    await tester.pumpAndSettle();

    expect(comments.addCalls, 1);
    expect(find.text('Great roam!'), findsOneWidget);
    expect(find.text('No comments yet'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );

    auth.dispose();
    await comments.dispose();
  });

  testWidgets('persistence failure does not add comment or clear input', (
    tester,
  ) async {
    final comments = _FakeCommentService(failNextAdd: true);
    final auth = AuthProvider(authRepository: _FakeAuthRepository());
    await auth.refreshCurrentUser();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: CommentsScreen(
            activityId: 'activity-1',
            activityOwnerId: 'owner-1',
            commentService: comments,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Should fail');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Send'));
    await tester.pumpAndSettle();

    expect(find.text('Should fail'), findsOneWidget);
    // Inline error + AppToast both surface the same copy.
    expect(find.text('Could not post comment. Try again.'), findsNWidgets(2));
    expect(find.text('No comments yet'), findsOneWidget);

    auth.dispose();
    await comments.dispose();
  });

  testWidgets('composer tray ColoredBox uses AppSurfaces.card fill', (
    tester,
  ) async {
    final comments = _FakeCommentService();
    final auth = AuthProvider(authRepository: _FakeAuthRepository());
    await auth.refreshCurrentUser();

    late Color expectedTray;
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              expectedTray = AppSurfaces.card(context);
              return CommentsScreen(
                activityId: 'activity-1',
                activityOwnerId: 'owner-1',
                commentService: comments,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tray = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(CommentComposer),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(tray.color, expectedTray);

    auth.dispose();
    await comments.dispose();
  });

  testWidgets('liked comment action shows compact thumbs-up active state', (
    tester,
  ) async {
    final comments = _FakeCommentService()
      ..seedComment(
        ActivityComment(
          id: 'comment-1',
          activityId: 'activity-1',
          authorId: 'author-1',
          authorDisplayName: 'Author',
          text: 'Nice route',
          createdAt: DateTime(2026, 8, 10, 12),
        ),
      );
    final likes = _FakeCommentLikeService();
    final auth = AuthProvider(authRepository: _FakeAuthRepository());
    await auth.refreshCurrentUser();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: CommentsScreen(
            activityId: 'activity-1',
            activityOwnerId: 'owner-1',
            commentService: comments,
            commentLikeService: likes,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Like'), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_alt_rounded), findsNothing);

    await tester.tap(find.text('Like'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);
    expect(find.text('Liked · 1'), findsOneWidget);

    await tester.tap(find.text('Liked · 1'));
    await tester.pumpAndSettle();

    expect(find.text('Like'), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_alt_rounded), findsNothing);

    auth.dispose();
    await comments.dispose();
    await likes.dispose();
  });
}

class _FakeCommentService implements CommentService {
  _FakeCommentService({this.failNextAdd = false});

  final bool failNextAdd;
  int addCalls = 0;
  final List<ActivityComment> _comments = <ActivityComment>[];
  final StreamController<List<ActivityComment>> _controller =
      StreamController<List<ActivityComment>>.broadcast();

  void seedComment(ActivityComment comment) {
    _comments.add(comment);
  }

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
    addCalls += 1;
    if (failNextAdd) {
      throw Exception('persist failed');
    }
    final comment = ActivityComment(
      id: 'c-$addCalls',
      activityId: activityId,
      authorId: authorId,
      authorDisplayName: authorDisplayName,
      authorUsername: authorUsername,
      authorPhotoUrl: authorPhotoUrl,
      text: text.trim(),
      createdAt: DateTime(2026, 8, 6, 12),
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
  }) async {
    final comment = await addComment(
      activityId: activityId,
      activityOwnerId: activityOwnerId,
      authorId: authorId,
      authorDisplayName: authorDisplayName,
      text: text,
      authorUsername: authorUsername,
      authorPhotoUrl: authorPhotoUrl,
    );
    return ActivityComment(
      id: comment.id,
      activityId: activityId,
      authorId: authorId,
      authorDisplayName: authorDisplayName,
      authorUsername: authorUsername,
      authorPhotoUrl: authorPhotoUrl,
      text: comment.text,
      createdAt: comment.createdAt,
      parentCommentId: parentComment.id,
      replyToUserId: parentComment.authorId,
      replyToDisplayName: parentComment.authorDisplayName,
    );
  }

  Future<void> dispose() => _controller.close();
}

class _FakeCommentLikeService implements CommentLikeService {
  final Set<String> _liked = <String>{};
  final StreamController<void> _controller = StreamController<void>.broadcast();

  @override
  Stream<bool> watchIsLiked({
    required String activityId,
    required String commentId,
    required String userId,
  }) {
    return Stream<bool>.multi((controller) {
      controller.add(_liked.contains(_key(activityId, commentId, userId)));
      final subscription = _controller.stream.listen((_) {
        controller.add(_liked.contains(_key(activityId, commentId, userId)));
      });
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<int> watchLikeCount({
    required String activityId,
    required String commentId,
  }) {
    return Stream<int>.multi((controller) {
      controller.add(_count(activityId, commentId));
      final subscription = _controller.stream.listen((_) {
        controller.add(_count(activityId, commentId));
      });
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> toggleLike({
    required String activityId,
    required String commentId,
    required String commentAuthorId,
    required String userId,
  }) async {
    final key = _key(activityId, commentId, userId);
    if (!_liked.add(key)) {
      _liked.remove(key);
    }
    _controller.add(null);
  }

  int _count(String activityId, String commentId) {
    final prefix = '$activityId/$commentId/';
    return _liked.where((key) => key.startsWith(prefix)).length;
  }

  String _key(String activityId, String commentId, String userId) {
    return '$activityId/$commentId/$userId';
  }

  Future<void> dispose() => _controller.close();
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository()
    : _user = _FakeUser(),
      _profile = ProfileModel(
        uid: 'user-1',
        email: 't@example.com',
        username: 'traveller',
        displayName: 'Traveller',
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
  @override
  String get uid => 'user-1';
}
