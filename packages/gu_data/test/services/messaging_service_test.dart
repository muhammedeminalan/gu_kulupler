// T-42 · MessagingService (Mod F, CD-165): izin durumu yalnızca okunur
// (izin penceresi PermissionService'tedir), SDK hataları fırlatmaz,
// dokunma yükleri string haritasıdır, ön plan sunumu kapalıdır.
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

/// `FirebaseMessaging` çifti: yalnızca servisin kullandığı üyeler.
final class _Sdk extends Fake implements FirebaseMessaging {
  AuthorizationStatus status = AuthorizationStatus.authorized;
  Object? error;
  String? tokenValue = 'tkn';
  RemoteMessage? initial;
  int invalidations = 0;
  final List<String> log = <String>[];
  ({bool alert, bool badge, bool sound})? foreground;
  final StreamController<String> refresh = StreamController<String>();

  Future<T> _answer<T>(T value) =>
      error == null ? Future.value(value) : Future.error(error!);

  @override
  Future<NotificationSettings> getNotificationSettings() => _answer(
    NotificationSettings(
      alert: AppleNotificationSetting.enabled,
      announcement: AppleNotificationSetting.disabled,
      authorizationStatus: status,
      badge: AppleNotificationSetting.enabled,
      carPlay: AppleNotificationSetting.disabled,
      lockScreen: AppleNotificationSetting.enabled,
      notificationCenter: AppleNotificationSetting.enabled,
      showPreviews: AppleShowPreviewSetting.always,
      timeSensitive: AppleNotificationSetting.disabled,
      criticalAlert: AppleNotificationSetting.disabled,
      sound: AppleNotificationSetting.enabled,
      providesAppNotificationSettings: AppleNotificationSetting.disabled,
    ),
  );

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) => _answer(tokenValue);

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Future<void> deleteToken() {
    invalidations++;
    log.add('deleteToken');
    return _answer(null);
  }

  @override
  Future<void> setAutoInitEnabled(bool enabled) async {
    log.add('autoInit:$enabled');
  }

  @override
  Future<RemoteMessage?> getInitialMessage() => _answer(initial);

  @override
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) {
    foreground = (alert: alert, badge: badge, sound: sound);
    return _answer(null);
  }
}

void main() {
  late _Sdk sdk;
  late StreamController<RemoteMessage> opened;
  late MessagingService service;

  setUp(() {
    sdk = _Sdk();
    opened = StreamController<RemoteMessage>();
    service = FirebaseMessagingService(
      messaging: sdk,
      openedApp: opened.stream,
    );
  });

  group('T-42 · MessagingService', () {
    test('isAuthorized: authorized / provisional → true; denied / '
        'notDetermined / SDK hatası → false (pencere açmaz)', () async {
      final results = <bool>[];
      for (final status in AuthorizationStatus.values) {
        sdk.status = status;
        results.add(await service.isAuthorized());
      }
      sdk.error = Exception('platform');

      expect(results, [
        for (final status in AuthorizationStatus.values)
          status == AuthorizationStatus.authorized ||
              status == AuthorizationStatus.provisional,
      ]);
      expect(await service.isAuthorized(), isFalse);
    });

    test('token / invalidateToken / initialMessageData hata ya da boş '
        'değerde fırlatmaz; yük string haritasıdır', () async {
      expect(await service.token(), 'tkn');
      sdk.tokenValue = '';
      expect(await service.token(), isNull);
      sdk.initial = const RemoteMessage(
        data: {'notificationId': 'n1', 'type': 'announcement', 'x': 3},
      );
      expect(await service.initialMessageData(), {
        'notificationId': 'n1',
        'type': 'announcement',
        'x': '3',
      });

      sdk.error = Exception('apns-token-not-set');
      expect(await service.token(), isNull);
      expect(await service.initialMessageData(), isNull);
      // T-44 · A4-06: deleteToken başarısız → false (temizlik bekler).
      expect(await service.invalidateToken(), isFalse);
      expect(sdk.invalidations, 1);
      // Jeton istenince otomatik başlatma açılır (iOS APNs kaydı); geçersiz
      // kılınca jeton silinir, sonra kapanır (yeniden üretilmez).
      expect(sdk.log, [
        'autoInit:true',
        'autoInit:true',
        'autoInit:true',
        'deleteToken',
        'autoInit:false',
      ]);
    });

    test('T-44 · A4-06 · invalidateToken: jeton silinince true; yalnızca '
        'otomatik başlatma hatası sonucu değiştirmez', () async {
      expect(await service.invalidateToken(), isTrue);
      expect(sdk.invalidations, 1);
    });

    test('H-25 · setBadge: kanala `set` + sayı (negatif → 0); kanal yoksa '
        'fırlatmaz; çıkışta (invalidateToken) rozet 0', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('test/badge');
      final sent = <Object?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            sent.add('${call.method}:${call.arguments}');
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final badged = FirebaseMessagingService(
        messaging: sdk,
        openedApp: opened.stream,
        badgeChannel: channel,
      );

      await badged.setBadge(3);
      await badged.setBadge(-1);
      await badged.invalidateToken();
      await service.setBadge(2);

      expect(sent, ['set:3', 'set:0', 'set:0']);
    });

    test('configureForeground: iOS bandı, ses ve rozet kapalı; dokunma ve '
        'yenileme akışları iletilir', () async {
      await service.configureForeground();
      expect(sdk.foreground, (alert: false, badge: false, sound: false));

      final taps = <Map<String, String>>[];
      final tokens = <String>[];
      service.openedMessageData.listen(taps.add);
      service.onTokenRefresh.listen(tokens.add);
      opened.add(const RemoteMessage(data: {'notificationId': 'n2'}));
      sdk.refresh.add('tkn-2');
      await pumpEventQueue();

      expect(taps, [
        {'notificationId': 'n2'},
      ]);
      expect(tokens, ['tkn-2']);
    });
  });
}
