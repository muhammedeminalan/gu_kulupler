import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/error/error_boundary.dart';

/// Yakalanmamış hataların tek toplanma noktası (D-23; architecture §4).
///
/// Üç kaynak [CrashService]'e gider:
/// 1. `FlutterError.onError` — çerçeve hataları (build / layout / paint);
///    ölümcül **değildir** (ağaç `ErrorBoundary` ile ayakta kalır).
/// 2. `PlatformDispatcher.onError` — zaman uyumsuz, bölge dışı hatalar; ölümcül.
/// 3. [onZoneError] — `runZonedGuarded` bölge hataları; ölümcül.
///
/// [CrashService] GetIt'ten **tembel** okunur: [install] DI kurulmadan önce
/// çağrılır; o aralıktaki hatalar yalnızca konsola yazılır. Hiçbir işleyici
/// fırlatmaz (hata işleyicinin hatası sonsuz döngüdür).
abstract final class AppErrorHandler {
  /// İşleyicileri ve `ErrorWidget.builder`'ı kurar. Açılışta bir kez,
  /// `WidgetsFlutterBinding.ensureInitialized()`'dan hemen sonra çağrılır.
  static void install() {
    FlutterError.onError = onFlutterError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorBoundary.install();
  }

  /// Çerçeve hatası: debug'da Flutter'ın ayrıntılı dökümüyle konsola yazılır
  /// (aynı hata ikinci kez günlüğe yazılmaz), her derlemede raporlanır.
  static void onFlutterError(FlutterErrorDetails details) {
    final dumped = kDebugMode && !details.silent;
    if (dumped) FlutterError.dumpErrorToConsole(details);
    _record(
      details.exception,
      details.stack,
      fatal: false,
      reason: _describe(details),
      log: !dumped,
    );
  }

  /// Bölge dışı zaman uyumsuz hata. `true` döner: hata işlendi.
  static bool onPlatformError(Object error, StackTrace stack) {
    _record(error, stack, fatal: true, reason: 'PlatformDispatcher.onError');
    return true;
  }

  /// `runZonedGuarded` hata geri çağrısı.
  static void onZoneError(Object error, StackTrace stack) {
    _record(error, stack, fatal: true, reason: 'runZonedGuarded');
  }

  static void _record(
    Object error,
    StackTrace? stack, {
    required bool fatal,
    required String reason,
    bool log = true,
  }) {
    try {
      if (log) AppLogger.error(reason, error: error, stackTrace: stack);
      if (!GetIt.I.isRegistered<CrashService>()) return;
      unawaited(
        GetIt.I<CrashService>().recordError(
          error,
          stack,
          fatal: fatal,
          reason: reason,
        ),
      );
    } on Object catch (_) {
      // Raporlama başarısız: raporlanacak başka yer yok.
    }
  }

  /// Hatanın oluştuğu yer (kişisel veri içermez: çerçevenin sabit metni).
  static String _describe(FlutterErrorDetails details) {
    final library = details.library ?? 'flutter';
    final context = details.context?.toDescription();
    return context == null ? library : '$library: $context';
  }
}
