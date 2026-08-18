import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/you/milestones/milestone_catalog.dart';
import 'package:roam_io/features/you/milestones/milestone_format.dart';
import 'package:roam_io/features/you/milestones/milestone_progress.dart';

MilestoneMetrics _metrics({
  double areaKm2 = 0,
  int tilesUnlocked = 0,
  int totalVisits = 0,
  int journeyCount = 0,
  double distanceKm = 0,
  double journeyHours = 0,
  int xpStreakDays = 0,
}) {
  return MilestoneMetrics(
    areaKm2: areaKm2,
    tilesUnlocked: tilesUnlocked,
    totalVisits: totalVisits,
    journeyCount: journeyCount,
    distanceKm: distanceKm,
    journeyHours: journeyHours,
    xpStreakDays: xpStreakDays,
  );
}

void main() {
  group('MilestoneCatalog thresholds and XP', () {
    test('XP curve is 100 × tier² for every milestone', () {
      for (var tier = 1; tier <= 5; tier++) {
        expect(milestoneXpForTier(tier), 100 * tier * tier);
      }
      for (final definition in MilestoneCatalog.all) {
        for (final tier in definition.tiers) {
          expect(tier.xpReward, milestoneXpForTier(tier.tier));
        }
      }
    });

    test('each milestone uses the locked threshold table', () {
      expect(
        MilestoneCatalog.byId(
          MilestoneId.mapMagnate,
        ).tiers.map((tier) => tier.threshold).toList(),
        [1, 3, 5, 15, 50],
      );
      expect(
        MilestoneCatalog.byId(
          MilestoneId.tileCollector,
        ).tiers.map((tier) => tier.threshold).toList(),
        [5, 15, 40, 100, 250],
      );
      expect(
        MilestoneCatalog.byId(
          MilestoneId.visitViking,
        ).tiers.map((tier) => tier.threshold).toList(),
        [5, 15, 40, 100, 250],
      );
      expect(
        MilestoneCatalog.byId(
          MilestoneId.tripTally,
        ).tiers.map((tier) => tier.threshold).toList(),
        [1, 5, 15, 40, 100],
      );
      expect(
        MilestoneCatalog.byId(
          MilestoneId.kilometreCrusader,
        ).tiers.map((tier) => tier.threshold).toList(),
        [5, 25, 75, 200, 500],
      );
      expect(
        MilestoneCatalog.byId(
          MilestoneId.clockedCruiser,
        ).tiers.map((tier) => tier.threshold).toList(),
        [1, 5, 15, 40, 100],
      );
      expect(
        MilestoneCatalog.byId(
          MilestoneId.flameKeeper,
        ).tiers.map((tier) => tier.threshold).toList(),
        [3, 7, 14, 30, 60],
      );
    });

    test('earnedTier stops at the highest met threshold', () {
      final visit = MilestoneCatalog.byId(MilestoneId.visitViking);
      expect(visit.earnedTier(0), 0);
      expect(visit.earnedTier(4.999), 0);
      expect(visit.earnedTier(5), 1);
      expect(visit.earnedTier(15), 2);
      expect(visit.earnedTier(39.9), 2);
      expect(visit.earnedTier(40), 3);
      expect(visit.earnedTier(250), 5);
      expect(visit.earnedTier(9999), 5);

      final area = MilestoneCatalog.byId(MilestoneId.mapMagnate);
      expect(area.earnedTier(0.999), 0);
      expect(area.earnedTier(1), 1);
      expect(area.earnedTier(2.9), 1);
      expect(area.earnedTier(3), 2);
    });

    test('badgeAssetPath uses wire id and clamped tier', () {
      final definition = MilestoneCatalog.byId(MilestoneId.visitViking);
      expect(
        definition.badgeAssetPath(3),
        'assets/badges/milestones/visit_viking_3.png',
      );
      expect(
        definition.badgeAssetPath(0),
        'assets/badges/milestones/visit_viking_1.png',
      );
      expect(
        definition.badgeAssetPath(99),
        'assets/badges/milestones/visit_viking_5.png',
      );
    });

    test('MilestoneId wire round-trips', () {
      for (final id in MilestoneId.values) {
        expect(MilestoneId.fromWire(id.wireValue), id);
      }
      expect(MilestoneId.fromWire('nope'), isNull);
    });
  });

  group('MilestoneMetrics mapping', () {
    test('valueFor maps each milestone id to the correct field', () {
      final metrics = _metrics(
        areaKm2: 1.5,
        tilesUnlocked: 12,
        totalVisits: 8,
        journeyCount: 3,
        distanceKm: 22.5,
        journeyHours: 4.25,
        xpStreakDays: 6,
      );

      expect(metrics.valueFor(MilestoneId.mapMagnate), 1.5);
      expect(metrics.valueFor(MilestoneId.tileCollector), 12);
      expect(metrics.valueFor(MilestoneId.visitViking), 8);
      expect(metrics.valueFor(MilestoneId.tripTally), 3);
      expect(metrics.valueFor(MilestoneId.kilometreCrusader), 22.5);
      expect(metrics.valueFor(MilestoneId.clockedCruiser), 4.25);
      expect(metrics.valueFor(MilestoneId.flameKeeper), 6);
    });
  });

  group('MilestoneClaimState', () {
    test('fromMap parses claimed tiers and ignores non-numeric values', () {
      final state = MilestoneClaimState.fromMap(MilestoneId.tripTally, {
        'claimedTiers': [1, 2, 'x', 2, 3.0],
        'updatedAt': '2026-08-16T10:00:00.000',
      });

      expect(state.milestoneId, MilestoneId.tripTally);
      expect(state.claimedTiers, {1, 2, 3});
      expect(state.hasClaimed(2), isTrue);
      expect(state.hasClaimed(4), isFalse);
      expect(state.updatedAt, DateTime.parse('2026-08-16T10:00:00.000'));
    });

    test('toMap writes sorted claimed tiers', () {
      const state = MilestoneClaimState(
        milestoneId: MilestoneId.flameKeeper,
        claimedTiers: {3, 1},
      );
      final map = state.toMap();
      expect(map['claimedTiers'], [1, 3]);
      expect(map['updatedAt'], isA<String>());
    });
  });

  group('MilestoneProgressBuilder', () {
    const builder = MilestoneProgressBuilder();

    test('marks earned unclaimed tiers as claimable in order', () {
      final progress = builder.build(
        definition: MilestoneCatalog.byId(MilestoneId.visitViking),
        claimState: const MilestoneClaimState(
          milestoneId: MilestoneId.visitViking,
          claimedTiers: {1},
        ),
        metrics: _metrics(totalVisits: 40),
      );

      expect(progress.earnedTier, 3);
      expect(progress.claimableTiers, [2, 3]);
      expect(progress.nextClaimableTier, 2);
      expect(progress.displayTier, 2);
      expect(progress.pendingClaimCount, 2);
    });

    test('backfill exposes every earned tier when nothing claimed', () {
      final progress = builder.build(
        definition: MilestoneCatalog.byId(MilestoneId.tripTally),
        claimState: const MilestoneClaimState(
          milestoneId: MilestoneId.tripTally,
        ),
        metrics: _metrics(journeyCount: 15),
      );

      expect(progress.earnedTier, 3);
      expect(progress.claimableTiers, [1, 2, 3]);
      expect(progress.displayTier, 1);
    });

    test('shows next goal badge once all earned tiers are claimed', () {
      final progress = builder.build(
        definition: MilestoneCatalog.byId(MilestoneId.visitViking),
        claimState: const MilestoneClaimState(
          milestoneId: MilestoneId.visitViking,
          claimedTiers: {1, 2},
        ),
        metrics: _metrics(totalVisits: 15),
      );

      expect(progress.earnedTier, 2);
      expect(progress.nextClaimableTier, isNull);
      expect(progress.nextTier?.tier, 3);
      expect(progress.displayTier, 3);
    });

    test('progressToNext is fraction between previous and next threshold', () {
      final definition = MilestoneCatalog.byId(MilestoneId.visitViking);
      // Tier 2 at 15, tier 3 at 40 → span 25. Value 20 → (20-15)/25 = 0.2
      final mid = builder.build(
        definition: definition,
        claimState: const MilestoneClaimState(
          milestoneId: MilestoneId.visitViking,
          claimedTiers: {1, 2},
        ),
        metrics: _metrics(totalVisits: 20),
      );
      expect(mid.progressToNext, closeTo(0.2, 1e-9));

      final beforeFirst = builder.build(
        definition: definition,
        claimState: const MilestoneClaimState(
          milestoneId: MilestoneId.visitViking,
        ),
        metrics: _metrics(totalVisits: 2),
      );
      expect(beforeFirst.earnedTier, 0);
      expect(beforeFirst.nextTier?.tier, 1);
      expect(beforeFirst.progressToNext, closeTo(2 / 5, 1e-9));
      expect(beforeFirst.displayTier, 1);
    });

    test('isMaxed only when all tiers earned and claimed', () {
      final definition = MilestoneCatalog.byId(MilestoneId.flameKeeper);
      final almost = builder.build(
        definition: definition,
        claimState: const MilestoneClaimState(
          milestoneId: MilestoneId.flameKeeper,
          claimedTiers: {1, 2, 3, 4},
        ),
        metrics: _metrics(xpStreakDays: 60),
      );
      expect(almost.earnedTier, 5);
      expect(almost.isMaxed, isFalse);
      expect(almost.nextClaimableTier, 5);
      expect(almost.displayTier, 5);

      final maxed = builder.build(
        definition: definition,
        claimState: const MilestoneClaimState(
          milestoneId: MilestoneId.flameKeeper,
          claimedTiers: {1, 2, 3, 4, 5},
        ),
        metrics: _metrics(xpStreakDays: 60),
      );
      expect(maxed.isMaxed, isTrue);
      expect(maxed.nextTier, isNull);
      expect(maxed.progressToNext, 1.0);
      expect(maxed.displayTier, 5);
    });

    test('buildAll returns one progress entry per catalog milestone', () {
      final all = builder.buildAll(
        claims: const {},
        metrics: _metrics(totalVisits: 5, tilesUnlocked: 5),
      );
      expect(all, hasLength(MilestoneCatalog.all.length));
      expect(
        all.map((item) => item.definition.id).toSet(),
        MilestoneId.values.toSet(),
      );
    });
  });

  group('milestone formatting', () {
    test('formats count, distance, hours, and days for UI labels', () {
      expect(formatMilestoneValue(12, MilestoneMetricUnit.count), '12');
      expect(
        formatMilestoneValue(9.4, MilestoneMetricUnit.kilometres),
        '9.40 km',
      );
      expect(
        formatMilestoneValue(12.34, MilestoneMetricUnit.kilometres),
        '12.3 km',
      );
      expect(
        formatMilestoneValue(150.2, MilestoneMetricUnit.kilometres),
        '150 km',
      );
      expect(formatMilestoneValue(4.2, MilestoneMetricUnit.hours), '4.2h');
      expect(formatMilestoneValue(12.7, MilestoneMetricUnit.hours), '13h');
      expect(formatMilestoneValue(7, MilestoneMetricUnit.days), '7d');
      expect(formatMilestoneThreshold(40, MilestoneMetricUnit.count), '40');
    });
  });
}
