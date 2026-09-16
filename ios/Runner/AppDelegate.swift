import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Força o registro remoto de push já no boot do app, em vez de depender
    // só do timing do plugin firebase_messaging (que às vezes não dispara o
    // registro nativo a tempo, deixando o APNs token nulo pra sempre —
    // "apns-token-not-set"). Mesmo fix aplicado no VetVem Pro (2026-09-15),
    // confirmado funcionando — mesma causa raiz aqui.
    application.registerForRemoteNotifications()
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
