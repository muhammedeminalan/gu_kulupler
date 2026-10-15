import 'dart:async';

import 'package:gu_data/gu_data.dart';

/// Emülatör ortamının Remote Config'i (W-53, CD-131): **hiçbir yere bağlanmaz**.
///
/// Remote Config'in emülatörü yoktur; `ENV=emulator` iken gerçek SDK
/// kullanılsaydı varsayılan (gerçek) Firebase uygulamasına istek giderdi.
/// Bu uygulama yalnızca kod içi varsayılanları döndürür (`Limits`): güncelleme
/// kapısı kapalı, bakım mesajı yok.
final class EmulatorRemoteConfigService implements RemoteConfigService {
  /// Varsayılan değerlerle çalışan yerel servis.
  const EmulatorRemoteConfigService();

  @override
  Future<RemoteConfigResult<bool>> fetchAndActivate() async =>
      const FirebaseSuccess(false);

  @override
  int get minSupportedBuild => 0;

  @override
  String get maintenanceMessage => '';

  @override
  int get announcementDailyLimit => Limits.announcementDailyLimit;

  @override
  int get reapplyCooldownDays => Limits.reapplyCooldown.inDays;

  @override
  Stream<void> get onConfigUpdated => const Stream<void>.empty();
}

/// Emülatör ortamının çökme raporlayıcısı (W-53, CD-131): **hiçbir yere
/// göndermez** ve hiçbir şey yapmaz. Crashlytics'in emülatörü yoktur; konsol
/// çıktısını tek çağıran `AppErrorHandler` zaten yazar (aynı hata ikinci kez
/// yazılmaz — T-44 · D2-12).
final class EmulatorCrashService implements CrashService {
  /// Etkisiz yerel servis.
  const EmulatorCrashService();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {}

  @override
  void log(String message) {
    // `AppLogger` debug/profile derlemede satırı zaten konsola yazar.
  }

  @override
  Future<void> setUserId(String? uid) async {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}

/// Emülatör ortamının push servisi (T-42, W-53, CD-165): **gerçek FCM'e
/// bağlanmaz**. FCM'in emülatörü yoktur; `firebase_messaging` varsayılan
/// (gerçek) Firebase uygulamasına kayıt olurdu. Bu uygulama sabit bir sahte
/// jeton ([fakeToken]) döndürür: jeton yazımı (`fcmTokens`, Rules) ve
/// fonksiyon emülatörünün kayıt tutan göndericisi yerelde sınanabilir.
/// Dokunma akışları boştur; izin varsayılır.
final class EmulatorMessagingService implements MessagingService {
  /// Yalnızca yerelde çalışan servis.
  const EmulatorMessagingService();

  /// Emülatörde yazılan sahte jeton (gerçek cihaza karşılık gelmez).
  static const String fakeToken = 'emulator-fcm-token';

  @override
  Future<bool> isAuthorized() async => true;

  @override
  Future<String?> token() async => fakeToken;

  @override
  Stream<String> get onTokenRefresh => const Stream<String>.empty();

  @override
  Future<bool> invalidateToken() async => true;

  @override
  Future<Map<String, String>?> initialMessageData() async => null;

  @override
  Stream<Map<String, String>> get openedMessageData =>
      const Stream<Map<String, String>>.empty();

  @override
  Future<void> configureForeground() async {}
}
