/*
 * Author: Alvin Liong
 * Last Modified: 16/08/2026
 * Description:
 *   Backward-compatible entry for the XP progress celebration overlay.
 */

import 'package:flutter/material.dart';

import '../../features/profile/domain/pending_xp_celebration.dart';
import '../../features/profile/domain/profile_model.dart';
import 'xp_progress_celebration.dart';

/// Legacy wrapper around [XpProgressCelebration] for older call sites/tests.
class LevelUpCelebration extends StatelessWidget {
  const LevelUpCelebration({
    super.key,
    required this.newLevel,
    required this.onDismiss,
    this.rewardToastMessage,
    this.previousXp,
    this.newXp,
    this.previousLevel,
  });

  final int newLevel;
  final VoidCallback onDismiss;
  final String? rewardToastMessage;
  final int? previousXp;
  final int? newXp;
  final int? previousLevel;

  @override
  Widget build(BuildContext context) {
    final fromLevel = previousLevel ?? (newLevel > 1 ? newLevel - 1 : 1);
    final celebration = PendingXpCelebration(
      previousXp: previousXp ?? ProfileModel.totalXpToReachLevel(fromLevel),
      newXp: newXp ?? ProfileModel.totalXpToReachLevel(newLevel),
      previousLevel: fromLevel,
      newLevel: newLevel,
      rewardToastMessage: rewardToastMessage,
    );
    return XpProgressCelebration(
      celebration: celebration,
      onDismiss: onDismiss,
    );
  }
}
