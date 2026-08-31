/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 19 August 2026
 * Description:
 *   Shared ActivityKit model used by both Runner and the Live Activity
 *   extension.
 */

import ActivityKit
import Foundation

/// Shared ActivityKit model used by both Runner and the Live Activity extension.
@available(iOS 16.1, *)
struct JourneyActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var elapsedSeconds: Int
    var distanceMeters: Double
    var tilesUnlocked: Int
    var xpEarned: Int
    var isPaused: Bool
  }

  var journeyId: String
  var transportMode: String
  var startTimeMillis: Int64
}
