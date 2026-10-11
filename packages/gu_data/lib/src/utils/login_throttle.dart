import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/app_clock.dart';

/// Hatalı giriş denemesi kilidi (PLAN §10.3, §10.4 `AuthRepository.signIn`;
/// AUT-01, DLG-02).
///
/// E-posta başına sayar: art arda [maxFailedAttempts] hatalı denemeden sonra
/// o adres [lockout] süresince kilitlenir. Kilit dolunca ya da başarılı
/// girişte ([reset]) sayaç sıfırlanır. Adres kırpılıp küçültülerek
/// anahtarlanır (`Ayse@…` ile `ayse@…` aynı sayaçtır).
///
/// Durum **bellektedir** (uygulama ömrü): arayüz düzeyinde bir frendir,
/// sunucu tarafı korumanın (`AuthError.tooManyRequests`) yerine geçmez. Zaman
/// yalnızca [AppClock] üzerinden okunur.
final class LoginThrottle {
  /// Verilen saate bağlı kilit; sınırlar varsayılan olarak `Limits`'ten
  /// gelir.
  LoginThrottle(
    this._clock, {
    this.maxFailedAttempts = Limits.loginMaxFailedAttempts,
    this.lockout = Limits.loginLockout,
  }) : assert(maxFailedAttempts > 0, 'maxFailedAttempts pozitif olmalı');

  final AppClock _clock;

  /// Kilitlenmeden önceki hatalı deneme sayısı.
  final int maxFailedAttempts;

  /// Kilit süresi.
  final Duration lockout;

  final Map<String, _Attempts> _entries = {};

  /// [email] kilitliyse kilidin açılacağı an (UTC), değilse `null`.
  ///
  /// Süresi dolmuş kilit burada temizlenir: sayaç sıfırdan başlar.
  DateTime? check(String email) => _lockedUntil(email, _clock.nowUtc());

  /// [email] kilitliyse kalan süre (pozitif), değilse `null`.
  Duration? remaining(String email) {
    final now = _clock.nowUtc();
    return _lockedUntil(email, now)?.difference(now);
  }

  /// [email] için bir hatalı denemeyi sayar; sayı [maxFailedAttempts]'e
  /// ulaşınca adres [lockout] süresince kilitlenir. Kilitliyken çağrılırsa
  /// kilit uzamaz.
  void recordFailure(String email) {
    final now = _clock.nowUtc();
    if (_lockedUntil(email, now) != null) return;
    final entry = _entries.putIfAbsent(_keyOf(email), _Attempts.new);
    entry.failures++;
    if (entry.failures >= maxFailedAttempts) {
      entry.lockedUntil = now.add(lockout);
    }
  }

  /// [email] sayacını ve kilidini sıfırlar (başarılı giriş).
  void reset(String email) => _entries.remove(_keyOf(email));

  /// [now] anında geçerli kilit bitişi; süresi dolmuş kilidi (sayaçla
  /// birlikte) temizler.
  DateTime? _lockedUntil(String email, DateTime now) {
    final key = _keyOf(email);
    final lockedUntil = _entries[key]?.lockedUntil;
    if (lockedUntil == null) return null;
    if (now.isBefore(lockedUntil)) return lockedUntil;
    _entries.remove(key);
    return null;
  }

  static String _keyOf(String email) => email.trim().toLowerCase();
}

/// Bir adresin hatalı deneme sayacı ve (varsa) kilit bitişi.
final class _Attempts {
  int failures = 0;
  DateTime? lockedUntil;
}
