import 'dart:async';

// `firebase_remote_config` FirebaseException tipini dışa aktarmaz; aynı sınıf
// (firebase_core) cloud_firestore üzerinden alınır.
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/constants/remote_config_keys.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/remote_config_error.dart';

/// Uzaktan yapılandırma (Remote Config) kapısı (PLAN §10.2;
/// architecture §11).
///
/// Değer okuyucular **eşzamanlıdır ve hiçbir zaman fırlatmaz**: uzaktan değer
/// yoksa, okunamıyorsa ya da geçersizse kod içi varsayılan döner (`Limits`).
/// Remote Config yalnızca geçersiz kılar; hatası kullanıcıya gösterilmez.
abstract interface class RemoteConfigService {
  /// Yapılandırmayı sunucudan çeker ve etkinleştirir; değerler değiştiyse
  /// başarı `true` taşır. Açılışta **beklenmez** (arka planda çalışır).
  Future<RemoteConfigResult<bool>> fetchAndActivate();

  /// Desteklenen en düşük derleme numarası; varsayılan `0` (kapı kapalı).
  int get minSupportedBuild;

  /// Bakım mesajı; varsayılan boş (bant yok).
  String get maintenanceMessage;

  /// Günlük duyuru sınırı — yalnızca arayüz ipucu (bağlayıcı değer Security
  /// Rules'tadır, Q-10); varsayılan [Limits.announcementDailyLimit].
  int get announcementDailyLimit;

  /// Yeniden başvuru bekleme süresi, gün — yalnızca metin ipucu; varsayılan
  /// [Limits.reapplyCooldown] gün sayısı.
  int get reapplyCooldownDays;

  /// Sunucudaki yapılandırma değişip etkinleştirildiğinde olay yayınlar
  /// (zorunlu güncelleme kapısı DLG-26 dinler). Hata olayı taşımaz.
  Stream<void> get onConfigUpdated;
}

/// [RemoteConfigService] uygulaması: `firebase_remote_config` SDK'sını sarar.
final class FirebaseRemoteConfigService implements RemoteConfigService {
  /// Verilen `FirebaseRemoteConfig` örneğini sarar. `minimumFetchInterval`
  /// üretimde 1 saattir; emülatör ortamında kompozisyon kökü
  /// `Duration.zero` verir. `fetchTimeout` hem SDK'ya hem çağrı zaman
  /// aşımına uygulanır.
  FirebaseRemoteConfigService(
    this._config, {
    this._minimumFetchInterval = defaultMinimumFetchInterval,
    this._fetchTimeout = defaultFetchTimeout,
  });

  /// Üretimde iki çekim arasındaki en kısa süre.
  static const Duration defaultMinimumFetchInterval = Duration(hours: 1);

  /// Çekim zaman aşımı.
  static const Duration defaultFetchTimeout = Duration(seconds: 10);

  final FirebaseRemoteConfig _config;
  final Duration _minimumFetchInterval;
  final Duration _fetchTimeout;
  bool _configured = false;

  @override
  Future<RemoteConfigResult<bool>> fetchAndActivate() async {
    try {
      return FirebaseSuccess(await _fetch().timeout(_fetchTimeout));
    } on TimeoutException catch (error) {
      return FirebaseFailure(RemoteConfigError.timeout, message: error.message);
    } on FirebaseException catch (error) {
      return FirebaseFailure(
        RemoteConfigError.fromCode(error.code),
        message: error.message,
      );
    } on Object catch (error) {
      return FirebaseFailure(
        RemoteConfigError.unknown,
        message: error.toString(),
      );
    }
  }

  @override
  int get minSupportedBuild {
    final build = _remoteInt(RemoteConfigKeys.minSupportedBuild);
    return build == null || build < 0 ? 0 : build;
  }

  @override
  String get maintenanceMessage =>
      _remote(RemoteConfigKeys.maintenanceMessage)?.trim() ?? '';

  @override
  int get announcementDailyLimit => _positiveInt(
    RemoteConfigKeys.announcementDailyLimit,
    Limits.announcementDailyLimit,
  );

  @override
  int get reapplyCooldownDays => _positiveInt(
    RemoteConfigKeys.reapplyCooldownDays,
    Limits.reapplyCooldown.inDays,
  );

  @override
  Stream<void> get onConfigUpdated => _config.onConfigUpdated
      // Canlı güncelleme bağlantısı en-iyi-çaba çalışır (masaüstünde hiç
      // yoktur); hatası değerleri etkilemez, bir sonraki çekim telafi eder.
      .handleError((Object _) {})
      .asyncMap(_activate)
      .where((activated) => activated)
      .map<void>((_) {});

  /// İlk çağrıda SDK ayarlarını yazar, sonra çekip etkinleştirir.
  Future<bool> _fetch() async {
    if (!_configured) {
      await _config.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: _fetchTimeout,
          minimumFetchInterval: _minimumFetchInterval,
        ),
      );
      _configured = true;
    }
    return _config.fetchAndActivate();
  }

  /// Çekilmiş yapılandırmayı etkinleştirir; etkinleşti mi?
  Future<bool> _activate(RemoteConfigUpdate _) async {
    try {
      await _config.activate();
      return true;
    } on Object catch (_) {
      // Etkinleştirilemedi: değerler eski halinde kalır, olay yayınlanmaz.
      return false;
    }
  }

  /// [key] için uzaktan (ya da konsol varsayılanı) gelen ham değer; değer
  /// tanımlı değilse ya da okunamıyorsa `null`.
  String? _remote(String key) {
    try {
      final value = _config.getValue(key);
      return value.source == ValueSource.valueStatic ? null : value.asString();
    } on Object catch (_) {
      // Okunamadı: çağıran kod içi varsayılana düşer.
      return null;
    }
  }

  int? _remoteInt(String key) {
    final raw = _remote(key);
    return raw == null ? null : int.tryParse(raw.trim());
  }

  /// [key] değeri pozitif bir tam sayıysa onu, değilse [fallback] döndürür.
  int _positiveInt(String key, int fallback) {
    final value = _remoteInt(key);
    return value == null || value < 1 ? fallback : value;
  }
}
