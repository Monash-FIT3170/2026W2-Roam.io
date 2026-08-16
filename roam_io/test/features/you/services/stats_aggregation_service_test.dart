import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/domain/journey.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/map/domain/visit_event.dart';
import 'package:roam_io/features/profile/domain/stats_summary.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_meta.dart';
import 'package:roam_io/features/you/services/stats_aggregation_service.dart';

void main() {
  const service = StatsAggregationService();

  group('StatsAggregationService', () {
    test('topPlaces prefers visit events over summary docs', () {
      final events = <VisitEvent>[
        VisitEvent(
          id: 'e1',
          placeId: 1,
          googlePlaceId: 'g1',
          placeName: 'Cafe',
          regionId: 'r1',
          category: 'food_drink',
          lat: -37.8,
          lng: 144.9,
          visitedAt: DateTime(2026, 5, 1),
        ),
        VisitEvent(
          id: 'e2',
          placeId: 1,
          googlePlaceId: 'g1',
          placeName: 'Cafe',
          regionId: 'r1',
          category: 'food_drink',
          lat: -37.8,
          lng: 144.9,
          visitedAt: DateTime(2026, 5, 2),
        ),
        VisitEvent(
          id: 'e3',
          placeId: 2,
          googlePlaceId: 'g2',
          placeName: 'Park',
          regionId: 'r2',
          category: 'nature',
          lat: -37.81,
          lng: 144.91,
          visitedAt: DateTime(2026, 5, 3),
        ),
      ];

      final top = service.topPlaces(events: events, visits: const [], limit: 2);

      expect(top.first.placeName, 'Cafe');
      expect(top.first.visitCount, 2);
      expect(top.last.placeName, 'Park');
    });

    test('xpSourceBreakdown falls back to stats summary totals', () {
      const summary = StatsSummary(
        xpFromVisits: 100,
        xpFromTileUnlocks: 50,
        xpFromJourneys: 25,
      );

      final breakdown = service.xpSourceBreakdown(
        eventTotals: const {},
        summary: summary,
      );

      expect(breakdown.first.label, 'Visits');
      expect(breakdown.first.value, 100);
    });

    test('melbourneCoveragePercent clamps to 100', () {
      expect(service.melbourneCoveragePercent(0), 0);
      expect(
        service.melbourneCoveragePercent(melbourneMetroAreaSquareMetres * 2),
        100,
      );
    });

    test('furthestFromHomeKm returns null without home base', () {
      expect(
        service.furthestFromHomeKm(
          events: [
            VisitEvent(
              id: 'e1',
              placeId: 1,
              googlePlaceId: 'g1',
              placeName: 'Far',
              regionId: 'r1',
              category: 'other',
              lat: -38.0,
              lng: 145.0,
              visitedAt: DateTime(2026, 5, 1),
            ),
          ],
          homeBase: null,
        ),
        isNull,
      );
    });

    test('journeyInsightMessage prefers best exploration yield', () {
      final journeys = <Journey>[
        Journey(
          id: 'j1',
          userId: 'u1',
          startTime: DateTime(2026, 5, 1, 9),
          endTime: DateTime(2026, 5, 1, 10),
          startLocation: JourneyLocation(
            latLng: const LatLng(-37.8, 144.9),
            displayName: 'Start',
          ),
          endLocation: JourneyLocation(
            latLng: const LatLng(-37.81, 144.91),
            displayName: 'End',
          ),
          transportMode: TransportMode.walk,
          encodedRoute: 'abc',
          distanceMeters: 5000,
          durationSeconds: 3600,
          tilesUnlocked: 10,
          tilesPerKm: 2.0,
        ),
      ];

      expect(
        service.journeyInsightMessage(journeys),
        'Best exploration yield: 2.0 tiles/km',
      );
    });

    test('topTilesByEntryCount uses meta names when available', () {
      final meta = <String, VisitedPolygonMeta>{
        'tile-1': VisitedPolygonMeta(
          polygonId: 'tile-1',
          visitedAt: DateTime(2026, 5, 1),
          name: 'Carlton',
        ),
      };

      final tiles = service.topTilesByEntryCount(
        entryCounts: const {'tile-1': 4},
        metaByPolygonId: meta,
      );

      expect(tiles.single.displayName, 'Carlton');
      expect(tiles.single.entryCount, 4);
    });

    test('formatTileDisplayName prefers SA2 suburb from stored region name', () {
      expect(
        service.formatTileDisplayName(
          name: 'Carlton - SA1 21102126135',
          polygonId: '21102126135',
        ),
        'Carlton',
      );
      expect(
        service.formatTileDisplayName(
          name: null,
          polygonId: '21102126135',
        ),
        'Area 211021',
      );
    });

    test('revealedAreaSquareMetres estimates when meta has no areas', () {
      final revealed = service.revealedAreaSquareMetres(
        summary: const StatsSummary(),
        polygonMeta: const {},
        tileCount: 4,
      );

      expect(revealed.isEstimated, isTrue);
      expect(revealed.squareMetres, 4 * averageSa1AreaSquareMetres);
      expect(
        service.formatAreaKm2(revealed.squareMetres, isEstimated: true),
        '~1.00 km²',
      );
      expect(
        service.formatCoveragePercent(revealed.squareMetres),
        isNot(equals('0.00%')),
      );
    });
  });
}
