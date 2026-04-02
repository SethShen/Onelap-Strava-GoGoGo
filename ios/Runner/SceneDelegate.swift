import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private let sharedFitIntakeBridge = SharedFitIntakeBridge.shared

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    if let flutterViewController = window?.rootViewController as? FlutterViewController {
      sharedFitIntakeBridge.configure(binaryMessenger: flutterViewController.binaryMessenger)
    }

    let urls = connectionOptions.urlContexts.map { $0.url }
    if !urls.isEmpty {
      sharedFitIntakeBridge.publishFiles(urls: urls, sourcePlatform: "ios", storeAsInitial: true)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: urlContexts)
    sharedFitIntakeBridge.publishFiles(
      urls: urlContexts.map { $0.url },
      sourcePlatform: "ios",
      storeAsInitial: false
    )
  }
}
