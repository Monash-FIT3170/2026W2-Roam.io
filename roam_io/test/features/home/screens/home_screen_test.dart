/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Widget tests for the Home stub friend activity feed — privacy actions,
 *   live comment counts, and Comment navigation to CommentsScreen.
 */

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/activity_feed/data/comment_service.dart';
import 'package:roam_io/features/activity_feed/models/activity_comment.dart';
import 'package:roam_io/features/activity_feed/screens/activity_detail_screen.dart';
import 'package:roam_io/features/activity_feed/screens/comments_screen.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/home/screens/home_screen.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

void main() {
  testWidgets('shows friend stub cards without Journeys/Quests tabs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final comments = _FakeCommentService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(commentService: comments)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Journeys'), findsNothing);
    expect(find.text('Quests'), findsNothing);
    expect(
      find.text('Your journeys, quests, and activity foundations'),
      findsNothing,
    );

    expect(find.text('Amar'), findsOneWidget);
    expect(find.text('Sidequest with Mates'), findsOneWidget);
    expect(find.text('Sidequest Progress'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Kudos'), findsWidgets);
    expect(find.text('0 comments'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Nathan'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Nathan'), findsOneWidget);
    expect(find.text('Journey to Monash'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('jacob'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('jacob'), findsOneWidget);
    expect(find.text('Exploring Melbourne CBD'), findsOneWidget);
    expect(find.text('Map preview'), findsWidgets);

    await comments.dispose();
  });

  testWidgets('overflow opens activity detail without engagement controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final comments = _FakeCommentService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(commentService: comments)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byType(ActivityDetailScreen), findsOneWidget);
    expect(find.text('Sidequest with Mates'), findsOneWidget);
    expect(find.text('Journey route map'), findsOneWidget);
    expect(find.text('Kudos'), findsNothing);
    expect(find.text('0 comments'), findsNothing);
    expect(find.text('Share'), findsNothing);

    await comments.dispose();
  });

  testWidgets('Comment opens Comments page and count updates after post', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final auth = AuthProvider(authRepository: _FakeAuthRepository());
    await auth.refreshCurrentUser();
    final comments = _FakeCommentService();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: Scaffold(body: HomeScreen(commentService: comments)),
        ),
      ),
    );
    await tester.pumpAndSettle();

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

    auth.dispose();
    await comments.dispose();
  });
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
