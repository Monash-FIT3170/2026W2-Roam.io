import ActivityKit
import Foundation

/// Owns the ActivityKit lifecycle for the currently tracked Journey.
@available(iOS 16.2, *)
final class JourneyLiveActivityManager {
  static let shared = JourneyLiveActivityManager()

  private init() {}

  var isSupported: Bool {
    ActivityAuthorizationInfo().areActivitiesEnabled
  }

  func start(arguments: [String: Any]) async throws -> String {
    let attributes = JourneyActivityAttributes(
      journeyId: string(arguments, "journeyId", fallback: "journey"),
      transportMode: string(arguments, "transportMode", fallback: "Journey"),
      startTimeMillis: int64(arguments, "startTimeMillis")
    )
    let content = activityContent(from: arguments)

    if let existing = Activity<JourneyActivityAttributes>.activities.first(
      where: { $0.attributes.journeyId == attributes.journeyId }
    ) {
      await existing.update(content)
      return existing.id
    }

    let activity = try Activity.request(
      attributes: attributes,
      content: content,
      pushType: nil
    )
    return activity.id
  }

  func update(arguments: [String: Any]) async {
    guard let activity = activity(from: arguments) else { return }
    await activity.update(activityContent(from: arguments))
  }

  func end(arguments: [String: Any]) async {
    guard let activity = activity(from: arguments) else { return }
    await activity.end(
      activityContent(from: arguments),
      dismissalPolicy: .immediate
    )
  }

  private func activity(
    from arguments: [String: Any]
  ) -> Activity<JourneyActivityAttributes>? {
    if let activityId = arguments["activityId"] as? String,
       let matching = Activity<JourneyActivityAttributes>.activities.first(
         where: { $0.id == activityId }
       ) {
      return matching
    }

    if let journeyId = arguments["journeyId"] as? String,
       let matching = Activity<JourneyActivityAttributes>.activities.first(
         where: { $0.attributes.journeyId == journeyId }
       ) {
      return matching
    }

    return Activity<JourneyActivityAttributes>.activities.first
  }

  private func activityContent(
    from arguments: [String: Any]
  ) -> ActivityContent<JourneyActivityAttributes.ContentState> {
    let state = JourneyActivityAttributes.ContentState(
      elapsedSeconds: integer(arguments, "elapsedSeconds"),
      distanceMeters: double(arguments, "distanceMeters"),
      tilesUnlocked: integer(arguments, "tilesUnlocked"),
      xpEarned: integer(arguments, "xpEarned"),
      isPaused: boolean(arguments, "isPaused")
    )

    // Mark content stale if the app has not refreshed it for ninety seconds.
    return ActivityContent(
      state: state,
      staleDate: Date().addingTimeInterval(90)
    )
  }

  private func string(
    _ arguments: [String: Any],
    _ key: String,
    fallback: String
  ) -> String {
    arguments[key] as? String ?? fallback
  }

  private func integer(_ arguments: [String: Any], _ key: String) -> Int {
    (arguments[key] as? NSNumber)?.intValue ?? 0
  }

  private func int64(_ arguments: [String: Any], _ key: String) -> Int64 {
    (arguments[key] as? NSNumber)?.int64Value ?? 0
  }

  private func double(_ arguments: [String: Any], _ key: String) -> Double {
    (arguments[key] as? NSNumber)?.doubleValue ?? 0
  }

  private func boolean(_ arguments: [String: Any], _ key: String) -> Bool {
    (arguments[key] as? NSNumber)?.boolValue ?? false
  }
}
