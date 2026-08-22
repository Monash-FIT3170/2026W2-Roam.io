import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/you/milestones/milestone_catalog.dart';
import 'package:roam_io/features/you/milestones/milestone_progress.dart';

void main() {
  group('MilestoneCatalog', () {
    test('defines seven milestones with five scaled XP tiers', () {
      expect(MilestoneCatalog.all, hasLength(7));
      for (final definition in MilestoneCatalog.all) {
        expect(definition.tiers, hasLength(5));
        expect(definition.tierDefinition(1).xpReward, 100);
        expect(definition.tierDefinition(5).xpReward, 2500);
      }
    });

    test('uses locked display names', () {
      expect(
        MilestoneCatalog.byId(MilestoneId.mapMagnate).title,
        'Map Magnate',
      );
      expect(
        MilestoneCatalog.byId(MilestoneId.clockedCruiser).title,
        'Clocked Cruiser',
      );
      expect(
        MilestoneCatalog.byId(MilestoneId.flameKeeper).title,
        'Flame Keeper',
      );
    });
  });

  group('MilestoneProgressBuilder', () {
    const builder = MilestoneProgressBuilder();

    test('marks earned unclaimed tiers as claimable in order', () {
      final definition = MilestoneCatalog.byId(MilestoneId.visitViking);
      final progress = builder.build(
        definition: definition,
        claimState: const MilestoneClaimState(
          milestoneId: MilestoneId.visitViking,
          claimedTiers: {1},
        ),
        metrics: const MilestoneMetrics(
          areaKm2: 0,
          tilesUnlocked: 0,
          totalVisits: 40,
          journeyCount: 0,
          distanceKm: 0,
          journeyHours: 0,
          xpStreakDays: 0,
        ),
      );

      expect(progress.earnedTier, 3);
      expect(progress.claimableTiers, [2, 3]);
      expect(progress.nextClaimableTier, 2);
      expect(progress.displayTier, 2);
    });

    test('backfill exposes every earned tier when nothing claimed', () {
      final definition = MilestoneCatalog.byId(MilestoneId.tripTally);
      final progress = builder.build(
        definition: definition,
        claimState: const MilestoneClaimState(
          milestoneId: MilestoneId.tripTally,
        ),
        metrics: const MilestoneMetrics(
          areaKm2: 0,
          tilesUnlocked: 0,
          totalVisits: 0,
          journeyCount: 15,
          distanceKm: 0,
          journeyHours: 0,
          xpStreakDays: 0,
        ),
      );

      expect(progress.earnedTier, 3);
      expect(progress.claimableTiers, [1, 2, 3]);
      expect(progress.displayTier, 1);
    });

    test('shows next goal badge once all earned tiers are claimed', () {
      final definition = MilestoneCatalog.byId(MilestoneId.visitViking);
      final progress = builder.build(
        definition: definition,
        claimState: const MilestoneClaimState(
          milestoneId: MilestoneId.visitViking,
          claimedTiers: {1, 2},
        ),
        metrics: const MilestoneMetrics(
          areaKm2: 0,
          tilesUnlocked: 0,
          totalVisits: 15,
          journeyCount: 0,
          distanceKm: 0,
          journeyHours: 0,
          xpStreakDays: 0,
        ),
      );

      expect(progress.earnedTier, 2);
      expect(progress.nextClaimableTier, isNull);
      expect(progress.nextTier?.tier, 3);
      expect(progress.displayTier, 3);
    });
  });
}
