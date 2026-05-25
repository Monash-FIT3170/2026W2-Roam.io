/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 18/05/2026
 * Description:
 *   Widget tests for AppToast message, subtitle, success, error, and messenger
 *   display paths added for ART-68 coverage enforcement.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/shared/widgets/app_toast.dart';

void main() {
  testWidgets('show displays a message with the default icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => AppToast.show(context, 'Saved changes'),
                child: const Text('Show toast'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show toast'));
    await tester.pump();

    expect(find.text('Saved changes'), findsOneWidget);
    expect(find.byIcon(Icons.info_rounded), findsOneWidget);
  });

  testWidgets('success displays message and subtitle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => AppToast.success(
                  context,
                  'Visit logged',
                  subtitle: '+50 XP',
                ),
                child: const Text('Show success'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show success'));
    await tester.pump();

    expect(find.text('Visit logged'), findsOneWidget);
    expect(find.text('+50 XP'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('error displays an error icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => AppToast.error(context, 'Could not save'),
                child: const Text('Show error'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show error'));
    await tester.pump();

    expect(find.text('Could not save'), findsOneWidget);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
  });

  testWidgets('successForMessenger displays via an existing messenger', (
    tester,
  ) async {
    late ScaffoldMessengerState messenger;

    await tester.pumpWidget(
      MaterialApp(
        home: ScaffoldMessenger(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                messenger = ScaffoldMessenger.of(context);
                return TextButton(
                  onPressed: () => AppToast.successForMessenger(
                    messenger,
                    'Saved from modal',
                    subtitle: '+50 XP',
                  ),
                  child: const Text('Show via messenger'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show via messenger'));
    await tester.pump();

    expect(find.text('Saved from modal'), findsOneWidget);
    expect(find.text('+50 XP'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
