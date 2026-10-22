import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/shared/widgets/app_page_transition.dart';
import 'package:roam_io/theme/app_accessibility.dart';

void main() {
  for (final reduce in [true, false]) {
    for (final kind in ['material', 'cupertino']) {
      testWidgets('$kind route slides=${!reduce} (reduceMotion=$reduce)', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
              child: Builder(
                builder: (context) =>
                    AppAccessibility.wrap(context, child, largerText: false),
              ),
            ),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  kind == 'material'
                      ? MaterialPageRoute<void>(
                          builder: (_) => const Text('next'),
                        )
                      : appHorizontalPageRoute<void>(
                          builder: (_) => const Text('next'),
                        ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final dx = tester.getTopLeft(find.text('next')).dx;
        if (reduce) {
          expect(dx, lessThan(50));
        } else {
          expect(dx, greaterThan(50));
        }
      });
    }
  }
}
