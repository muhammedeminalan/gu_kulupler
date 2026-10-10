import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Çökme ve hata raporlama (Crashlytics) kapısı (PLAN §10.2, D-23).
///
/// Bu servisin metotları **hiçbir zaman fırlatmaz**: hata yakalayıcılardan
/// (`AppErrorHandler`) çağrılır ve raporlamanın kendisi başarısız olursa
/// bunun yeni bir hataya (ve sonsuz döngüye) dönüşmesi engellenir.
abstract interface class CrashService {
  /// [error] hatasını [stack] yığınıyla raporlar. [fatal] çökme olarak
  /// işaretler; [reason] bağlam notudur.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  });

  /// Bir sonraki rapora eklenecek günlük satırı yazar (`AppLogger` release
  /// modunda buraya yazar). Kişisel veri içermemelidir.
  void log(String message);

  /// Raporlara kullanıcı kimliğini (uid — e-posta **değil**) ekler; `null`
  /// kimliği temizler (çıkış).
  Future<void> setUserId(String? uid);

  /// Rapor toplamayı açar/kapatır (debug derlemede kapalı).
  Future<void> setCollectionEnabled(bool enabled);
}

/// [CrashService] uygulaması: `firebase_crashlytics` SDK'sını sarar.
final class FirebaseCrashService implements CrashService {
  /// Verilen `FirebaseCrashlytics` örneğini sarar.
  FirebaseCrashService(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) => _quietly(
    () => _crashlytics.recordError(error, stack, reason: reason, fatal: fatal),
  );

  @override
  void log(String message) =>
      unawaited(_quietly(() => _crashlytics.log(message)));

  @override
  Future<void> setUserId(String? uid) =>
      _quietly(() => _crashlytics.setUserIdentifier(uid ?? ''));

  @override
  Future<void> setCollectionEnabled(bool enabled) => _quietly(
    () => _crashlytics.setCrashlyticsCollectionEnabled(enabled),
  );

  /// [call] çağrısının hatasını bilerek yutar (sınıf açıklaması).
  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call();
    } on Object catch (_) {
      // Raporlama başarısız: raporlanacak başka bir yer yok ve hatayı yukarı
      // taşımak hata yakalayıcıyı yeniden tetikler.
    }
  }
}
