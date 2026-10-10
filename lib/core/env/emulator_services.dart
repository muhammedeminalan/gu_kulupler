import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';

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
/// göndermez**. Crashlytics'in emülatörü yoktur; hatalar yalnızca konsola
/// yazılır (`AppLogger` — emülatör ortamı release derlenemez).
final class EmulatorCrashService implements CrashService {
  /// Yalnızca konsola yazan yerel servis.
  const EmulatorCrashService();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    AppLogger.error(
      reason ?? (fatal ? 'Yakalanmamış hata' : 'Hata'),
      error: error,
      stackTrace: stack,
    );
  }

  @override
  void log(String message) {
    // `AppLogger` debug/profile derlemede satırı zaten konsola yazar.
  }

  @override
  Future<void> setUserId(String? uid) async {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}
