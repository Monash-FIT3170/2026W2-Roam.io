/*
 * Author: Alvin Liong
 * Last Modified: 16/08/2026
 * Description:
 *   Payload for the full-screen XP progress celebration overlay.
 */

import 'xp_award_result.dart';

/// XP transition shown after a milestone claim or level-up.
class PendingXpCelebration {
  const PendingXpCelebration({
    required this.previousXp,
    required this.newXp,
    required this.previousLevel,
    required this.newLevel,
    this.rewardToastMessage,
  });

  final int previousXp;
  final int newXp;
  final int previousLevel;
  final int newLevel;
  final String? rewardToastMessage;

  bool get didLevelUp => newLevel > previousLevel;

  factory PendingXpCelebration.fromAward(
    XpAwardResult result, {
    String? rewardToastMessage,
  }) {
    return PendingXpCelebration(
      previousXp: result.previousXp,
      newXp: result.newXp,
      previousLevel: result.previousLevel,
      newLevel: result.newLevel,
      rewardToastMessage: rewardToastMessage,
    );
  }

  PendingXpCelebration withRewardToast(String? message) {
    return PendingXpCelebration(
      previousXp: previousXp,
      newXp: newXp,
      previousLevel: previousLevel,
      newLevel: newLevel,
      rewardToastMessage: message ?? rewardToastMessage,
    );
  }
}
