/*
 * Author: Sam Sutherland
 * Last Modified: 04/08/2026
 * Description:
 *   Widget tests for displaying, dismissing and interacting with
 *   notifications through NotificationOverlay.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/notifications/notification.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget() {
    return const MaterialApp(
      home: NotificationOverlay(
        child: Scaffold(body: Text('Application content')),
      ),
    );
  }

  AppNotification createNotification({
    Duration duration = const Duration(seconds: 4),
  }) {
    return AppNotification(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: NotificationType.friendRequest,
      title: 'New Friend Request',
      body: 'Alex sent you a friend request.',
      timestamp: DateTime(2026, 8, 4),
      displayDuration: duration,
      actions: const [
        NotificationAction(
          type: NotificationActionType.accept,
          label: 'Accept',
        ),
      ],
    );
  }

  testWidgets('shows application content without a notification', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());

    expect(find.text('Application content'), findsOneWidget);
    expect(find.byType(NotificationBanner), findsNothing);
  });

  testWidgets('displays notification received from service', (tester) async {
    await tester.pumpWidget(buildTestWidget());

    final notification = createNotification();

    await NotificationService.instance.show(notification);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NotificationBanner), findsOneWidget);
    expect(find.text('New Friend Request'), findsOneWidget);
    expect(find.text('Alex sent you a friend request.'), findsOneWidget);
  });

  testWidgets('dismisses notification using close button', (tester) async {
    await tester.pumpWidget(buildTestWidget());

    await NotificationService.instance.show(createNotification());

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Dismiss notification'));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NotificationBanner), findsNothing);
  });

  testWidgets('automatically dismisses notification after duration', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());

    await NotificationService.instance.show(
      createNotification(duration: const Duration(seconds: 1)),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NotificationBanner), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NotificationBanner), findsNothing);
  });

  testWidgets('emits action event when action is selected', (tester) async {
    await tester.pumpWidget(buildTestWidget());

    final eventFuture = NotificationService.instance.actionEvents.first;

    await NotificationService.instance.show(createNotification());

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Accept'));
    await tester.pump();

    final event = await eventFuture;

    expect(event.action.type, NotificationActionType.accept);
    expect(event.notification.type, NotificationType.friendRequest);
  });

  testWidgets('dismisses notification when body is tapped', (tester) async {
    await tester.pumpWidget(buildTestWidget());

    await NotificationService.instance.show(createNotification());

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('New Friend Request'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NotificationBanner), findsNothing);
  });

  testWidgets('new notification replaces previous notification', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());

    final first = createNotification();

    final second = AppNotification(
      id: 'second-notification',
      type: NotificationType.comment,
      title: 'New Comment',
      body: 'Jordan commented on your activity.',
      timestamp: DateTime(2026, 8, 4),
    );

    await NotificationService.instance.show(first);
    await tester.pump();

    await NotificationService.instance.show(second);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('New Comment'), findsOneWidget);
    expect(find.text('New Friend Request'), findsNothing);
  });
}
