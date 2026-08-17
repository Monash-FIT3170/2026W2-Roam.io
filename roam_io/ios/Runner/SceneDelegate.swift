import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts {
      if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
         appDelegate.handleLiveActivityURL(context.url) {
        continue
      }
    }

    // Preserve Flutter/plugin deep-link handling for any URLs not consumed by
    // the Journey Live Activity bridge.
    super.scene(scene, openURLContexts: URLContexts)
  }
}
