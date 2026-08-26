/*
 * Author: GitHub Copilot
 * Last Modified: 13/08/2026
 * Description:
 *   Defines the phases of the Journey lifecycle used by JourneyController.
 */

/// Represents the current phase of the Journey workflow.
enum JourneyPhase {
  /// No journey active - user can start a new one.
  idle,

  /// User is setting up journey parameters (start location, transport mode).
  settingUp,

  /// Journey is actively tracking user movement.
  tracking,

  /// Journey remains active, but location accumulation and elapsed time are
  /// temporarily paused.
  paused,

  /// Tracking has ended and the user is selecting the final location.
  completing,

  /// Journey complete, showing summary for review/edit before saving.
  reviewing,
}
