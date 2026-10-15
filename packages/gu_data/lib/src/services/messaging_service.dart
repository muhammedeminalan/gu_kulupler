import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

/// Push (FCM) cihaz servisi — T-42, Mod F (CD-62 adı, CD-165).
///
/// * **İzin istemez:** bildirim izni tek kaynaktan, `PermissionService
///   .requestNotifications()` ile istenir (DLG-03 / NTF-01 `enable`; iki
///   ayrı sistem penceresi açılmaz). Bu servis yalnızca izin durumunu okur
///   ([isAuthorized]).
/// * Jeton: [token] + [onTokenRefresh]; çıkışta [invalidateToken] (FCM
///   `deleteToken` — yerel jeton geçersizleşir; veri silme değildir). Jetonun
///   `users/{uid}/private/account.fcmTokens` yazımı `UserRepository`'dedir
///   (`upsertFcmToken` / `removeFcmToken`); bu servis Firestore bilmez.
/// * Dokunma: soğuk açılış [initialMessageData], uygulama arka plandayken
///   [openedMessageData]. Yük, sunucunun `data` alanıdır (hepsi string:
///   `notificationId`, `type` + `refs`'in dolu alanları).
/// * Ön plan: [configureForeground] iOS sistem bandını / sesini / rozetini
///   kapatır; ön planda gelen push için ayrı iş yapılmaz — TST-55 bandı gelen
///   kutusu akışından gelir (T-26; çift gösterim yok).
///
/// * Otomatik başlatma kapalıdır (Android manifest
///   `firebase_messaging_auto_init_enabled=false`, iOS
///   `FirebaseMessagingAutoInitEnabled=NO`): cihaz FCM / APNs kaydını
///   yalnızca etkin oturumda ve izin varken [token] ile açar,
///   [invalidateToken] kapatır — oturumsuz cihaz jeton taşımaz, emülatör
///   ortamı gerçek projeye kayıt olmaz (W-53).
///
/// Hiçbir metot fırlatmaz: SDK hatası `null` / boş akış / etkisiz çağrıdır.
abstract interface class MessagingService {
  /// Bildirim izni push için yeterli mi (`authorized` ya da `provisional`)?
  /// Sistem penceresi **açmaz**.
  Future<bool> isAuthorized();

  /// Otomatik başlatmayı açar (iOS'ta APNs kaydı) ve bu cihazın FCM
  /// jetonunu döndürür; alınamazsa (iOS'ta APNs jetonu henüz yok, ağ yok)
  /// `null` — jeton gelince [onTokenRefresh] yayar.
  Future<String?> token();

  /// Jeton yenilendi / ilk kez üretildi.
  Stream<String> get onTokenRefresh;

  /// Bu cihazın jetonunu geçersiz kılar (çıkış; FCM `deleteToken`) ve
  /// otomatik başlatmayı kapatır (jeton kendiliğinden yeniden üretilmez).
  /// Sonraki [token] yeni jeton üretir.
  ///
  /// Jeton silindiyse `true`; `deleteToken` başarısızsa (çoğunlukla ağ yok)
  /// `false` — çağıran temizliği sonra yeniden dener (T-44 · A4-06).
  /// Otomatik başlatmayı kapatma hatası sonucu değiştirmez.
  Future<bool> invalidateToken();

  /// Uygulamayı push'a dokunarak (soğuk) açtıran mesajın `data` yükü; yoksa
  /// `null`. Aynı mesaj ikinci kez dönmez.
  Future<Map<String, String>?> initialMessageData();

  /// Uygulama arka plandayken dokunulan push'ların `data` yükleri.
  Stream<Map<String, String>> get openedMessageData;

  /// Ön plan sunumunu kurar: iOS'ta sistem bandı, ses ve rozet kapalı.
  Future<void> configureForeground();

  /// Push `data` yükünde bildirim belgesinin kimliği.
  static const String notificationIdKey = 'notificationId';

  /// Push `data` yükünde bildirim türü (`NotificationType.json`).
  static const String typeKey = 'type';
}

/// [MessagingService] uygulaması: `firebase_messaging`.
///
/// `messaging` ve `openedApp` yalnızca testte verilir; varsayılanlar
/// `FirebaseMessaging.instance` (varsayılan Firebase uygulaması) ve
/// `FirebaseMessaging.onMessageOpenedApp`'tir. Emülatör ortamında bu sınıf
/// **kurulmaz** (gerçek projeye gider — W-53); kompozisyon kökü yerel
/// uygulamayı kaydeder.
final class FirebaseMessagingService implements MessagingService {
  /// Varsayılan Firebase uygulamasının FCM'i.
  FirebaseMessagingService({this._messaging, this._openedApp});

  final FirebaseMessaging? _messaging;
  final Stream<RemoteMessage>? _openedApp;

  FirebaseMessaging get _sdk => _messaging ?? FirebaseMessaging.instance;

  /// Push için yeterli izin durumları.
  static bool isPushAuthorized(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  /// FCM `data` yükü → string haritası (değerler zaten string'dir; olmayan
  /// `toString` ile çevrilir, `null` atılır).
  static Map<String, String> dataOf(Map<String, dynamic> data) => {
    for (final MapEntry(:key, :value) in data.entries)
      if (value != null) key: value is String ? value : '$value',
  };

  @override
  Future<bool> isAuthorized() async {
    try {
      final settings = await _sdk.getNotificationSettings();
      return isPushAuthorized(settings.authorizationStatus);
    } on Object {
      return false;
    }
  }

  @override
  Future<String?> token() async {
    try {
      await _sdk.setAutoInitEnabled(true);
      final value = await _sdk.getToken();
      return value == null || value.isEmpty ? null : value;
    } on Object {
      // iOS: `apns-token-not-set` — APNs jetonu gelince onTokenRefresh yayar.
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh =>
      _sdk.onTokenRefresh.handleError((Object _) {});

  @override
  Future<bool> invalidateToken() async {
    var deleted = true;
    try {
      await _sdk.deleteToken();
    } on Object {
      // En iyi çaba: sunucu geçersiz jetonu ilk gönderimde çıkarır; çağıran
      // `false` ile temizliği sonra yeniden dener.
      deleted = false;
    }
    try {
      await _sdk.setAutoInitEnabled(false);
    } on Object {
      // En iyi çaba (sonucu değiştirmez).
    }
    return deleted;
  }

  @override
  Future<Map<String, String>?> initialMessageData() async {
    try {
      final message = await _sdk.getInitialMessage();
      return message == null ? null : dataOf(message.data);
    } on Object {
      return null;
    }
  }

  @override
  Stream<Map<String, String>> get openedMessageData =>
      (_openedApp ?? FirebaseMessaging.onMessageOpenedApp)
          .map((message) => dataOf(message.data))
          .handleError((Object _) {});

  @override
  Future<void> configureForeground() async {
    try {
      await _sdk.setForegroundNotificationPresentationOptions();
    } on Object {
      // Android'de etkisiz; iOS varsayılanı zaten kapalıdır.
    }
  }
}
