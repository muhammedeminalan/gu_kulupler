import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';

/// Yeniden denemeler arasındaki bekleme; testte gerçek zaman geçirmeyen bir
/// işlevle değiştirilir.
typedef RetryWait = Future<void> Function(Duration delay);

/// Geçici Firestore hatalarında işlemi yeniden dener (PLAN §10.1).
///
/// Yalnızca [FirestoreError.aborted] (transaction çekişmesi) ve
/// [FirestoreError.unavailable] (servis geçici olarak erişilemez) yeniden
/// denenir. Diğer her hata — `permissionDenied`, `conflict`, `ruleViolation`,
/// `timeout` dahil — tekrarlamakla düzelmez ya da sonucu belirsizdir; ilk
/// denemede olduğu gibi döner.
///
/// Toplam [maxAttempts] deneme yapılır (varsayılan 3); n. başarısız denemeden
/// sonra [backoff] listesinin n. süresi kadar beklenir
/// ([Limits.retryBackoff]: 250 ms, 500 ms, 1000 ms). Son denemeden sonra
/// beklenmez.
final class RetryPolicy {
  /// `wait` verilmezse gerçek zamanlayıcıyla beklenir; testler anında dönen
  /// bir işlev verir.
  const RetryPolicy({
    this.maxAttempts = defaultMaxAttempts,
    this.backoff = Limits.retryBackoff,
    this._wait = _delay,
  }) : assert(maxAttempts > 0, 'RetryPolicy.maxAttempts pozitif olmalı');

  /// Varsayılan toplam deneme sayısı (= [Limits.retryBackoff] uzunluğu).
  static const int defaultMaxAttempts = 3;

  /// Toplam deneme sayısı (ilk deneme dahil).
  final int maxAttempts;

  /// Denemeler arası bekleme süreleri; liste kısaysa son süre tekrarlanır,
  /// boşsa beklenmez.
  final List<Duration> backoff;

  final RetryWait _wait;

  /// [error] yeniden denenebilir mi? Yalnızca [FirestoreError.aborted] ve
  /// [FirestoreError.unavailable].
  static bool shouldRetry(FirestoreError error) =>
      error == FirestoreError.aborted || error == FirestoreError.unavailable;

  /// [action] işlemini çalıştırır; yeniden denenebilir bir hatayla dönerse
  /// bekleyip tekrarlar. Son denemenin sonucu (başarı ya da hata) döner.
  ///
  /// [action] her denemede baştan çağrılır; bu yüzden tekrarlanması güvenli
  /// (idempotent) olmalıdır.
  Future<FirestoreResult<T>> run<T>(
    Future<FirestoreResult<T>> Function() action,
  ) async {
    for (var attempt = 1; ; attempt++) {
      final result = await action();
      final error = result.errorOrNull;
      if (error == null || !shouldRetry(error) || attempt >= maxAttempts) {
        return result;
      }
      await _wait(_delayAfter(attempt));
    }
  }

  /// [attempt]. başarısız denemeden sonraki bekleme süresi.
  Duration _delayAfter(int attempt) {
    if (backoff.isEmpty) return Duration.zero;
    return backoff[attempt <= backoff.length
        ? attempt - 1
        : backoff.length - 1];
  }

  static Future<void> _delay(Duration delay) => Future<void>.delayed(delay);
}
