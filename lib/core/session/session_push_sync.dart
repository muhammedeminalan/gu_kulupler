import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';

/// Oturumun push jetonu köprüsü (T-42, Mod F — `docs/plans/T-42.md` §4 d,
/// CD-165). `SessionViewModel` çağırır; oturum kararını (hangi uid, hâlâ
/// geçerli mi) o verir, bu sınıf yalnızca okur ve yazar.
///
/// * [register] — oturum `active` çözülünce, dil değişince ve uygulama öne
///   gelince (DLG-03 / sistem ayarlarından verilen izin böyle yakalanır):
///   izin `authorized` / `provisional` ise bu cihazın jetonu
///   `UserRepository.upsertFcmToken` ile yazılır (`{token, platform,
///   locale, updatedAt}`). Aynı (kullanıcı, jeton, dil) bu oturumda zaten
///   yazıldıysa yeniden yazılmaz. `onTokenRefresh` dinlenir: yeni jeton
///   aynı yoldan yazılır. Jetonun yazıldığı hesap cihazda saklanır
///   (`AppPreferencesStore.pushTokenUid`); **başka** hesap girerse jeton
///   önce geçersiz kılınır (T-42 güvenlik incelemesi: çevrimdışı çıkışta
///   önceki hesabın listesinde kalan jeton yeni hesaba yazılmaz → önceki
///   hesabın push'u yeni kullanıcının kilit ekranına düşmez; eski jeton
///   sunucuda `UNREGISTERED` ile temizlenir).
/// * [unregister] — çıkışta `signOut`'tan **önce** (Rules oturum ister): bu
///   cihazın jetonu hesaptan çıkarılır (`removeFcmToken`) ve FCM'de
///   geçersiz kılınır (`invalidateToken`); her adım
///   [AppDurations.pushTokenCleanupTimeout] ile sınırlıdır (çıkışı
///   engellemez).
/// * [forgetDevice] — silinmiş hesap (jetonlar `markDeleted` ile zaten
///   `[]`): yalnızca yerel jeton geçersizleşir.
/// * [release] — oturum dışarıdan kapandı (süre, iptal, başka cihazdan):
///   dinleyici bırakılır; bu oturumda jeton yazıldıysa yerel jeton
///   geçersiz kılınır (hesaba yazılamaz — oturum yok; sunucu eski jetonu
///   ilk gönderimde temizler).
/// * [detach] — dinleyiciyi bırakır, yazım yok.
/// * [retryPendingCleanup] — oturum kapalıyken (açılış, çıkış olayı, öne
///   gelme): önceki çıkışta geçersiz kılınamayan jeton (çevrimdışı) yeniden
///   geçersiz kılınır (T-44 · A4-06).
///
/// **Bekleyen temizlik:** `AppPreferencesStore.pushTokenUid` jetonun yazıldığı
/// hesabı tutar ve yalnızca jeton FCM'de **gerçekten** geçersiz kılınınca
/// (`invalidateToken` → `true`) temizlenir; dolu kalan değer "temizlik
/// bekliyor" demektir. Geçersiz kılma tek uçuşludur (aynı anda tek çağrı);
/// [register] bekleyen çağrının bitmesini bekler — temizliğin `deleteToken`'ı
/// yeni yazılan jetonu öldürmez.
///
/// İzin **istenmez** (`PermissionService` — tek pencere). Hiçbir metot
/// fırlatmaz: hata günlüğe düşer (jeton değeri yazılmaz).
final class SessionPushSync with ProjectDependencyMixin {
  /// Bu oturumda başarıyla yazılan son kayıt.
  ({String uid, String token, String locale})? _registered;

  /// Süren geçersiz kılma (tek uçuş — [_invalidate]).
  Future<bool>? _inflight;

  /// `onTokenRefresh` aboneliği ve dinlenen kullanıcı.
  StreamSubscription<String>? _refresh;
  String? _refreshFor;

  /// Ön plan sunumu kuruldu mu (uygulama ömründe bir kez)?
  bool _foregroundConfigured = false;

  /// [uid] hesabına bu cihazın jetonunu yazar (izin yoksa ya da jeton
  /// alınamazsa etkisiz). [isCurrent] her bekleyişten sonra sorulur:
  /// `false` ise (oturum değişti / kapandı) yazılmaz.
  Future<void> register(
    String uid, {
    required bool Function() isCurrent,
  }) async {
    final platform = _platform;
    if (platform == null) return;
    if (!_foregroundConfigured) {
      _foregroundConfigured = true;
      await messagingService.configureForeground();
    }
    _listenRefresh(uid, platform, isCurrent);
    if (!await messagingService.isAuthorized() || !isCurrent()) return;
    // Süren temizlik (önceki hesabın jetonu) bitmeden okunmaz / yazılmaz.
    if (_inflight case final running?) await running;
    if (!isCurrent()) return;
    final owner = appPreferencesStore.pushTokenUid;
    if (owner != null && owner != uid) {
      // Jeton başka hesaba yazılmıştı: önce geçersiz kıl (yeni jeton üretilir).
      _registered = null;
      await _invalidate();
      if (!isCurrent()) return;
    }
    final token = await messagingService.token();
    if (token == null || !isCurrent()) return;
    await _write(uid, token, platform, isCurrent);
  }

  /// [uid] hesabından bu cihazın jetonunu çıkarır ve jetonu geçersiz kılar
  /// (en iyi çaba, süre sınırlı). Yazılmış jeton yoksa ve izin de yoksa
  /// hiçbir şey yapılmaz (jeton üretilmez).
  ///
  /// Cihaz çevrimdışı biliniyorsa ağ adımları atlanır ve çıkış beklemez
  /// (3 + 3 sn yerine anında — T-44 · A4-06): `pushTokenUid` dolu kalır,
  /// geçersiz kılma [retryPendingCleanup] ile sonra yapılır; hesaptaki jeton
  /// sunucuda `UNREGISTERED` ile temizlenir.
  Future<void> unregister(String uid) async {
    detach();
    final registered = _registered;
    _registered = null;
    if (connectivityGate.isOffline) {
      AppLogger.info('Çevrimdışı çıkış: push jetonu temizliği ertelendi');
      return;
    }
    final token = registered != null && registered.uid == uid
        ? registered.token
        : await _currentTokenIfAuthorized();
    if (token == null) return;
    final removed = await userRepository
        .removeFcmToken(uid, token)
        .timeout(
          AppDurations.pushTokenCleanupTimeout,
          onTimeout: () => const FirebaseFailure(FirestoreError.timeout),
        );
    if (removed case FirebaseFailure(:final error)) {
      AppLogger.warn('Push jetonu hesaptan çıkarılamadı: ${error.name}');
    }
    await _invalidate();
  }

  /// Silinmiş hesap: hesap belgesine yazılmaz (`fcmTokens` zaten `[]`),
  /// yalnızca bu cihazın jetonu geçersiz kılınır.
  Future<void> forgetDevice() async {
    detach();
    final hadToken = _registered != null;
    _registered = null;
    if (hadToken || await messagingService.isAuthorized()) await _invalidate();
  }

  /// Oturum dışarıdan kapandı: dinleyici bırakılır; bu oturumda jeton
  /// yazıldıysa yerel jeton geçersiz kılınır (en iyi çaba, süre sınırlı).
  Future<void> release() async {
    detach();
    if (_registered == null) return;
    _registered = null;
    await _invalidate();
  }

  /// Oturum kapalıyken çağrılır (açılış, çıkış olayı, öne gelme — T-44 ·
  /// A4-06): önceki çıkışta geçersiz kılınamayan jeton (`pushTokenUid` dolu)
  /// yeniden geçersiz kılınır; başarıda `pushTokenUid` temizlenir. Süren bir
  /// geçersiz kılma varsa yalnızca o beklenir (az önce denendi; aynı anda
  /// ikinci çağrı yapılmaz).
  Future<void> retryPendingCleanup() async {
    if (_inflight case final running?) {
      await running;
      return;
    }
    if (appPreferencesStore.pushTokenUid == null) return;
    await _invalidate();
  }

  /// Jeton yenileme dinleyicisini bırakır (yazım yok).
  void detach() {
    unawaited(_refresh?.cancel());
    _refresh = null;
    _refreshFor = null;
  }

  /// Push metinlerinin dili: uygulama tercihi, yoksa cihaz dili; desteklenmeyen
  /// dil → `FcmTokenModel.defaultLocale` (PLAN §14.10).
  String get locale {
    final code =
        (appPreferencesStore.locale ?? PlatformDispatcher.instance.locale)
            .languageCode;
    return FcmTokenModel.locales.contains(code)
        ? code
        : FcmTokenModel.defaultLocale;
  }

  /// `FcmTokenModel.platform`; push'u olmayan platformda `null`.
  static String? get _platform => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => null,
  };

  void _listenRefresh(
    String uid,
    String platform,
    bool Function() isCurrent,
  ) {
    if (_refreshFor == uid && _refresh != null) return;
    detach();
    _refreshFor = uid;
    _refresh = messagingService.onTokenRefresh.listen((token) {
      if (token.isEmpty || !isCurrent()) return;
      unawaited(_write(uid, token, platform, isCurrent));
    });
  }

  Future<void> _write(
    String uid,
    String token,
    String platform,
    bool Function() isCurrent,
  ) async {
    final language = locale;
    final entry = (uid: uid, token: token, locale: language);
    if (_registered == entry) return;
    final written = await userRepository.upsertFcmToken(
      uid,
      FcmTokenModel(
        token: token,
        platform: platform,
        locale: language,
        updatedAt: appClock.nowUtc(),
      ),
    );
    switch (written) {
      case FirebaseSuccess():
        if (appPreferencesStore.pushTokenUid != uid) {
          await appPreferencesStore.setPushTokenUid(uid);
        }
        if (isCurrent()) _registered = entry;
      case FirebaseFailure(:final error):
        AppLogger.warn('Push jetonu yazılamadı: ${error.name}');
    }
  }

  Future<String?> _currentTokenIfAuthorized() async =>
      await messagingService.isAuthorized()
      ? await messagingService.token()
      : null;

  /// Bu cihazın jetonunu geçersiz kılar (tek uçuş, süre sınırlı). Başarıda
  /// `pushTokenUid` temizlenir (bekleyen temizlik yok); başarısızsa dolu
  /// kalır ve [retryPendingCleanup] sonra yeniden dener.
  Future<bool> _invalidate() =>
      _inflight ??= _runInvalidate().whenComplete(() => _inflight = null);

  Future<bool> _runInvalidate() async {
    final invalidated = await messagingService.invalidateToken().timeout(
      AppDurations.pushTokenCleanupTimeout,
      onTimeout: () => false,
    );
    if (!invalidated) {
      AppLogger.warn(
        'Push jetonu geçersiz kılınamadı; sonra yeniden denenecek',
      );
      return false;
    }
    if (appPreferencesStore.pushTokenUid != null) {
      await appPreferencesStore.setPushTokenUid(null);
    }
    return true;
  }
}
