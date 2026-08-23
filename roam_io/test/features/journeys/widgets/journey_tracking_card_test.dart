import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/journeys/widgets/journey_tracking_card.dart';

void main() {
  testWidgets('shows live journey metrics and ends the journey', (
    tester,
  ) async {
    var ended = false;
    var pauseResumePressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneyTrackingCard(
            distanceMeters: 1250,
            elapsedTime: '12m 4s',
            transportMode: TransportMode.bus,
            isPaused: false,
            onPauseResume: () => pauseResumePressed = true,
            onEndJourney: () => ended = true,
          ),
        ),
      ),
    );

    expect(find.text('Journey in Progress'), findsOneWidget);
    expect(find.text('1.25 km'), findsOneWidget);
    expect(find.text('12m 4s'), findsOneWidget);
    expect(find.text('Bus'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    expect(pauseResumePressed, isTrue);

    await tester.tap(find.text('End Journey'));
    expect(ended, isTrue);
  });

  testWidgets('shows resume state while journey is paused', (tester) async {
    var resumed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneyTrackingCard(
            distanceMeters: 42.9,
            elapsedTime: '9s',
            transportMode: TransportMode.walk,
            isPaused: true,
            onPauseResume: () => resumed = true,
            onEndJourney: () {},
          ),
        ),
      ),
    );

    expect(find.text('Journey Paused'), findsOneWidget);
    expect(find.text('42 m'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);

    await tester.tap(find.text('Resume'));
    expect(resumed, isTrue);
  });
}
