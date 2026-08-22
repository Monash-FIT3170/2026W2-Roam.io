/*
 * Author: Alvin Liong
 * Last Modified: 16/08/2026
 * Description:
 *   Catalog of exploration milestones, tier thresholds, and scaled XP rewards.
 */

/// Stable milestone identifiers (also used in Firestore doc ids and asset names).
enum MilestoneId {
  mapMagnate,
  tileCollector,
  visitViking,
  tripTally,
  kilometreCrusader,
  clockedCruiser,
  flameKeeper;

  String get wireValue {
    switch (this) {
      case MilestoneId.mapMagnate:
        return 'map_magnate';
      case MilestoneId.tileCollector:
        return 'tile_collector';
      case MilestoneId.visitViking:
        return 'visit_viking';
      case MilestoneId.tripTally:
        return 'trip_tally';
      case MilestoneId.kilometreCrusader:
        return 'kilometre_crusader';
      case MilestoneId.clockedCruiser:
        return 'clocked_cruiser';
      case MilestoneId.flameKeeper:
        return 'flame_keeper';
    }
  }

  static MilestoneId? fromWire(String? value) {
    for (final id in MilestoneId.values) {
      if (id.wireValue == value) return id;
    }
    return null;
  }
}

/// How a milestone metric is measured for progress UI.
enum MilestoneMetricUnit { count, kilometres, hours, days }

/// One tier rung inside a milestone (1–5).
class MilestoneTierDefinition {
  const MilestoneTierDefinition({
    required this.tier,
    required this.threshold,
    required this.xpReward,
  });

  final int tier;
  final double threshold;
  final int xpReward;
}

/// Static definition for a milestone track.
class MilestoneDefinition {
  const MilestoneDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.unit,
    required this.tiers,
  });

  final MilestoneId id;
  final String title;
  final String subtitle;
  final MilestoneMetricUnit unit;
  final List<MilestoneTierDefinition> tiers;

  int get maxTier => tiers.length;

  MilestoneTierDefinition tierDefinition(int tier) {
    return tiers.firstWhere((entry) => entry.tier == tier);
  }

  /// Highest tier whose threshold is met by [currentValue], or 0 if none.
  int earnedTier(double currentValue) {
    var earned = 0;
    for (final tier in tiers) {
      if (currentValue + 1e-9 >= tier.threshold) {
        earned = tier.tier;
      } else {
        break;
      }
    }
    return earned;
  }

  /// Asset path for a tier badge (user-supplied art).
  String badgeAssetPath(int tier) {
    final safeTier = tier.clamp(1, maxTier);
    return 'assets/badges/milestones/${id.wireValue}_$safeTier.png';
  }
}

/// XP for milestone tier [tier] using scaled curve `100 × tier²`.
int milestoneXpForTier(int tier) => 100 * tier * tier;

/// Built-in milestone catalog (5 tiers each).
class MilestoneCatalog {
  const MilestoneCatalog._();

  static const int tierCount = 5;

  static final List<MilestoneDefinition> all = [
    MilestoneDefinition(
      id: MilestoneId.mapMagnate,
      title: 'Map Magnate',
      subtitle: 'Area revealed on the map',
      unit: MilestoneMetricUnit.kilometres,
      tiers: _areaTiers,
    ),
    MilestoneDefinition(
      id: MilestoneId.tileCollector,
      title: 'Tile Collector',
      subtitle: 'Tiles unlocked',
      unit: MilestoneMetricUnit.count,
      tiers: _countTiers(const [5, 15, 40, 100, 250]),
    ),
    MilestoneDefinition(
      id: MilestoneId.visitViking,
      title: 'Visit Viking',
      subtitle: 'Places visited',
      unit: MilestoneMetricUnit.count,
      tiers: _countTiers(const [5, 15, 40, 100, 250]),
    ),
    MilestoneDefinition(
      id: MilestoneId.tripTally,
      title: 'Trip Tally',
      subtitle: 'Journeys completed',
      unit: MilestoneMetricUnit.count,
      tiers: _countTiers(const [1, 5, 15, 40, 100]),
    ),
    MilestoneDefinition(
      id: MilestoneId.kilometreCrusader,
      title: 'Kilometre Crusader',
      subtitle: 'Distance travelled on journeys',
      unit: MilestoneMetricUnit.kilometres,
      tiers: _countTiers(const [5, 25, 75, 200, 500]),
    ),
    MilestoneDefinition(
      id: MilestoneId.clockedCruiser,
      title: 'Clocked Cruiser',
      subtitle: 'Time spent on journeys',
      unit: MilestoneMetricUnit.hours,
      tiers: _countTiers(const [1, 5, 15, 40, 100]),
    ),
    MilestoneDefinition(
      id: MilestoneId.flameKeeper,
      title: 'Flame Keeper',
      subtitle: 'Current XP earn streak',
      unit: MilestoneMetricUnit.days,
      tiers: _countTiers(const [3, 7, 14, 30, 60]),
    ),
  ];

  /// Area thresholds in km² (stored/compared as km² in evaluator).
  static final List<MilestoneTierDefinition> _areaTiers = [
    for (var i = 0; i < tierCount; i++)
      MilestoneTierDefinition(
        tier: i + 1,
        threshold: const [1.0, 3.0, 5.0, 15.0, 50.0][i],
        xpReward: milestoneXpForTier(i + 1),
      ),
  ];

  static List<MilestoneTierDefinition> _countTiers(List<num> thresholds) {
    return [
      for (var i = 0; i < thresholds.length; i++)
        MilestoneTierDefinition(
          tier: i + 1,
          threshold: thresholds[i].toDouble(),
          xpReward: milestoneXpForTier(i + 1),
        ),
    ];
  }

  static MilestoneDefinition byId(MilestoneId id) {
    return all.firstWhere((definition) => definition.id == id);
  }
}
