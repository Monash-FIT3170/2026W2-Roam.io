import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

struct RoamLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: JourneyActivityAttributes.self) { context in
      lockScreenView(context)
        .activityBackgroundTint(Color.black.opacity(0.88))
        .activitySystemActionForegroundColor(.white)
        .widgetURL(URL(string: "roamio://journey/open"))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(
            context.attributes.transportMode,
            systemImage: "location.fill"
          )
          .font(.caption.bold())
        }

        DynamicIslandExpandedRegion(.trailing) {
          Text(formatDistance(context.state.distanceMeters))
            .font(.caption.bold())
        }

        DynamicIslandExpandedRegion(.center) {
          Text(context.state.isPaused ? "Journey Paused" : "Journey in Progress")
            .font(.headline)
        }

        DynamicIslandExpandedRegion(.bottom) {
          VStack(spacing: 8) {
            HStack {
              timeMetric(context.state)
              Spacer()
              metric("Tiles", "\(context.state.tilesUnlocked)")
              Spacer()
              metric("XP", "\(context.state.xpEarned)")
            }
            actionLinks(isPaused: context.state.isPaused)
          }
        }
      } compactLeading: {
        Image(systemName: context.state.isPaused ? "pause.fill" : "location.fill")
      } compactTrailing: {
        Text(formatCompactDistance(context.state.distanceMeters))
          .font(.caption2.bold())
      } minimal: {
        Image(systemName: context.state.isPaused ? "pause.fill" : "location.fill")
      }
      .widgetURL(URL(string: "roamio://journey/open"))
      .keylineTint(.green)
    }
  }

  @ViewBuilder
  private func lockScreenView(
    _ context: ActivityViewContext<JourneyActivityAttributes>
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(context.state.isPaused ? "Journey Paused" : "Journey in Progress")
            .font(.headline)
          Text(context.attributes.transportMode)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: context.state.isPaused ? "pause.circle.fill" : "location.circle.fill")
          .font(.title2)
      }

      HStack {
        metric("Distance", formatDistance(context.state.distanceMeters))
        Spacer()
        timeMetric(context.state)
        Spacer()
        metric("Tiles", "\(context.state.tilesUnlocked)")
        Spacer()
        metric("XP", "\(context.state.xpEarned)")
      }

      actionLinks(isPaused: context.state.isPaused)
    }
    .padding()
  }

  private func metric(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(.subheadline.bold())
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private func timeMetric(
    _ state: JourneyActivityAttributes.ContentState
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      if state.isPaused {
        Text(formatDuration(state.elapsedSeconds))
          .font(.subheadline.bold())
      } else {
        // Let SwiftUI advance the elapsed timer locally so ActivityKit does
        // not require an update every second.
        Text(
          Date(timeIntervalSinceNow: -TimeInterval(state.elapsedSeconds)),
          style: .timer
        )
        .font(.subheadline.bold())
      }
      Text("Time")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  private func actionLinks(isPaused: Bool) -> some View {
    HStack(spacing: 12) {
      Link(
        destination: URL(
          string: isPaused ? "roamio://journey/resume" : "roamio://journey/pause"
        )!
      ) {
        Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)

      Link(destination: URL(string: "roamio://journey/stop")!) {
        Label("Stop", systemImage: "stop.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
    }
    .font(.caption.bold())
  }

  private func formatDistance(_ meters: Double) -> String {
    if meters >= 1000 {
      return String(format: "%.2f km", meters / 1000)
    }
    return "\(Int(meters.rounded())) m"
  }

  private func formatCompactDistance(_ meters: Double) -> String {
    if meters >= 1000 {
      return String(format: "%.1fK", meters / 1000)
    }
    return "\(Int(meters.rounded()))m"
  }

  private func formatDuration(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
  }
}
