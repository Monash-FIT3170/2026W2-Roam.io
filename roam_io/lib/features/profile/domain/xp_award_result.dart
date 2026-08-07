/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Explicit result of an XP award so callers can distinguish canonical
 *   progression success from optional XP history recording. History failure
 *   never marks the award as failed once aggregate XP has been persisted.
 */

/// Outcome of awarding XP to a profile.
class XpAwardResult {
  const XpAwardResult({
    required this.succeeded,
    required this.amount,
    required this.previousXp,
    required this.newXp,
    required this.previousLevel,
    required this.newLevel,
    required this.didLevelUp,
    required this.historyRecorded,
  });

  /// Whether the canonical profiles/{uid} XP + level update succeeded.
  final bool succeeded;

  /// XP amount requested for this award (0 when the award failed).
  final int amount;

  final int previousXp;
  final int newXp;
  final int previousLevel;
  final int newLevel;

  /// True when [newLevel] is greater than [previousLevel] after a successful award.
  final bool didLevelUp;

  /// True when a timestamped xp_events document was written after progression.
  ///
  /// May be false even when [succeeded] is true; analytics history is secondary.
  final bool historyRecorded;

  /// Canonical progression failed; no XP was persisted.
  factory XpAwardResult.failed({int amount = 0}) {
    return XpAwardResult(
      succeeded: false,
      amount: amount,
      previousXp: 0,
      newXp: 0,
      previousLevel: 1,
      newLevel: 1,
      didLevelUp: false,
      historyRecorded: false,
    );
  }

  /// Canonical progression succeeded; [historyRecorded] reflects the secondary write.
  factory XpAwardResult.success({
    required int amount,
    required int previousXp,
    required int newXp,
    required int previousLevel,
    required int newLevel,
    required bool historyRecorded,
  }) {
    return XpAwardResult(
      succeeded: true,
      amount: amount,
      previousXp: previousXp,
      newXp: newXp,
      previousLevel: previousLevel,
      newLevel: newLevel,
      didLevelUp: newLevel > previousLevel,
      historyRecorded: historyRecorded,
    );
  }
}
