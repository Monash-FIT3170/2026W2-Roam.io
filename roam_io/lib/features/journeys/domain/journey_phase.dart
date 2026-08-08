/*
 * Author: GitHub Copilot
 * Last Modified: 30/07/2026
 * Description:
 *   Defines the phases of a journey lifecycle for state machine management
 *   in JourneyController.
 */

/// The phases of a journey's lifecycle.
enum JourneyPhase {
  /// No journey active - user can start a new one.
  idle,

  /// User is setting up journey parameters (start location, transport mode).
  settingUp,

  /// Journey is actively tracking user movement.
  tracking,

  /// User ended tracking, now selecting end location.
  completing,

  /// Journey complete, showing summary for review/edit before saving.
  reviewing,
}
