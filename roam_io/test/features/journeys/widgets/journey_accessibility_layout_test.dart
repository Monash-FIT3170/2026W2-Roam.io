/*
 * Description:
 *   Larger Text and High Contrast layout checks for the journey start/end
 *   sheets and the live tracking card.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/domain/nearby_place.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/journeys/domain/journey.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/widgets/custom_location_details_sheet.dart';
import 'package:roam_io/features/journeys/widgets/end_journey_sheet.dart';
import 'package:roam_io/features/journeys/widgets/past_journey_summary_sheet.dart';
import 'package:roam_io/features/journeys/widgets/journey_tracking_card.dart';
import 'package:roam_io/features/journeys/widgets/start_journey_sheet.dart';

import '../../../support/accessibility_harness.dart';

const _position = LatLng(-37.81, 144.96);

void main() {
  testAccessibleLayouts('tracking card lays out', (tester, theme, scale) async {
    await pumpAccessible(
      tester,
      Scaffold(
        body: JourneyTrackingCard(
          distanceMeters: 12500,
          elapsedTime: '1h 12m 4s',
          transportMode: TransportMode.bus,
          onEndJourney: () {},
        ),
      ),
      theme: theme,
      textScale: scale,
      largerText: true,
    );
  });

  testAccessibleLayouts('start sheet lays out', (tester, theme, scale) async {
    await pumpAccessible(
      tester,
      const Scaffold(
        body: StartJourneySheet(
          currentPosition: _position,
          availableTransportModes: {
            TransportMode.walk,
            TransportMode.drive,
            TransportMode.bus,
            TransportMode.train,
          },
        ),
      ),
      theme: theme,
      textScale: scale,
      largerText: true,
    );
  });

  testAccessibleLayouts('end sheet lays out', (tester, theme, scale) async {
    await pumpAccessible(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => EndJourneySheet.show(
              context: context,
              currentPosition: _position,
              distanceMeters: 1234,
              duration: const Duration(hours: 1, minutes: 5),
              transportMode: TransportMode.train,
              nearbyPlaces: const [
                NearbyPlace(
                  placeId: 'station',
                  name: 'Central Station Platform Concourse',
                  address: '1 Station Street, Melbourne',
                  latLng: LatLng(-37.811, 144.961),
                  distanceMeters: 8,
                ),
              ],
            ),
            child: const Text('Open'),
          ),
        ),
      ),
      theme: theme,
      textScale: scale,
      largerText: true,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  });

  testAccessibleLayouts('past journey sheet lays out', (
    tester,
    theme,
    scale,
  ) async {
    final journey = Journey(
      id: 'journey-1',
      userId: 'user-1',
      startTime: DateTime(2026, 7, 30, 11, 26),
      endTime: DateTime(2026, 7, 30, 11, 56),
      startLocation: const JourneyLocation(
        latLng: LatLng(-37.8136, 144.9631),
        displayName: 'Creek entrance to the northern boardwalk',
      ),
      endLocation: const JourneyLocation(
        latLng: LatLng(-37.8100, 144.9700),
        displayName: 'Park lookout over the creek',
        description: 'A good view over the creek.',
      ),
      transportMode: TransportMode.walk,
      encodedRoute: '',
      distanceMeters: 3200,
      durationSeconds: 1800,
      xpEarned: 182,
      journeyXpEarned: 32,
      tilesUnlocked: 3,
      tileXpEarned: 150,
    );
    await pumpAccessible(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => PastJourneySummarySheet.show(
              context: context,
              journey: journey,
            ),
            child: const Text('Open journey'),
          ),
        ),
      ),
      theme: theme,
      textScale: scale,
      largerText: true,
    );
    await tester.tap(find.text('Open journey'));
    await tester.pumpAndSettle();
  });

  testAccessibleLayouts('custom location sheet lays out', (
    tester,
    theme,
    scale,
  ) async {
    await pumpAccessible(
      tester,
      Scaffold(
        body: CustomLocationDetailsSheet(
          location: const JourneyLocation(
            latLng: LatLng(-37.8136, 144.9631),
            displayName: 'Current Location',
            customName: 'Creek lookout',
            description: 'A quiet place near the trail.',
          ),
          distanceMeters: 17,
          userId: 'user-1',
          onSave: (_) async {},
        ),
      ),
      theme: theme,
      textScale: scale,
      largerText: true,
    );
  });
}
