import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/journeys/widgets/journey_summary_sheet.dart';

void main() {
  testWidgets('returns edited activity title when saving', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    JourneySummaryResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await JourneySummarySheet.show(
                  context: context,
                  startLocation: _startLocation,
                  endLocation: _endLocation,
                  transportMode: TransportMode.walk,
                  distanceMeters: 3200,
                  duration: const Duration(minutes: 30),
                  routePoints: _routePoints,
                  startTime: DateTime(2026, 8, 10, 7),
                  xpEarned: 182,
                  tilesUnlocked: 3,
                  onUpdateStartName: (_) {},
                  onUpdateEndName: (_) {},
                );
              },
              child: const Text('Open summary'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open summary'));
    await tester.pumpAndSettle();

    expect(find.text('Journey Complete!'), findsOneWidget);
    expect(find.text('Journey Complete'), findsNothing);
    final heading = tester.widget<Text>(find.text('Journey Complete!'));
    expect(heading.maxLines, 1);
    expect(heading.softWrap, isFalse);
    expect(find.text('Journey title'), findsNothing);
    expect(find.text('+182 XP'), findsOneWidget);
    expect(find.textContaining('XP total'), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.text('Morning Journey'), findsOneWidget);
    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
    expect(find.text('Add media coming soon'), findsOneWidget);
    expect(find.text('Locations Visited'), findsNothing);
    expect(find.text('Journey Details'), findsNothing);
    expect(find.text('From'), findsNothing);
    expect(find.text('To'), findsNothing);
    expect(find.text('Save Activity'), findsOneWidget);
    expect(find.text('Save Journey'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Creek Loop');
    await tester.scrollUntilVisible(
      find.text('Save Activity'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save Activity'));
    await tester.pumpAndSettle();

    expect(result?.action, JourneySummaryAction.save);
    expect(result?.title, 'Creek Loop');
  });

  testWidgets('returns discard action with current title', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    JourneySummaryResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await JourneySummarySheet.show(
                  context: context,
                  startLocation: _startLocation,
                  endLocation: _endLocation,
                  transportMode: TransportMode.walk,
                  distanceMeters: 3200,
                  duration: const Duration(minutes: 30),
                  routePoints: _routePoints,
                  startTime: DateTime(2026, 8, 10, 13),
                  xpEarned: 182,
                  tilesUnlocked: 3,
                  onUpdateStartName: (_) {},
                  onUpdateEndName: (_) {},
                );
              },
              child: const Text('Open summary'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open summary'));
    await tester.pumpAndSettle();

    expect(find.text('Afternoon Journey'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Discard'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(result?.action, JourneySummaryAction.discard);
    expect(result?.title, 'Afternoon Journey');
  });
}

const _startLocation = JourneyLocation(
  latLng: LatLng(-37.8136, 144.9631),
  displayName: 'Creek entrance',
);

const _endLocation = JourneyLocation(
  latLng: LatLng(-37.8115, 144.9631),
  displayName: 'Park lookout',
);

const _routePoints = [
  LatLng(-37.8136, 144.9631),
  LatLng(-37.8125, 144.9631),
  LatLng(-37.8115, 144.9631),
];
