/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Widget tests for main shell tab switching, real Home feed, and
 *   notification action toast feedback.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/activity_feed/data/activity_feed_service.dart';
import 'package:roam_io/features/activity_feed/data/comment_service.dart';
import 'package:roam_io/features/activity_feed/models/activity_comment.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/journeys/data/journey_controller.dart';
import 'package:roam_io/features/map/data/map_page.dart';
import 'package:roam_io/features/navigation/screens/main_shell_screen.dart';
import 'package:roam_io/notifications/notification.dart';
import 'package:roam_io/features/social/data/follow_request_service.dart';
import 'package:roam_io/features/social/data/follow_service.dart';
import 'package:roam_io/features/social/data/friendship_service.dart';
import 'package:roam_io/features/social/data/social_notification_coordinator.dart';
import 'package:roam_io/features/social/data/social_notification_service.dart';
import 'package:roam_io/features/social/domain/friend_request.dart';
import 'package:roam_io/shared/widgets/app_toast.dart';

import '../../../support/journey_test_harness.dart';

void main() {
  // Map tab loads Firebase-backed widgets during the first pump.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  testWidgets('starts on map tab and opens the new top-level destinations', (
    tester,
  ) async {
    // Arrange: provide an authenticated user and profile.
    final repository = JourneyTestAuthRepository();
    final comments = _FakeCommentService();
    final firestore = FakeFirebaseFirestore();

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(authRepository: repository),
            ),
            ChangeNotifierProvider<JourneyController>(
              create: (_) => JourneyTestController(),
            ),
          ],
          child: MainShellScreen(
            // Android platform permissions are not available in widget tests.
            requestNotificationPermission: false,
            commentService: comments,
            activityFeedService: ActivityFeedService(firestore: firestore),
            followService: FollowService(firestore: firestore),
            friendshipService: FriendshipService(firestore: firestore),
            followRequestService: FollowRequestService(firestore: firestore),
            socialNotificationCoordinator: SocialNotificationCoordinator(
              friendshipService: FriendshipService(firestore: firestore),
              notificationService: SocialNotificationService(
                firestore: firestore,
              ),
            ),
          ),
        ),
      ),
    );

    // Allow the shell and Firebase-backed tab widgets to initialise.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(MapPage), findsOneWidget);
    expect(find.byTooltip('Test notification'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('HOME'));
    await _pumpShellFrame(tester);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('No activities yet'), findsOneWidget);
    expect(find.text('Journeys'), findsNothing);
    expect(find.text('Quests'), findsNothing);

    await tester.tap(find.text('SOCIAL'));
    await _pumpShellFrame(tester);
    expect(find.text('Follow and community tools'), findsOneWidget);

    await tester.tap(find.text('YOU'));
    await _pumpShellFrame(tester);
    expect(find.text('Most Visited Location'), findsOneWidget);

    await tester.tap(find.text('SETTINGS'));
    await _pumpShellFrame(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);

    await comments.dispose();
  });

  for (final scenario in [
    (
      action: const NotificationAction(
        type: NotificationActionType.accept,
        label: 'Accept',
      ),
      expectedMessage: 'Friend request accepted.',
    ),
    (
      action: const NotificationAction(
        type: NotificationActionType.decline,
        label: 'Decline',
      ),
      expectedMessage: 'Friend request declined.',
    ),
  ]) {
    testWidgets(
      '${scenario.action.label.toLowerCase()} notification action shows app toast',
      (tester) async {
        final repository = JourneyTestAuthRepository();
        final comments = _FakeCommentService();
        final firestore = FakeFirebaseFirestore();
        final friendshipService = FriendshipService(firestore: firestore);
        final currentUserId = repository.currentUser!.uid;
        final pairKey = FriendshipService.pairKeyFor(
          'sender-user',
          currentUserId,
        );
        final now = DateTime(2026, 8, 7);
        await firestore
            .collection(FriendshipService.friendRequestsCollection)
            .doc(pairKey)
            .set(
              FriendRequest(
                id: pairKey,
                pairKey: pairKey,
                senderId: 'sender-user',
                recipientId: currentUserId,
                status: FriendRequestStatus.pending,
                createdAt: now,
                updatedAt: now,
              ).toMap(),
            );

        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>(
                  create: (_) => AuthProvider(authRepository: repository),
                ),
                ChangeNotifierProvider<JourneyController>(
                  create: (_) => JourneyTestController(),
                ),
              ],
              child: MainShellScreen(
                requestNotificationPermission: false,
                commentService: comments,
                activityFeedService: ActivityFeedService(firestore: firestore),
                followService: FollowService(firestore: firestore),
                friendshipService: friendshipService,
                followRequestService: FollowRequestService(
                  firestore: firestore,
                ),
                socialNotificationCoordinator: SocialNotificationCoordinator(
                  friendshipService: FriendshipService(firestore: firestore),
                  notificationService: SocialNotificationService(
                    firestore: firestore,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        NotificationService.instance.handleAction(
          notification: AppNotification(
            id: pairKey,
            type: NotificationType.friendRequest,
            title: 'New Friend Request',
            body: 'Alex sent you a friend request.',
            timestamp: DateTime(2026, 8, 5),
            data: {'friendRequestId': pairKey, 'senderId': 'sender-user'},
          ),
          action: scenario.action,
        );

        await _pumpShellFrame(tester);

        final toast = tester.widget<AppToastBanner>(
          find.byType(AppToastBanner),
        );
        expect(toast.icon, Icons.check_circle_rounded);
        expect(find.text(scenario.expectedMessage), findsOneWidget);

        await comments.dispose();
      },
    );
  }
}

Future<void> _pumpShellFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// In-memory comments so shell tests never touch Firestore.
class _FakeCommentService implements CommentService {
  @override
  Stream<List<ActivityComment>> watchComments(String activityId) {
    return Stream<List<ActivityComment>>.value(const <ActivityComment>[]);
  }

  @override
  Stream<int> watchCommentCount(String activityId) {
    return Stream<int>.value(0);
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
    throw UnsupportedError('Shell tests do not post comments.');
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
    throw UnsupportedError('Shell tests do not post replies.');
  }

  Future<void> dispose() async {}
}
