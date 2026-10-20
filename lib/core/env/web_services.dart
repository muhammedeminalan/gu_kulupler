import 'dart:async';

import 'package:gu_data/gu_data.dart';

/// Web derlemesinin push servisi: **FCM'e kaydolmaz**, jeton döndürmez.
///
/// Web push service worker + VAPID anahtarı ister ve kurulmadı; telefon
/// dışındaki oturumun hesaba (`fcmTokens`) jeton yazmaması için izin yok
/// sayılır. Bildirim kutusu (uygulama içi) web'de de çalışır.
final class WebMessagingService implements MessagingService {
  /// Hiçbir yere bağlanmayan servis.
  const WebMessagingService();

  @override
  Future<bool> isAuthorized() async => false;

  @override
  Future<String?> token() async => null;

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

  @override
  Future<void> setBadge(int count) async {}
}
