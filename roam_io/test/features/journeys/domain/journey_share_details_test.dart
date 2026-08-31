/*
 * Author: Amarprit Singh
 * Last Updated: 29 August 2026
 * Description:
 *   A share card used to be filled with placeholder numbers whenever the
 *   journey document was out of reach. These cover the values recovered from
 *   the post itself instead, and the ones taken from the journey when the
 *   sharer owns it.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/activity_feed/models/activity_feed_item.dart';
import 'package:roam_io/features/journeys/data/polyline_codec.dart';
import 'package:roam_io/features/journeys/domain/journey.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/domain/journey_share_details.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';

void main() {
  group('fromJourney', () {
    test('reads the journey it was given', () {
      final details = JourneyShareDetails.fromJourney(_journey());

      expect(details.title, 'Morning loop');
      expect(details.transportMode, TransportMode.walk);
      expect(details.encodedRoute, _encodedRoute);
      expect(_stats(details), [('5.0', 'km'), ('21', 'min'), ('1527', 'xp')]);
    });

    test('shows tiles for a journey that never recorded XP', () {
      final details = JourneyShareDetails.fromJourney(_journey(xpEarned: null));

      expect(_stats(details).last, ('4', 'tiles'));
    });

    test('takes the map picture from the post it was shared from', () {
      final details = JourneyShareDetails.fromJourney(
        _journey(),
        mapImageUrl: 'https://example.com/map.png',
      );

      expect(details.mapImageUrl, 'https://example.com/map.png');
    });

    test('falls back to the drawn route without a picture', () {
      final details = JourneyShareDetails.fromJourney(_journey());

      expect(details.hasMapImage, isFalse);
      expect(details.hasMapArea, isTrue);
    });
  });

  group('fromActivity', () {
    test('measures the post it was given', () {
      final details = JourneyShareDetails.fromActivity(_activity());

      expect(details.title, 'Trip to the pier');
      expect(details.transportMode, TransportMode.run);
      expect(details.hasRoute, isTrue);
      // ~1.4 km of route, 21 minutes between the recorded timestamps.
      expect(_stats(details), [('1.4', 'km'), ('21', 'min'), ('1527', 'xp')]);
    });

    test('prefers the recorded timestamps over the Time metric', () {
      final details = JourneyShareDetails.fromActivity(
        _activity(
          journeyEndTime: DateTime.utc(2026, 8, 26, 9, 30),
          metrics: const [ActivityFeedMetric(label: 'Time', value: '21m 0s')],
        ),
      );

      expect(_stats(details)[1], ('1.5', 'hrs'));
    });

    test('keeps the hours when it falls back to the Time metric', () {
      final details = JourneyShareDetails.fromActivity(
        _activity(
          withJourneyTimes: false,
          metrics: const [ActivityFeedMetric(label: 'Time', value: '1h 30m')],
        ),
      );

      expect(_stats(details)[1], ('1.5', 'hrs'));
    });

    test('reads a Time metric written in minutes and seconds', () {
      final details = JourneyShareDetails.fromActivity(
        _activity(
          withJourneyTimes: false,
          metrics: const [ActivityFeedMetric(label: 'Time', value: '21m 0s')],
        ),
      );

      expect(_stats(details)[1], ('21', 'min'));
    });

    test('shows tiles when the post recorded no XP', () {
      final details = JourneyShareDetails.fromActivity(
        _activity(
          metrics: const [
            ActivityFeedMetric(label: 'Tiles Unlocked', value: '4'),
          ],
        ),
      );

      expect(_stats(details).last, ('4', 'tiles'));
    });

    test('drops the distance for a post with no route', () {
      final details = JourneyShareDetails.fromActivity(
        _activity(withRoute: false),
      );

      expect(details.hasRoute, isFalse);
      expect(_stats(details), [('21', 'min'), ('1527', 'xp')]);
    });

    test('carries the map picture stored with the post', () {
      final details = JourneyShareDetails.fromActivity(
        _activity(mapImageUrl: 'https://example.com/map.png'),
      );

      expect(details.mapImageUrl, 'https://example.com/map.png');
      expect(details.hasMapImage, isTrue);
    });

    test('keeps a map area for a picture with no route behind it', () {
      final details = JourneyShareDetails.fromActivity(
        _activity(withRoute: false, mapImageUrl: 'https://example.com/map.png'),
      );

      expect(details.hasRoute, isFalse);
      expect(details.hasMapArea, isTrue);
    });

    test('shares a sidequest as its own metrics, with no map', () {
      final details = JourneyShareDetails.fromActivity(
        _activity(
          kind: ActivityFeedKind.sidequest,
          withRoute: false,
          withJourneyTimes: false,
          transportMode: null,
          metrics: const [
            ActivityFeedMetric(label: 'Quest', value: 'Hidden Laneways'),
            ActivityFeedMetric(label: 'XP Gained', value: '+250 XP'),
          ],
        ),
      );

      expect(details.title, 'Trip to the pier');
      expect(details.hasRoute, isFalse);
      expect(details.transportMode, isNull);
      expect(_stats(details), [
        ('Hidden Laneways', 'Quest'),
        ('+250 XP', 'XP Gained'),
      ]);
    });

    test('falls back to the metrics row when nothing else is recoverable', () {
      final details = JourneyShareDetails.fromActivity(
        _activity(
          withRoute: false,
          withJourneyTimes: false,
          metrics: const [
            ActivityFeedMetric(label: 'Explored', value: '3 regions'),
          ],
        ),
      );

      expect(_stats(details), [('3 regions', 'Explored')]);
    });
  });
}

const _routePoints = [LatLng(-37.8136, 144.9631), LatLng(-37.8036, 144.9731)];

final _encodedRoute = PolylineCodec.encode(_routePoints);

List<(String, String)> _stats(JourneyShareDetails details) {
  return details.stats
      .map((stat) => (stat.value, stat.unit))
      .toList(growable: false);
}

Journey _journey({int? xpEarned = 1527}) {
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
    xpEarned: xpEarned,
    tilesUnlocked: 4,
  );
}

const _defaultMetrics = [
  ActivityFeedMetric(label: 'Time', value: '21m 0s'),
  ActivityFeedMetric(label: 'Tiles Unlocked', value: '4'),
  ActivityFeedMetric(label: 'XP Gained', value: '+1527 XP'),
];

ActivityFeedItem _activity({
  ActivityFeedKind kind = ActivityFeedKind.journey,
  bool withRoute = true,
  bool withJourneyTimes = true,
  DateTime? journeyEndTime,
  String? transportMode = 'run',
  String? mapImageUrl,
  List<ActivityFeedMetric> metrics = _defaultMetrics,
}) {
  final start = DateTime.utc(2026, 8, 26, 8);

  return ActivityFeedItem(
    id: 'journey_journey-1',
    ownerId: 'user-1',
    displayName: 'Amar',
    timestampLabel: 'Today',
    title: 'Trip to the pier',
    kind: kind,
    metrics: metrics,
    sourceJourneyId: 'journey-1',
    encodedRoute: withRoute ? _encodedRoute : null,
    journeyStartTime: withJourneyTimes ? start : null,
    journeyEndTime: withJourneyTimes
        ? (journeyEndTime ?? start.add(const Duration(minutes: 21)))
        : null,
    transportMode: transportMode,
    mapImageUrl: mapImageUrl,
  );
}
