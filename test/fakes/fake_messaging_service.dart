// `MessagingService` fake'i (T-42, CD-165): FCM'e gitmez. İzin durumu,
// jeton, soğuk açılış yükü ve dokunma / yenileme olayları testte elle
// kurulur.
//
//   final messaging = GetIt.I<MessagingService>() as FakeMessagingService;
//   messaging.authorized = false;          // izin yok → jeton yazılmaz
//   messaging.refreshToken('fcm-2');       // onTokenRefresh
//   messaging.tap({'notificationId': 'n1'}); // arka plandan dokunma
import 'dart:async';

import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

final class FakeMessagingService extends FakeBase implements MessagingService {
  /// Varsayılan jeton.
  static const String defaultToken = 'fake-fcm-token';

  /// `isAuthorized` sonucu.
  bool authorized = true;

  /// `token` sonucu (`null` → jeton alınamadı); `invalidateToken` sonrası
  /// [nextToken] olur (FCM yeni jeton üretir).
  String? currentToken = defaultToken;

  /// `invalidateToken` sonrası üretilecek jeton.
  String nextToken = 'fake-fcm-token-2';

  /// `initialMessageData` sonucu (bir kez döner).
  Map<String, String>? launchData;

  /// `configureForeground` çağrıldı mı?
  bool foregroundConfigured = false;

  /// Verilirse `invalidateToken` bunu bekler (süre sınırı testleri).
  Completer<void>? invalidateGate;

  final StreamController<Map<String, String>> _taps =
      StreamController<Map<String, String>>.broadcast(sync: true);
  final StreamController<String> _refresh = StreamController<String>.broadcast(
    sync: true,
  );

  /// Uygulama arka plandayken [data] yüklü push'a dokunma benzetimi.
  void tap(Map<String, String> data) => _taps.add(data);

  /// FCM jetonu yeniledi: [token] güncel jeton olur ve yayılır.
  void refreshToken(String token) {
    currentToken = token;
    _refresh.add(token);
  }

  /// Dokunma akışının dinleyicisi var mı?
  bool get hasTapListener => _taps.hasListener;

  /// Yenileme akışının dinleyicisi var mı?
  bool get hasRefreshListener => _refresh.hasListener;

  @override
  Future<bool> isAuthorized() async {
    record('isAuthorized');
    return authorized;
  }

  @override
  Future<String?> token() async {
    record('token');
    return currentToken;
  }

  @override
  Stream<String> get onTokenRefresh => _refresh.stream;

  @override
  Future<void> invalidateToken() async {
    record('invalidateToken');
    await invalidateGate?.future;
    currentToken = nextToken;
  }

  @override
  Future<Map<String, String>?> initialMessageData() async {
    record('initialMessageData');
    final data = launchData;
    launchData = null;
    return data;
  }

  @override
  Stream<Map<String, String>> get openedMessageData => _taps.stream;

  @override
  Future<void> configureForeground() async {
    record('configureForeground');
    foregroundConfigured = true;
  }
}
