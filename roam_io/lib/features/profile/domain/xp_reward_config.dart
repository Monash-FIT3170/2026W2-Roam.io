/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Central numeric XP reward constants for Roam.io (flat visit rewards vs
 *   area-based tile unlock rewards defined elsewhere).
 */

/// Central configuration for XP reward amounts used across features.
///
/// Visit XP is a **flat** reward granted only after a visit document is saved.
/// Tile unlock XP stays **area-based** (see tile unlock / map unlock services).
class XpRewardConfig {
  XpRewardConfig._();

  /// Fixed XP awarded for each successfully persisted place visit.
  ///
  /// Not derived from polygon area, distance, or place metadata.
  static const int visitXpReward = 50;
}
