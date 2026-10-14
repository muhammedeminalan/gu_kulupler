/// Ürün akışı süreleri (iş kuralı; görsel süreler `GuMotion`'dadır).
abstract final class AppDurations {
  /// Bildirimden hedefe gidildikten sonra sheet açılmadan önceki bekleme
  /// (SHT-19 / SHT-26; CD-58, PLAN §15.8).
  static const Duration postNavigationSheetDelay = Duration(milliseconds: 250);
}
