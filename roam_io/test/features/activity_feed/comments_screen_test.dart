/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Widget tests for CommentsScreen composer validation and CommentService
 *   persistence behaviour (success clears input; failure does not fake-add).
 */

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/activity_feed/data/comment_service.dart';
import 'package:roam_io/features/activity_feed/models/activity_comment.dart';
import 'package:roam_io/features/activity_feed/screens/comments_screen.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

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
            activityId: 'stub-amar-sidequest',
            commentService: comments,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

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
            activityId: 'stub-amar-sidequest',
            commentService: comments,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No comments yet'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Great roam!');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Send'));
    await tester.pumpAndSettle();

    expect(comments.addCalls, 1);
    expect(find.text('Great roam!'), findsOneWidget);
    expect(find.textContaining('No comments yet'), findsNothing);
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
            activityId: 'stub-amar-sidequest',
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
    expect(find.text('Could not post comment. Try again.'), findsOneWidget);
    expect(find.textContaining('No comments yet'), findsOneWidget);

    auth.dispose();
    await comments.dispose();
  });
}

class _FakeCommentService implements CommentService {
  _FakeCommentService({this.failNextAdd = false});

  final bool failNextAdd;
  int addCalls = 0;
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
  Future<ActivityComment> addComment({
    required String activityId,
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
