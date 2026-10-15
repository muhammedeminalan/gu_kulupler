import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // T-23 (PLAN §5.6.1): flutter_local_notifications — ön planda bildirim ve dokunma.
    // T-42 (Mod F): firebase_messaging ek kod istemez (swizzling açık); kurulumda bu
    // temsilciyi saklayıp zincirler — yerel hatırlatıcı dokunuşu ve push dokunuşu ikisi de
    // iletilir. APNs kaydını eklenti yapar; izin PermissionService'ten (tek pencere).
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
