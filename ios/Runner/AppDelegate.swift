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
    // H-25: uygulama simgesi rozeti (MessagingService.setBadge — `gu_kulupler/badge`).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GuBadge") {
      let channel = FlutterMethodChannel(name: "gu_kulupler/badge", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "set" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let count = max(0, (call.arguments as? Int) ?? 0)
        if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
        } else {
          UIApplication.shared.applicationIconBadgeNumber = count
        }
        result(nil)
      }
    }
  }
}
