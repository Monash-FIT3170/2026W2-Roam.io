/*
 * Author: Amarprit Singh
 * Last Updated: 29 August 2026
 * Description:
 *   Sharing used to look the journey up by the activity's own id, which never
 *   matches a journey document, so every shared card fell back to placeholder
 *   numbers. These cover which source each viewer's card is built from.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/activity_feed/data/activity_map_image.dart';
import 'package:roam_io/features/activity_feed/models/activity_feed_item.dart';
import 'package:roam_io/features/journeys/data/journey_service.dart';
import 'package:roam_io/features/journeys/data/polyline_codec.dart';
import 'package:roam_io/features/journeys/domain/journey.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/domain/journey_share_details.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/journeys/widgets/journey_share_card.dart';
import 'package:roam_io/features/journeys/widgets/journey_share_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JourneyShareSheet.resolveShareDetails', () {
    test('finds the owner’s journey through sourceJourneyId', () async {
      // The activity is 'journey_journey-1' while the document is 'journey-1';
      // looking it up by the activity id is what produced placeholder cards.
      final details = await JourneyShareSheet.resolveShareDetails(
        _activity(),
        currentUserId: 'user-1',
        journeyService: await _seededJourneyService(_journey()),
      );

      expect(details.title, 'Morning loop');
      expect(details.stats.first.value, '5.0');
      expect(details.transportMode, TransportMode.walk);
    });

    test('keeps the post’s map picture when it loads the journey', () async {
      final details = await JourneyShareSheet.resolveShareDetails(
        _activity(mapImageUrl: 'https://example.com/map.png'),
        currentUserId: 'user-1',
        journeyService: await _seededJourneyService(_journey()),
      );

      // The journey document holds no picture, so losing it here would send
      // the owner's card back to drawing a bare polyline.
      expect(details.title, 'Morning loop');
      expect(details.mapImageUrl, 'https://example.com/map.png');
    });

    test('builds a friend’s post from the post itself', () async {
      final details = await JourneyShareSheet.resolveShareDetails(
        _activity(),
        currentUserId: 'user-2',
        journeyService: await _seededJourneyService(_journey()),
      );

      // Their journey document is unreadable, so nothing from it appears.
      expect(details.title, 'Trip to the pier');
      expect(details.stats.first.value, '1.4');
      expect(details.transportMode, TransportMode.run);
    });

    test('still shares when the journey document is gone', () async {
      final details = await JourneyShareSheet.resolveShareDetails(
        _activity(),
        currentUserId: 'user-1',
        journeyService: await _seededJourneyService(null),
      );

      expect(details.title, 'Trip to the pier');
      expect(details.hasRoute, isTrue);
    });

    test('shares a sidequest post without looking for a journey', () async {
      final details = await JourneyShareSheet.resolveShareDetails(
        _sidequest(),
        currentUserId: 'user-1',
        journeyService: await _seededJourneyService(_journey()),
      );

      expect(details.title, 'Hidden Laneways');
      expect(details.hasRoute, isFalse);
      expect(details.transportMode, isNull);
      expect(details.stats.single.value, '+250 XP');
    });
  });

  group('JourneyShareCard', () {
    testWidgets('gives the map the shape it was captured in', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JourneyShareCard(
              details: JourneyShareDetails(
                title: 'Morning loop',
                encodedRoute: '',
                mapImageUrl: 'https://example.com/map.png',
                stats: <ShareStat>[ShareStat(value: '5.0', unit: 'km')],
              ),
            ),
          ),
        ),
      );

      // The slot and the picture have to agree, or the card shows the map in
      // bands of empty card the way it did when this was a square.
      expect(
        tester
            .widgetList<AspectRatio>(find.byType(AspectRatio))
            .map((slot) => slot.aspectRatio),
        contains(ActivityMapImage.aspectRatio),
      );
    });
  });
}

const _routePoints = [LatLng(-37.8136, 144.9631), LatLng(-37.8036, 144.9731)];

final _encodedRoute = PolylineCodec.encode(_routePoints);

/// A [JourneyService] over a fake Firestore, optionally holding [journey].
Future<JourneyService> _seededJourneyService(Journey? journey) async {
  final firestore = FakeFirebaseFirestore();
  if (journey != null) {
    await firestore
        .collection('profiles')
        .doc(journey.userId)
        .collection('journeys')
        .doc(journey.id)
        .set(journey.toMap());
  }
  return JourneyService(firestore: firestore);
}

Journey _journey() {
  return Journey(
    id: 'journey-1',
    userId: 'user-1',
    startTime: DateTime.utc(2026, 8, 26, 8),
    endTime: DateTime.utc(2026, 8, 26, 8, 21),
    startLocation: const JourneyLocation(
      latLng: LatLng(-37.8136, 144.9631),
      displayName: 'Start',
    ),
    endLocation: const JourneyLocation(
      latLng: LatLng(-37.8036, 144.9731),
      displayName: 'Finish',
    ),
    transportMode: TransportMode.walk,
    encodedRoute: _encodedRoute,
    distanceMeters: 5000,
    durationSeconds: 1260,
    title: 'Morning loop',
    xpEarned: 1527,
    tilesUnlocked: 4,
  );
}

ActivityFeedItem _activity({String? mapImageUrl}) {
  return ActivityFeedItem(
    id: 'journey_journey-1',
    ownerId: 'user-1',
    displayName: 'Amar',
    timestampLabel: 'Today',
    title: 'Trip to the pier',
    kind: ActivityFeedKind.journey,
    metrics: const [
      ActivityFeedMetric(label: 'Time', value: '21m 0s'),
      ActivityFeedMetric(label: 'Tiles Unlocked', value: '4'),
      ActivityFeedMetric(label: 'XP Gained', value: '+1527 XP'),
    ],
    sourceJourneyId: 'journey-1',
    encodedRoute: _encodedRoute,
    journeyStartTime: DateTime.utc(2026, 8, 26, 8),
    journeyEndTime: DateTime.utc(2026, 8, 26, 8, 21),
    transportMode: 'run',
    mapImageUrl: mapImageUrl,
  );
}

ActivityFeedItem _sidequest() {
  return const ActivityFeedItem(
    id: 'sidequest_quest-1',
    ownerId: 'user-1',
    displayName: 'Amar',
    timestampLabel: 'Today',
    title: 'Hidden Laneways',
    kind: ActivityFeedKind.sidequest,
    metrics: [ActivityFeedMetric(label: 'XP Gained', value: '+250 XP')],
  );
}
