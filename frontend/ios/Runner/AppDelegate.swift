import Flutter
import UIKit

// UIScene lifecycle (required on iOS 27+): the window is owned by
// FlutterSceneDelegate (see UIApplicationSceneManifest in Info.plist), and
// plugins register on the implicit engine once it exists. URL opens (for
// example password-reset links) reach plugins through the scene delegate.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
