import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Substituir pela API key real do Google Maps antes do primeiro build iOS.
    // Idealmente injetar via Info.plist + xcconfig em vez de hardcode.
    if let key = ProcessInfo.processInfo.environment["MAPS_API_KEY"] {
      GMSServices.provideAPIKey(key)
    } else if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String, !key.isEmpty {
      GMSServices.provideAPIKey(key)
    } else {
      print("⚠️ MAPS_API_KEY não configurada. Mapa não vai renderizar.")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
