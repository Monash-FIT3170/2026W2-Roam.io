/*
 * Author: Amarprit Singh
 * Last Updated: 4 October 2026
 * Description:
 *   Tests for the Profile tab's derived journey feed: display titles,
 *   distance fallbacks, highlights, week grouping, weekly totals and the
 *   journey streak.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/activity_feed/models/activity_feed_item.dart';
import 'package:roam_io/features/journeys/domain/journey.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_record.dart';
import 'package:roam_io/features/you/services/profile_feed_builder.dart';

// Saturday 4 October 2026; that week starts Monday 28 September.
final _now = DateTime(2026, 10, 4, 18);

void main() {
  group('deriveJourneyDisplayTitle', () {
    test('names the destination for generic titles', () {
      expect(
        deriveJourneyDisplayTitle(
          storedTitle: 'Morning Journey',
          transportMode: TransportMode.drive,
          start: 'Home',
          destination: 'Clayton',
          tilesUnlocked: 0,
        ),
        'Morning drive to Clayton',
      );
    });

    test('describes a loop when start and destination match', () {
      expect(
        deriveJourneyDisplayTitle(
          storedTitle: 'Evening Journey',
          transportMode: TransportMode.walk,
          start: 'Box Hill',
          destination: 'Box Hill',
          tilesUnlocked: 2,
        ),
        'Evening walk around Box Hill',
      );
    });

    test('falls back to new tiles, then the mode, then the stored title', () {
      expect(
        deriveJourneyDisplayTitle(
          storedTitle: 'Afternoon Journey',
          transportMode: TransportMode.drive,
          start: null,
          destination: null,
          tilesUnlocked: 5,
        ),
        'Explored 5 new tiles',
      );
      expect(
        deriveJourneyDisplayTitle(
          storedTitle: 'Afternoon Journey',
          transportMode: TransportMode.tram,
          start: null,
          destination: null,
          tilesUnlocked: 0,
        ),
        'Afternoon tram ride',
      );
      expect(
        deriveJourneyDisplayTitle(
          storedTitle: 'Afternoon Journey',
          transportMode: null,
          start: null,
          destination: null,
          tilesUnlocked: 0,
        ),
        'Afternoon Journey',
      );
    });

    test('never replaces a title the traveller chose', () {
      expect(
        deriveJourneyDisplayTitle(
          storedTitle: 'Beach run with Sam',
          transportMode: TransportMode.run,
          start: 'Home',
          destination: 'St Kilda',
          tilesUnlocked: 4,
        ),
        'Beach run with Sam',
      );
    });
  });

  group('buildProfileJourneyEntries', () {
    test('joins the source journey for distance, place and title', () {
      final journey = _journey(
        'j1',
        start: DateTime(2026, 10, 2, 8),
        distanceMeters: 12400,
        durationSeconds: 1500,
        tiles: 3,
        xp: 109,
        startName: 'Current Location',
        endName: 'Clayton',
      );
      final entry = buildProfileJourneyEntries(
        activities: [
          _activity('a1', journeyId: 'j1', title: 'Morning Journey'),
        ],
        journeys: [journey],
        now: _now,
      ).single;

      expect(entry.journey, journey);
      expect(entry.distanceMeters, 12400);
      expect(entry.durationSeconds, 1500);
      expect(entry.tilesUnlocked, 3);
      expect(entry.xpEarned, 109);
      expect(entry.placeLabel, 'Clayton');
      expect(entry.title, 'Morning drive to Clayton');
      expect(entry.displayActivity.title, 'Morning drive to Clayton');
    });

    test(
      'measures the route and reads metrics when the journey is missing',
      () {
        final entry = buildProfileJourneyEntries(
          activities: [
            _activity(
              'a1',
              journeyId: 'not-loaded',
              title: 'Afternoon Journey',
              encodedRoute: _encodedRoute,
            ),
          ],
          journeys: const <Journey>[],
          now: _now,
        ).single;

        expect(entry.journey, isNull);
        expect(entry.distanceMeters, greaterThan(100000));
        expect(entry.durationSeconds, 7 * 60 + 7);
        expect(entry.tilesUnlocked, 2);
        expect(entry.xpEarned, 109);
        expect(entry.title, 'Explored 2 new tiles');
      },
    );

    test('leaves non-journey posts as they were stored', () {
      final entry = buildProfileJourneyEntries(
        activities: [
          _activity(
            's1',
            title: 'Morning Journey',
            kind: ActivityFeedKind.sidequest,
          ),
        ],
        journeys: const <Journey>[],
        now: _now,
      ).single;

      expect(entry.isJourney, isFalse);
      expect(entry.title, 'Morning Journey');
      expect(entry.distanceMeters, isNull);
    });

    test('marks the longest journey of a month and the most tiles ever', () {
      final journeys = [
        _journey(
          'long',
          start: DateTime(2026, 10, 1, 8),
          distanceMeters: 30000,
          tiles: 1,
        ),
        _journey(
          'tiles',
          start: DateTime(2026, 10, 2, 8),
          distanceMeters: 8000,
          tiles: 9,
        ),
        _journey(
          'september',
          start: DateTime(2026, 9, 10, 8),
          distanceMeters: 50000,
        ),
      ];
      final entries = buildProfileJourneyEntries(
        activities: [
          _activity('a-long', journeyId: 'long'),
          _activity('a-tiles', journeyId: 'tiles'),
          _activity('a-september', journeyId: 'september'),
        ],
        journeys: journeys,
        now: _now,
      );

      expect(entries[0].highlights.map((h) => h.label), [
        'Longest journey this month',
      ]);
      expect(entries[1].highlights.map((h) => h.label), [
        'Most tiles in one journey',
      ]);
      // The only September journey has nothing to beat that month.
      expect(entries[2].highlights, isEmpty);
    });
  });

  test('groupProfileFeed splits this week, last week, then months', () {
    final entries = buildProfileJourneyEntries(
      activities: [
        _activity('a', start: DateTime(2026, 10, 3)),
        _activity('b', start: DateTime(2026, 9, 28, 7)),
        _activity('c', start: DateTime(2026, 9, 25)),
        _activity('d', start: DateTime(2026, 9, 2)),
        _activity('e', start: DateTime(2026, 8, 30)),
      ],
      journeys: const <Journey>[],
      now: _now,
    );

    final sections = groupProfileFeed(entries, now: _now);

    expect(sections.map((section) => section.title), [
      'This week',
      'Last week',
      'September 2026',
      'August 2026',
    ]);
    expect(sections.first.entries.map((entry) => entry.activity.id), [
      'a',
      'b',
    ]);
  });

  test('section summary counts journeys and their distance', () {
    final section = ProfileFeedSection(
      title: 'This week',
      entries: buildProfileJourneyEntries(
        activities: [
          _activity('a', journeyId: 'j1'),
          _activity('b', journeyId: 'j2'),
        ],
        journeys: [
          _journey('j1', start: DateTime(2026, 10, 1), distanceMeters: 10000),
          _journey('j2', start: DateTime(2026, 10, 2), distanceMeters: 2500),
        ],
        now: _now,
      ),
    );

    expect(section.summary, '2 journeys · 12.5 km');
  });

  group('buildWeeklyTotals', () {
    test('buckets journeys and tiles into the last 12 weeks', () {
      final weeks = buildWeeklyTotals(
        journeys: [
          _journey(
            'now',
            start: DateTime(2026, 10, 1),
            distanceMeters: 5000,
            durationSeconds: 900,
          ),
          _journey(
            'also-now',
            start: DateTime(2026, 9, 28),
            distanceMeters: 1000,
            durationSeconds: 300,
          ),
          _journey('last', start: DateTime(2026, 9, 27), distanceMeters: 7000),
          _journey('too-old', start: DateTime(2026, 6, 1), distanceMeters: 1),
        ],
        tileRecords: [
          _tile(DateTime(2026, 10, 2)),
          _tile(DateTime(2026, 10, 3)),
          _tile(DateTime(2026, 9, 21)),
        ],
        now: _now,
      );

      expect(weeks, hasLength(12));
      expect(weeks.last.weekStart, DateTime(2026, 9, 28));
      expect(weeks.first.weekStart, DateTime(2026, 7, 13));
      expect(weeks.last.distanceMeters, 6000);
      expect(weeks.last.durationSeconds, 1200);
      expect(weeks.last.journeyCount, 2);
      expect(weeks.last.newTiles, 2);
      expect(weeks[10].distanceMeters, 7000);
      expect(weeks[10].newTiles, 1);
      expect(
        weeks.fold<double>(0, (sum, week) => sum + week.distanceMeters),
        13000,
      );
    });
  });

  group('journeyWeekStreak', () {
    test('counts back from this week', () {
      expect(
        journeyWeekStreak(
          journeys: [
            _journey('a', start: DateTime(2026, 10, 1)),
            _journey('b', start: DateTime(2026, 9, 22)),
            _journey('c', start: DateTime(2026, 9, 15)),
            _journey('gap', start: DateTime(2026, 9, 1)),
          ],
          now: _now,
        ),
        3,
      );
    });

    test('does not break while this week is still empty', () {
      expect(
        journeyWeekStreak(
          journeys: [
            _journey('a', start: DateTime(2026, 9, 22)),
            _journey('b', start: DateTime(2026, 9, 15)),
          ],
          now: _now,
        ),
        2,
      );
    });

    test('is zero after a missed week', () {
      expect(
        journeyWeekStreak(
          journeys: [_journey('a', start: DateTime(2026, 9, 14))],
          now: _now,
        ),
        0,
      );
    });
  });

  test('formats distances and durations for stat blocks', () {
    expect(formatProfileDistance(850), (value: '850', unit: 'm'));
    expect(formatProfileDistance(12449), (value: '12.4', unit: 'km'));
    expect(formatProfileDistance(123456), (value: '123', unit: 'km'));
    expect(formatProfileDuration(427), '7m 7s');
    expect(formatProfileDuration(45), '45s');
    expect(formatProfileDuration(4320), '1h 12m');
    expect(formatProfileDuration(427, includeSeconds: false), '7m');
  });
}

const _encodedRoute = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

ActivityFeedItem _activity(
  String id, {
  String? journeyId,
  String title = 'Afternoon Journey',
  ActivityFeedKind kind = ActivityFeedKind.journey,
  String? encodedRoute,
  DateTime? start,
}) {
  return ActivityFeedItem(
    id: id,
    ownerId: 'user-1',
    displayName: 'Traveller',
    timestampLabel: 'Recently',
    createdAt: start ?? DateTime(2026, 10, 1),
    journeyStartTime: start,
    title: title,
    kind: kind,
    sourceJourneyId: journeyId,
    encodedRoute: encodedRoute,
    transportMode: 'drive',
    metrics: const [
      ActivityFeedMetric(label: 'Time', value: '7m 7s'),
      ActivityFeedMetric(label: 'Tiles Explored', value: '2'),
      ActivityFeedMetric(label: 'XP Gained', value: '+109 XP'),
    ],
  );
}

Journey _journey(
  String id, {
  required DateTime start,
  double distanceMeters = 5000,
  int durationSeconds = 900,
  int tiles = 0,
  int? xp,
  String startName = 'Current Location',
  String endName = 'Current Location',
}) {
  return Journey(
    id: id,
    userId: 'user-1',
    startTime: start,
    endTime: start.add(Duration(seconds: durationSeconds)),
    startLocation: JourneyLocation(
      latLng: const LatLng(-37.9, 145.1),
      displayName: startName,
    ),
    endLocation: JourneyLocation(
      latLng: const LatLng(-37.91, 145.13),
      displayName: endName,
    ),
    transportMode: TransportMode.drive,
    encodedRoute: _encodedRoute,
    distanceMeters: distanceMeters,
    durationSeconds: durationSeconds,
    tilesUnlocked: tiles,
    xpEarned: xp,
  );
}

VisitedPolygonRecord _tile(DateTime visitedAt) {
  return VisitedPolygonRecord(
    profileId: 'user-1',
    polygonId: 'tile-${visitedAt.toIso8601String()}',
    visitedAt: visitedAt,
  );
}
