import Flutter
import GoogleMaps
import UIKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var liveActivityChannel: FlutterMethodChannel?
  private var pendingLiveActivityAction: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyA9pbYpCNQKScCysC7xYYyICvk1dASCU2M")

    // Allows flutter_local_notifications to present notifications while the
    // application is in the foreground.
    UNUserNotificationCenter.current().delegate =
      self as? UNUserNotificationCenterDelegate

    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }

  func didInitializeImplicitFlutterEngine(
    _ engineBridge: FlutterImplicitEngineBridge
  ) {
    // Required when notification actions need a background Flutter engine.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.fit3170.roamio/live_activity",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    liveActivityChannel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleLiveActivityCall(call, result: result)
    }

  }

  /// Receives deep links from the Live Activity action controls.
  @discardableResult
  func handleLiveActivityURL(_ url: URL) -> Bool {
    guard url.scheme == "roamio", url.host == "journey" else {
      return false
    }

    let action = url.pathComponents.last ?? "open"
    guard ["pause", "resume", "stop", "open"].contains(action) else {
      return false
    }

    dispatchLiveActivityAction(action)
    return true
  }

  private func dispatchLiveActivityAction(_ action: String) {
    pendingLiveActivityAction = action
    guard let liveActivityChannel else { return }

    liveActivityChannel.invokeMethod(
      "onAction",
      arguments: ["action": action]
    )
  }

  private func handleLiveActivityCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    let arguments = call.arguments as? [String: Any] ?? [:]

    if call.method == "isSupported" {
      if #available(iOS 16.2, *) {
        result(JourneyLiveActivityManager.shared.isSupported)
      } else {
        result(false)
      }
      return
    }

    if call.method == "consumePendingAction" {
      result(pendingLiveActivityAction)
      pendingLiveActivityAction = nil
      return
    }

    if call.method == "ackPendingAction" {
      pendingLiveActivityAction = nil
      result(nil)
      return
    }

    guard #available(iOS 16.2, *) else {
      result(
        FlutterError(
          code: "live_activity_unavailable",
          message: "Live Activities require iOS 16.2 or later.",
          details: nil
        )
      )
      return
    }

    switch call.method {
    case "start":
      Task {
        do {
          let activityId = try await JourneyLiveActivityManager.shared.start(
            arguments: arguments
          )
          result(activityId)
        } catch {
          result(
            FlutterError(
              code: "live_activity_start_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }

    case "update", "pause", "resume":
      Task {
        await JourneyLiveActivityManager.shared.update(arguments: arguments)
        result(nil)
      }

    case "stop":
      Task {
        await JourneyLiveActivityManager.shared.end(arguments: arguments)
        result(nil)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
