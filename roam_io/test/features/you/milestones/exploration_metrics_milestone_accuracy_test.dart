import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/domain/journey.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/map/data/visit.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/features/profile/domain/stats_summary.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_meta.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_record.dart';
import 'package:roam_io/features/profile/domain/xp_award_result.dart';
import 'package:roam_io/features/profile/domain/pending_xp_celebration.dart';
import 'package:roam_io/features/you/milestones/milestone_catalog.dart';
import 'package:roam_io/features/you/milestones/milestone_progress.dart';
import 'package:roam_io/features/you/services/stats_aggregation_service.dart';

/// Mirrors [MilestonesProvider] metric assembly so exploration accuracy is
/// validated end-to-end from raw stats → milestone tiers.
MilestoneMetrics metricsFromExploration({
  required StatsAggregationService aggregation,
  required StatsSummary summary,
  required List<Visit> visits,
  required List<Journey> journeys,
  required List<VisitedPolygonRecord> tiles,
  required Map<String, VisitedPolygonMeta> polygonMeta,
}) {
  final tileCount = aggregation.tileCountFromSummary(summary, tiles);
  final revealed = aggregation.revealedAreaSquareMetres(
    summary: summary,
    polygonMeta: polygonMeta,
    tileCount: tileCount,
  );
  final journeyCount = summary.totalJourneys > 0
      ? summary.totalJourneys
      : journeys.length;
  final distanceMeters = summary.totalDistanceMeters > 0
      ? summary.totalDistanceMeters
      : aggregation.totalJourneyDistance(journeys);
  final journeySeconds = summary.totalJourneySeconds > 0
      ? summary.totalJourneySeconds
      : aggregation.totalJourneySeconds(journeys);

  return MilestoneMetrics(
    areaKm2: revealed.squareMetres / 1_000_000,
    tilesUnlocked: tileCount,
    totalVisits: aggregation.totalVisitEvents(visits),
    journeyCount: journeyCount,
    distanceKm: distanceMeters / 1000,
    journeyHours: journeySeconds / 3600,
    xpStreakDays: summary.currentXpStreakDays,
  );
}

Journey _journey({
  required String id,
  required double distanceMeters,
  required int durationSeconds,
}) {
  final start = DateTime(2026, 5, 1, 9);
  return Journey(
    id: id,
    userId: 'u1',
    startTime: start,
    endTime: start.add(Duration(seconds: durationSeconds)),
    startLocation: const JourneyLocation(
      latLng: LatLng(-37.8, 144.9),
      displayName: 'Start',
    ),
    endLocation: const JourneyLocation(
      latLng: LatLng(-37.81, 144.91),
      displayName: 'End',
    ),
    transportMode: TransportMode.walk,
    encodedRoute: 'abc',
    distanceMeters: distanceMeters,
    durationSeconds: durationSeconds,
    tilesUnlocked: 0,
  );
}

Visit _visit({required int placeId, required int visitCount}) {
  return Visit(
    placeId: placeId,
    googlePlaceId: 'g$placeId',
    placeName: 'Place $placeId',
    regionId: 'r$placeId',
    category: 'food_drink',
    visitedAt: DateTime(2026, 5, placeId.clamp(1, 28)),
    visitCount: visitCount,
  );
}

void main() {
  const aggregation = StatsAggregationService();
  const builder = MilestoneProgressBuilder();

  group('Exploration metrics → milestone tiers', () {
    test('Visit Viking uses summed visit counts, not unique places', () {
      final visits = [
        _visit(placeId: 1, visitCount: 3),
        _visit(placeId: 2, visitCount: 2),
        // 5 visit events total → tier 1; unique places would be 2 (no tier).
      ];
      final metrics = metricsFromExploration(
        aggregation: aggregation,
        summary: const StatsSummary(),
        visits: visits,
        journeys: const [],
        tiles: const [],
        polygonMeta: const {},
      );

      expect(metrics.totalVisits, 5);
      expect(aggregation.uniquePlaces(visits), 2);

      final progress = builder.build(
        definition: MilestoneCatalog.byId(MilestoneId.visitViking),
        claimState: const MilestoneClaimState(
          milestoneId: MilestoneId.visitViking,
        ),
        metrics: metrics,
      );
      expect(progress.earnedTier, 1);
      expect(progress.claimableTiers, [1]);
    });

    test('Map Magnate and Tile Collector track revealed area and tiles', () {
      final tiles = List<VisitedPolygonRecord>.generate(
        15,
        (index) => VisitedPolygonRecord(
          profileId: 'u1',
          polygonId: 'tile-$index',
          visitedAt: DateTime(2026, 5, 1),
        ),
      );
      // 15 tiles × 250_000 m² estimate = 3.75 km² → Map Magnate tier 2 (3 km²)
      final metrics = metricsFromExploration(
        aggregation: aggregation,
        summary: const StatsSummary(),
        visits: const [],
        journeys: const [],
        tiles: tiles,
        polygonMeta: const {},
      );

      expect(metrics.tilesUnlocked, 15);
      expect(metrics.areaKm2, closeTo(3.75, 1e-9));

      final tileProgress = builder.build(
        definition: MilestoneCatalog.byId(MilestoneId.tileCollector),
        claimState: const MilestoneClaimState(
          milestoneId: MilestoneId.tileCollector,
        ),
        metrics: metrics,
      );
      expect(tileProgress.earnedTier, 2); // thresholds 5, 15

      final areaProgress = builder.build(
        definition: MilestoneCatalog.byId(MilestoneId.mapMagnate),
        claimState: const MilestoneClaimState(
          milestoneId: MilestoneId.mapMagnate,
        ),
        metrics: metrics,
      );
      expect(areaProgress.earnedTier, 2); // thresholds 1, 3, 5…
    });

    test('journey milestones convert metres/seconds into km and hours', () {
      final journeys = [
        _journey(id: 'j1', distanceMeters: 12000, durationSeconds: 7200),
        _journey(id: 'j2', distanceMeters: 13000, durationSeconds: 3600),
      ];
      // 25 km → Kilometre Crusader tier 2 (5, 25)
      // 3 hours → Clocked Cruiser tier 1 (1, 5…)
      // 2 journeys → Trip Tally tier 2 (1, 5…)
      final metrics = metricsFromExploration(
        aggregation: aggregation,
        summary: const StatsSummary(),
        visits: const [],
        journeys: journeys,
        tiles: const [],
        polygonMeta: const {},
      );

      expect(metrics.distanceKm, 25);
      expect(metrics.journeyHours, 3);
      expect(metrics.journeyCount, 2);

      expect(
        builder
            .build(
              definition: MilestoneCatalog.byId(MilestoneId.kilometreCrusader),
              claimState: const MilestoneClaimState(
                milestoneId: MilestoneId.kilometreCrusader,
              ),
              metrics: metrics,
            )
            .earnedTier,
        2,
      );
      expect(
        builder
            .build(
              definition: MilestoneCatalog.byId(MilestoneId.clockedCruiser),
              claimState: const MilestoneClaimState(
                milestoneId: MilestoneId.clockedCruiser,
              ),
              metrics: metrics,
            )
            .earnedTier,
        1,
      );
      expect(
        builder
            .build(
              definition: MilestoneCatalog.byId(MilestoneId.tripTally),
              claimState: const MilestoneClaimState(
                milestoneId: MilestoneId.tripTally,
              ),
              metrics: metrics,
            )
            .earnedTier,
        1,
      );
    });

    test('summary rollups override live journey lists when present', () {
      final metrics = metricsFromExploration(
        aggregation: aggregation,
        summary: const StatsSummary(
          totalJourneys: 40,
          totalDistanceMeters: 200_000,
          totalJourneySeconds: 40 * 3600,
          currentXpStreakDays: 14,
        ),
        visits: const [],
        journeys: [
          // Would only count as 1 journey / tiny distance if used.
          _journey(id: 'ignored', distanceMeters: 100, durationSeconds: 60),
        ],
        tiles: const [],
        polygonMeta: const {},
      );

      expect(metrics.journeyCount, 40);
      expect(metrics.distanceKm, 200);
      expect(metrics.journeyHours, 40);
      expect(metrics.xpStreakDays, 14);

      final all = builder.buildAll(claims: const {}, metrics: metrics);
      final byId = {
        for (final progress in all) progress.definition.id: progress,
      };
      expect(byId[MilestoneId.tripTally]!.earnedTier, 4); // 1,5,15,40
      expect(byId[MilestoneId.kilometreCrusader]!.earnedTier, 4); // …200
      expect(byId[MilestoneId.clockedCruiser]!.earnedTier, 4); // …40
      expect(byId[MilestoneId.flameKeeper]!.earnedTier, 3); // 3,7,14
    });

    test('summary area and tile totals drive Map Magnate / Tile Collector', () {
      final metrics = metricsFromExploration(
        aggregation: aggregation,
        summary: const StatsSummary(
          totalTiles: 100,
          totalAreaSquareMetres: 15_000_000, // 15 km²
        ),
        visits: const [],
        journeys: const [],
        tiles: const [],
        polygonMeta: const {},
      );

      expect(metrics.tilesUnlocked, 100);
      expect(metrics.areaKm2, 15);

      final all = builder.buildAll(claims: const {}, metrics: metrics);
      final byId = {
        for (final progress in all) progress.definition.id: progress,
      };
      expect(byId[MilestoneId.tileCollector]!.earnedTier, 4); // …100
      expect(byId[MilestoneId.mapMagnate]!.earnedTier, 4); // …15
    });
  });

  group('PendingXpCelebration', () {
    test('fromAward copies XP transition and detects level-ups', () {
      final leveled = PendingXpCelebration.fromAward(
        XpAwardResult.success(
          amount: 100,
          previousXp: 80,
          newXp: 180,
          previousLevel: 1,
          newLevel: 2,
          historyRecorded: true,
        ),
      );
      expect(leveled.didLevelUp, isTrue);
      expect(leveled.previousXp, 80);
      expect(leveled.newXp, 180);
      expect(leveled.previousLevel, 1);
      expect(leveled.newLevel, 2);

      final flat = PendingXpCelebration.fromAward(
        XpAwardResult.success(
          amount: 10,
          previousXp: 10,
          newXp: 20,
          previousLevel: 1,
          newLevel: 1,
          historyRecorded: true,
        ),
      );
      expect(flat.didLevelUp, isFalse);
    });

    test('withRewardToast preserves XP fields', () {
      const base = PendingXpCelebration(
        previousXp: 0,
        newXp: 100,
        previousLevel: 1,
        newLevel: 2,
      );
      final toasted = base.withRewardToast('Unlocked +50 XP');
      expect(toasted.rewardToastMessage, 'Unlocked +50 XP');
      expect(toasted.newLevel, 2);
      expect(toasted.previousXp, 0);
    });
  });

  group('Profile XP curve used by celebration progress', () {
    test('within-level progress math matches Stats / celebration formula', () {
      // Level 2 starts at 100 XP and needs 300 XP to reach level 3.
      expect(ProfileModel.totalXpToReachLevel(2), 100);
      expect(ProfileModel.xpForLevel(2), 300);
      expect(ProfileModel.levelFromXp(100), 2);
      expect(ProfileModel.levelFromXp(399), 2);
      expect(ProfileModel.levelFromXp(400), 3);

      const previousXp = 150; // 50 into level 2
      const newXp = 400; // exactly level 3
      expect(ProfileModel.levelFromXp(previousXp), 2);
      expect(ProfileModel.levelFromXp(newXp), 3);

      final previousInto =
          previousXp - ProfileModel.totalXpToReachLevel(2); // 50
      final previousNeed = ProfileModel.xpForLevel(2); // 300
      expect(previousInto / previousNeed, closeTo(50 / 300, 1e-9));
    });
  });
}
