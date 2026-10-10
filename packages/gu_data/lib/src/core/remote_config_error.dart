/// Remote Config çağrılarının hata sözlüğü (PLAN §10.1, D-34).
///
/// Bu hatalar kullanıcıya **hiçbir zaman** gösterilmez: `RemoteConfigService`
/// başarısız olursa değerler `Limits` varsayılanlarından devam eder ve hata
/// yalnızca günlüğe (`AppLogger`) yazılır.
enum RemoteConfigError {
  /// `throttled` (web: `fetch-throttle`) — istek sıklığı sınırı aşıldı.
  fetchThrottled,

  /// `network-error` (web: `fetch-client-network`) — sunucuya ulaşılamadı.
  network,

  /// Çağrı zaman aşımına uğradı (SDK dışı `TimeoutException` ya da web
  /// `fetch-timeout`).
  timeout,

  /// `cancelled`, `forbidden`, `remote-config-server-error`, `internal`,
  /// `unknown` ve eşleşmeyen her kod.
  unknown;

  /// `firebase_remote_config` `FirebaseException.code` değerini sözlüğe
  /// çevirir.
  ///
  /// Eşleşme birebirdir (küçük harf, tireli). Tabloda olmayan her değer
  /// [unknown] olur.
  static RemoteConfigError fromCode(String code) => switch (code) {
    'throttled' || 'fetch-throttle' => fetchThrottled,
    'network-error' || 'fetch-client-network' => network,
    'fetch-timeout' => timeout,
    _ => unknown,
  };
}
