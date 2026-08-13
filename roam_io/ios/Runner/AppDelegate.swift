import Flutter
import UIKit
import GoogleMaps
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyA9pbYpCNQKScCysC7xYYyICvk1dASCU2M")

    // Required so flutter_local_notifications can handle notifications
    // while the application is running in the foreground.
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
    // Required for notification actions that are handled while the app is
    // backgrounded or terminated.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    GeneratedPluginRegistrant.register(
      with: engineBridge.pluginRegistry
    )
  }
}
