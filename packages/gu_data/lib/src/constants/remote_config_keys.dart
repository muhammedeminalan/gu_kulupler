/// Remote Config parametre anahtarları (PLAN §10.2; architecture §11).
///
/// Anahtarlar Firebase konsolundaki adlarla birebirdir; kodda elle yazılmaz
/// (D-15). Varsayılan değerler konsolda değil `Limits` sabitlerindedir:
/// Remote Config yalnızca **geçersiz kılar** (`RemoteConfigService`).
abstract final class RemoteConfigKeys {
  /// Desteklenen en düşük derleme numarası (int); `0` = kapı kapalı (DLG-26).
  static const String minSupportedBuild = 'min_supported_build';

  /// Bakım mesajı (string); boşsa bant gösterilmez (CD-48).
  static const String maintenanceMessage = 'maintenance_message';

  /// Günlük duyuru sınırı (int) — yalnızca arayüz ipucu; bağlayıcı değer
  /// Security Rules'taki `Limits.announcementDailyLimit` sabitidir (Q-10).
  static const String announcementDailyLimit = 'announcement_daily_limit';

  /// Yeniden başvuru bekleme süresi, gün (int) — yalnızca metin ipucu.
  static const String reapplyCooldownDays = 'reapply_cooldown_days';

  /// Tüm anahtarlar (test ve doğrulama için).
  static const List<String> all = [
    minSupportedBuild,
    maintenanceMessage,
    announcementDailyLimit,
    reapplyCooldownDays,
  ];
}
