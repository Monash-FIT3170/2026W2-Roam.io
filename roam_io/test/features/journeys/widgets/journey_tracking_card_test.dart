import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/journeys/widgets/journey_tracking_card.dart';

void main() {
  testWidgets('shows live journey metrics and ends the journey', (
    tester,
  ) async {
    var ended = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneyTrackingCard(
            distanceMeters: 1250,
            elapsedTime: '12m 4s',
            transportMode: TransportMode.bus,
            onEndJourney: () => ended = true,
          ),
        ),
      ),
    );

    expect(find.text('Journey in Progress'), findsOneWidget);
    expect(find.text('1.25 km'), findsOneWidget);
    expect(find.text('12m 4s'), findsOneWidget);
    expect(find.text('Bus'), findsOneWidget);

    await tester.tap(find.text('End Journey'));
    expect(ended, isTrue);
  });
}
