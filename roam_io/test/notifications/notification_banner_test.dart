/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Widget tests for the reusable in-app notification banner, including
 *   green app styling, content, actions, icons, dismissal and tap callbacks.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/notifications/notification.dart';
import 'package:roam_io/theme/app_colours.dart';
import 'package:roam_io/theme/app_theme.dart';

void main() {
  /// Creates a standard friend-request notification used across tests.
  AppNotification createFriendRequest() {
    return AppNotification(
      id: 'friend-request-1',
      type: NotificationType.friendRequest,
      title: 'New Friend Request',
      body: 'Alex sent you a friend request.',
      timestamp: DateTime(2026, 8, 1),
      actions: const [
        NotificationAction(
          type: NotificationActionType.accept,
          label: 'Accept',
        ),
        NotificationAction(
          type: NotificationActionType.decline,
          label: 'Decline',
        ),
      ],
    );
  }

  /// Wraps [NotificationBanner] in the Material widgets required for
  /// rendering, theming and interaction during widget tests.
  Widget buildTestWidget({
    required AppNotification notification,
    VoidCallback? onTap,
    VoidCallback? onDismiss,
    ValueChanged<NotificationAction>? onActionSelected,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: NotificationBanner(
          notification: notification,
          onTap: onTap,
          onDismiss: onDismiss,
          onActionSelected: onActionSelected,
        ),
      ),
    );
  }

  testWidgets('displays title and body', (tester) async {
    // Arrange and render.
    await tester.pumpWidget(
      buildTestWidget(notification: createFriendRequest()),
    );

    // Assert: the notification content should be visible.
    expect(find.text('New Friend Request'), findsOneWidget);
    expect(find.text('Alex sent you a friend request.'), findsOneWidget);
  });

  testWidgets('displays configured notification actions', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(notification: createFriendRequest()),
    );

    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });

  testWidgets('invokes dismiss callback', (tester) async {
    var dismissed = false;

    await tester.pumpWidget(
      buildTestWidget(
        notification: createFriendRequest(),
        onDismiss: () {
          dismissed = true;
        },
      ),
    );

    // Act: tap the close button using its accessibility tooltip.
    await tester.tap(find.byTooltip('Dismiss notification'));
    await tester.pump();

    expect(dismissed, isTrue);
  });

  testWidgets('returns selected action', (tester) async {
    NotificationAction? selectedAction;

    await tester.pumpWidget(
      buildTestWidget(
        notification: createFriendRequest(),
        onActionSelected: (action) {
          selectedAction = action;
        },
      ),
    );

    // Act: select the primary friend-request action.
    await tester.tap(find.text('Accept'));
    await tester.pump();

    expect(selectedAction, isNotNull);
    expect(selectedAction!.type, NotificationActionType.accept);
    expect(selectedAction!.label, 'Accept');
  });

  testWidgets('invokes notification tap callback', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      buildTestWidget(
        notification: createFriendRequest(),
        onTap: () {
          tapped = true;
        },
      ),
    );

    // Tapping the title also taps the banner's InkWell.
    await tester.tap(find.text('New Friend Request'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('uses friend request icon', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(notification: createFriendRequest()),
    );

    expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
  });

  testWidgets('uses app green treatment for icon and primary action', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestWidget(notification: createFriendRequest()),
    );

    final iconContainer = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.person_add_alt_1),
            matching: find.byType(Container),
          )
          .first,
    );
    final iconDecoration = iconContainer.decoration! as BoxDecoration;

    expect(iconDecoration.color, AppColors.sage);

    final acceptButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Accept'),
    );
    final buttonStates = <WidgetState>{};

    expect(
      acceptButton.style?.backgroundColor?.resolve(buttonStates),
      AppColors.sage,
    );
    expect(
      acceptButton.style?.foregroundColor?.resolve(buttonStates),
      Colors.white,
    );
  });

  testWidgets('does not show action buttons when list is empty', (
    tester,
  ) async {
    final notification = AppNotification(
      id: 'kudos-1',
      type: NotificationType.kudos,
      title: 'Glaze Received',
      body: 'Alex gave you Glaze.',
      timestamp: DateTime(2026, 8, 1),
    );

    await tester.pumpWidget(buildTestWidget(notification: notification));

    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('uses distinct activity interaction icons', (tester) async {
    final cases = <NotificationType, IconData>{
      NotificationType.kudos: Icons.thumb_up_alt_outlined,
      NotificationType.comment: Icons.chat_bubble_outline,
      NotificationType.commentReply: Icons.reply_rounded,
      NotificationType.commentLike: Icons.thumb_up_alt_outlined,
      NotificationType.follow: Icons.person_add_alt_1,
      NotificationType.followRequest: Icons.person_add_alt_1,
      NotificationType.followRequestAccepted: Icons.people_outline,
      NotificationType.error: Icons.error_outline,
      NotificationType.activity: Icons.directions_walk,
    };

    for (final entry in cases.entries) {
      await tester.pumpWidget(
        buildTestWidget(
          notification: AppNotification(
            id: entry.key.name,
            type: entry.key,
            title: 'Title',
            body: 'Body',
            timestamp: DateTime(2026, 8, 10),
          ),
        ),
      );

      expect(find.byIcon(entry.value), findsOneWidget);
    }
  });
}
