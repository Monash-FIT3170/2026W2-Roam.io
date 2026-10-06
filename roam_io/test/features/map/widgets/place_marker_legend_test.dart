import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/widgets/place_marker_legend.dart';
import 'package:roam_io/features/map/widgets/place_visit_status_card.dart';
import 'package:roam_io/features/map/domain/place_visit_feedback.dart';
import 'package:roam_io/theme/app_theme.dart';

void main() {
  testWidgets(
    'map guide opens from its labelled control and explains all states',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PlaceMarkerLegendButton())),
      );
      await tester.tap(find.byTooltip('Location marker guide'));
      await tester.pumpAndSettle();
      expect(find.text('Location markers'), findsOneWidget);
      expect(find.text('Not visited'), findsOneWidget);
      expect(find.text('In range'), findsOneWidget);
      expect(find.text('Visited'), findsOneWidget);
      expect(find.textContaining('100m'), findsOneWidget);
      expect(find.textContaining('Train, tram and bus'), findsOneWidget);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'guide and status cards fit narrow screens with large text (${dark ? 'dark' : 'light'})',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          Widget app(Widget child) => MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(body: child),
            ),
          );
          await tester.pumpWidget(app(const PlaceMarkerLegend()));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(find.text('Visited'), 150);
          expect(find.text('Visited'), findsOneWidget);
          for (final distance in [null, 50.0, 100.1]) {
            for (final visited in [false, true]) {
              await tester.pumpWidget(
                app(
                  SingleChildScrollView(
                    child: PlaceVisitStatusCard(
                      feedback: PlaceVisitFeedback(
                        isVisited: visited,
                        distanceMetres: distance,
                      ),
                      isCheckingLocation: false,
                      onRefresh: () {},
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await expectLater(tester, meetsGuideline(textContrastGuideline));
              expect(
                find.text(visited ? 'Visited' : 'Not visited'),
                findsOneWidget,
              );
            }
          }
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
