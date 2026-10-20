/// Web çerçevesi ölçüleri (H-23) — tasarımda karşılığı yoktur: prototip 390 px
/// telefondur. Düzen fikri referans projeden (telefon kartı + yan menü);
/// değerler `docs/token-map.md §9.1`.
///
/// Kırılımlar `GuBreakpoints.webFrame` / `GuBreakpoints.webSidebar`'dadır;
/// kart genişliği `GuBreakpoints.maxContentWidth` – [cardMaxWidth].
abstract final class GuWebLayout {
  /// Telefon kartının en geniş hali (referans projeyle aynı); kart pencereye
  /// göre `GuBreakpoints.maxContentWidth` (480) ile bu değer arasında büyür.
  static const double cardMaxWidth = 768;

  /// Kartın ve yan menünün pencere kenarına uzaklığı.
  static const double framePadding = 24;

  /// Yan menü ile kart arası.
  static const double sidebarGap = 24;

  /// Yan menü genişliği.
  static const double sidebarWidth = 264;

  /// Yan menü satırı yüksekliği (dokunma hedefi ≥ 48).
  static const double sidebarItemHeight = 48;

  /// Yan menü üst bilgisindeki amblem kenarı.
  static const double sidebarLogo = 32;

  /// Kart ve yan menü kenarlığı.
  static const double outline = 1;

  /// Zemin nokta deseni aralığı.
  static const double backdropDotSpacing = 24;

  /// Zemin nokta yarıçapı.
  static const double backdropDotRadius = 1.5;

  /// Yan menü kayarak gelirken kartın arkasından başladığı uzaklık (yan menü
  /// genişliğine oran).
  static const double sidebarSlideRatio = 0.25;

  /// Yan menünün görünür olmaya başladığı animasyon noktası (0–1).
  static const double sidebarRevealStart = 0.3;
}
