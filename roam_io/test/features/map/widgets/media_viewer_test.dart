/*
 * Author: Jacob De La Paz
 * Last Modified: 18/05/2026
 * Description:
 *   Widget tests for MediaViewer image display, initial page selection, and
 *   route presentation coverage added for ART-68 CI coverage enforcement.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/widgets/media_viewer.dart';

void main() {
  testWidgets('shows image media with a page counter', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaViewer(
          mediaUrls: [
            'https://example.com/first.jpg',
            'https://example.com/second.png',
          ],
        ),
      ),
    );

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('starts from the supplied initial image index', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaViewer(
          mediaUrls: [
            'https://example.com/first.jpg',
            'https://example.com/second.png',
          ],
          initialIndex: 1,
        ),
      ),
    );

    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('show pushes the full-screen viewer route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => MediaViewer.show(
                  context: context,
                  mediaUrls: const ['https://example.com/photo.jpg'],
                ),
                child: const Text('Open media'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open media'));
    await tester.pumpAndSettle();

    expect(find.byType(MediaViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}
