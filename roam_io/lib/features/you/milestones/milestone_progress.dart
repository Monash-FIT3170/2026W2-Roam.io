/*
 * Author: Alvin Liong
 * Last Modified: 16/08/2026
 * Description:
 *   Persisted claim state and live progress for a single milestone.
 */

import 'milestone_catalog.dart';

/// Claimed tiers for one milestone at `profiles/{uid}/milestones/{id}`.
class MilestoneClaimState {
  const MilestoneClaimState({
    required this.milestoneId,
    this.claimedTiers = const <int>{},
    this.updatedAt,
  });

  final MilestoneId milestoneId;
  final Set<int> claimedTiers;
  final DateTime? updatedAt;

  bool hasClaimed(int tier) => claimedTiers.contains(tier);

  factory MilestoneClaimState.fromMap(
    MilestoneId milestoneId,
    Map<String, dynamic>? data,
  ) {
    final raw = data?['claimedTiers'];
    final claimed = <int>{};
    if (raw is List) {
      for (final value in raw) {
        if (value is num) claimed.add(value.toInt());
      }
    }
    return MilestoneClaimState(
      milestoneId: milestoneId,
      claimedTiers: claimed,
      updatedAt: DateTime.tryParse(data?['updatedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    final sorted = claimedTiers.toList()..sort();
    return <String, dynamic>{
      'claimedTiers': sorted,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}

/// Snapshot of the metric values milestones read from.
class MilestoneMetrics {
  const MilestoneMetrics({
    required this.areaKm2,
    required this.tilesUnlocked,
    required this.totalVisits,
    required this.journeyCount,
    required this.distanceKm,
    required this.journeyHours,
    required this.xpStreakDays,
  });

  final double areaKm2;
  final int tilesUnlocked;
  final int totalVisits;
  final int journeyCount;
  final double distanceKm;
  final double journeyHours;
  final int xpStreakDays;

  double valueFor(MilestoneId id) {
    switch (id) {
      case MilestoneId.mapMagnate:
        return areaKm2;
      case MilestoneId.tileCollector:
        return tilesUnlocked.toDouble();
      case MilestoneId.visitViking:
        return totalVisits.toDouble();
      case MilestoneId.tripTally:
        return journeyCount.toDouble();
      case MilestoneId.kilometreCrusader:
        return distanceKm;
      case MilestoneId.clockedCruiser:
        return journeyHours;
      case MilestoneId.flameKeeper:
        return xpStreakDays.toDouble();
    }
  }
}

/// Computed progress for one milestone, ready for UI.
class MilestoneProgress {
  const MilestoneProgress({
    required this.definition,
    required this.currentValue,
    required this.earnedTier,
    required this.claimedTiers,
    required this.claimableTiers,
    required this.displayTier,
    required this.nextTier,
    required this.progressToNext,
  });

  final MilestoneDefinition definition;
  final double currentValue;
  final int earnedTier;
  final Set<int> claimedTiers;

  /// Earned but not yet claimed, ascending.
  final List<int> claimableTiers;

  /// Badge tier to show: next claimable, else next goal tier, else highest claimed.
  final int displayTier;

  /// Next tier still locked by metric, or null at max.
  final MilestoneTierDefinition? nextTier;

  /// 0–1 progress toward [nextTier] (1 if maxed).
  final double progressToNext;

  int? get nextClaimableTier =>
      claimableTiers.isEmpty ? null : claimableTiers.first;

  int get pendingClaimCount => claimableTiers.length;

  bool get isMaxed =>
      earnedTier >= definition.maxTier &&
      claimedTiers.length >= definition.maxTier;
}

/// Builds [MilestoneProgress] from definitions + claims + live metrics.
class MilestoneProgressBuilder {
  const MilestoneProgressBuilder();

  MilestoneProgress build({
    required MilestoneDefinition definition,
    required MilestoneClaimState claimState,
    required MilestoneMetrics metrics,
  }) {
    final currentValue = metrics.valueFor(definition.id);
    final earnedTier = definition.earnedTier(currentValue);
    final claimed = claimState.claimedTiers;
    final claimable = <int>[
      for (var tier = 1; tier <= earnedTier; tier++)
        if (!claimed.contains(tier)) tier,
    ];

    MilestoneTierDefinition? nextTier;
    var progressToNext = 1.0;
    if (earnedTier < definition.maxTier) {
      nextTier = definition.tierDefinition(earnedTier + 1);
      final previousThreshold = earnedTier == 0
          ? 0.0
          : definition.tierDefinition(earnedTier).threshold;
      final span = nextTier.threshold - previousThreshold;
      progressToNext = span <= 0
          ? 1.0
          : ((currentValue - previousThreshold) / span).clamp(0.0, 1.0);
    }

    final highestClaimed = claimed.isEmpty
        ? 1
        : claimed.reduce((a, b) => a > b ? a : b);
    final displayTier = claimable.isNotEmpty
        ? claimable.first
        : (nextTier?.tier ?? highestClaimed);

    return MilestoneProgress(
      definition: definition,
      currentValue: currentValue,
      earnedTier: earnedTier,
      claimedTiers: claimed,
      claimableTiers: claimable,
      displayTier: displayTier,
      nextTier: nextTier,
      progressToNext: progressToNext,
    );
  }

  List<MilestoneProgress> buildAll({
    required Map<MilestoneId, MilestoneClaimState> claims,
    required MilestoneMetrics metrics,
  }) {
    return [
      for (final definition in MilestoneCatalog.all)
        build(
          definition: definition,
          claimState:
              claims[definition.id] ??
              MilestoneClaimState(milestoneId: definition.id),
          metrics: metrics,
        ),
    ];
  }
}
