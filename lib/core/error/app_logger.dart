import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

/// Günlük düzeyi; [tag] satırın başına yazılır.
enum AppLogLevel {
  /// Geliştirme ayrıntısı; release derlemede yazılmaz.
  debug('D'),

  /// Olağan akış bilgisi.
  info('I'),

  /// Beklenmeyen ama kurtarılabilir durum (ör. `FirebaseFailure`).
  warn('W'),

  /// Hata.
  error('E');

  const AppLogLevel(this.tag);

  /// Satır öneki harfi (`[W] …`).
  final String tag;
}

/// Uygulamanın tek günlük kapısı (architecture §12, D-23; HC11 istisnası).
///
/// Debug/profile derlemede konsola (`debugPrint`), release derlemede
/// Crashlytics günlüğüne (`CrashService.log`) yazar. `print` / `debugPrint`
/// başka hiçbir dosyada çağrılmaz.
///
/// - Release'te [debug] düzeyi yazılmaz (Crashlytics günlüğü sınırlıdır;
///   gürültü son satırları iter).
/// - `CrashService` GetIt'ten okunur; kayıt yoksa (DI kurulmadan önce) satır
///   sessizce düşer.
/// - Hiçbir metot fırlatmaz: günlük yazımı çağıranın akışını bozmaz.
/// - Mesaja kişisel veri (e-posta, ad, mesaj içeriği) yazılmaz; kullanıcı
///   yalnızca uid ile anılır.
abstract final class AppLogger {
  /// Geliştirme ayrıntısı (release'te yazılmaz).
  static void debug(String message, {Object? error, StackTrace? stackTrace}) =>
      write(AppLogLevel.debug, message, error: error, stackTrace: stackTrace);

  /// Olağan akış bilgisi.
  static void info(String message, {Object? error, StackTrace? stackTrace}) =>
      write(AppLogLevel.info, message, error: error, stackTrace: stackTrace);

  /// Beklenmeyen ama kurtarılabilir durum.
  static void warn(String message, {Object? error, StackTrace? stackTrace}) =>
      write(AppLogLevel.warn, message, error: error, stackTrace: stackTrace);

  /// Hata.
  static void error(String message, {Object? error, StackTrace? stackTrace}) =>
      write(AppLogLevel.error, message, error: error, stackTrace: stackTrace);

  /// [level] düzeyinde tek satır yazar. Uygulama kodu düzey metotlarını
  /// çağırır; [release] yalnızca testte verilir (varsayılan derleme kipi).
  @visibleForTesting
  static void write(
    AppLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool release = kReleaseMode,
  }) {
    try {
      final line = format(level, message, error: error);
      if (!release) {
        debugPrint(stackTrace == null ? line : '$line\n$stackTrace');
        return;
      }
      if (level == AppLogLevel.debug) return;
      if (GetIt.I.isRegistered<CrashService>()) {
        GetIt.I<CrashService>().log(line);
      }
    } on Object catch (_) {
      // Günlük yazımı hiçbir zaman çağıranı düşürmez.
    }
  }

  /// Satır biçimi: `[W] mesaj` ya da hata varsa `[W] mesaj | hata`.
  @visibleForTesting
  static String format(AppLogLevel level, String message, {Object? error}) =>
      error == null
      ? '[${level.tag}] $message'
      : '[${level.tag}] $message | $error';
}
