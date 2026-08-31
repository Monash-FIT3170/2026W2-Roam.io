import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/shared/widgets/app_page_transition.dart';

void main() {
  test('horizontal page route uses a Cupertino page route', () {
    final route = appHorizontalPageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
    );

    expect(route, isA<CupertinoPageRoute<void>>());
    expect(route.fullscreenDialog, isFalse);
  });

  testWidgets('horizontal page route pushes and returns a result', (
    tester,
  ) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<String>(
                appHorizontalPageRoute<String>(
                  settings: const RouteSettings(name: 'test-horizontal-route'),
                  builder: (_) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).pop('done'),
                      child: const Text('Complete route'),
                    ),
                  ),
                ),
              );
            },
            child: const Text('Open route'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();
    expect(find.text('Complete route'), findsOneWidget);

    await tester.tap(find.text('Complete route'));
    await tester.pumpAndSettle();

    expect(result, 'done');
  });
}
