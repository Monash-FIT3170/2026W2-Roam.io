import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/domain/journey.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/journeys/widgets/past_journey_summary_sheet.dart';

void main() {
  testWidgets('shows a read-only summary for a past journey', (tester) async {
    final journey = Journey(
      id: 'journey-1',
      userId: 'user-1',
      startTime: DateTime(2026, 7, 30, 11, 26),
      endTime: DateTime(2026, 7, 30, 11, 56),
      startLocation: const JourneyLocation(
        latLng: LatLng(-37.8136, 144.9631),
        displayName: 'Creek entrance',
      ),
      endLocation: const JourneyLocation(
        latLng: LatLng(-37.8100, 144.9700),
        displayName: 'Park lookout',
        description: 'A good view over the creek.',
      ),
      transportMode: TransportMode.walk,
      encodedRoute: '',
      distanceMeters: 3200,
      durationSeconds: 1800,
      xpEarned: 32,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => PastJourneySummarySheet.show(
                context: context,
                journey: journey,
              ),
              child: const Text('Open journey'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open journey'));
    await tester.pumpAndSettle();

    expect(find.text('Creek entrance to Park lookout'), findsOneWidget);
    expect(find.text('Journey Overview'), findsNothing);
    expect(find.text('3.2 km'), findsOneWidget);
    expect(find.text('30 mins'), findsOneWidget);
    expect(find.text('Walk'), findsOneWidget);
    expect(find.text('32 XP earned'), findsOneWidget);
    expect(find.text('Creek entrance'), findsOneWidget);
    expect(find.text('Park lookout'), findsAtLeastNWidgets(1));
    expect(find.text('A good view over the creek.'), findsNothing);
    expect(find.text('Save Journey'), findsNothing);
    expect(find.text('Discard'), findsNothing);
  });
}
