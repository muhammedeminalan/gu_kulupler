import 'package:flutter/widgets.dart';

/// Kırılım noktaları ve referans cihaz ölçüleri (dp).
/// Değerler: `docs/token-map.md §9` (Q-13, CD-29).
///
/// Dikey kilit; yatay yerleşim yok. `isWide` yalnızca içerik sütunu
/// ortalama kararını verir (`GuContentColumn`, T-06).
abstract final class GuBreakpoints {
  // ── Platform-derived (Q-13, CD-29, testing.md §5; CD-20) ────────────

  /// Platform-derived · ortalanmış içerik sütunu üst sınırı 480 (CD-29, Q-13).
  static const double maxContentWidth = 480;

  /// Platform-derived · cihaz matrisi "küçük" genişlik 320 (testing.md §5, D-21).
  static const double phoneSmall = 320;

  /// CSS-derived · referans genişlik 390 (`.device{width:390px}` css:112).
  static const double phoneReference = 390;

  /// Platform-derived · cihaz matrisi "büyük" genişlik 430 (testing.md §5).
  static const double phoneLarge = 430;

  /// Platform-derived · cihaz matrisi "tablet" genişlik 768 (testing.md §5;
  /// prototip `mobile = w < 768` shell.js:65).
  static const double tablet = 768;

  /// CSS-derived · referans/golden yüksekliği 844 (`.device{height:844px}` css:112).
  static const double referenceHeight = 844;

  /// Ekran genişliği `maxContentWidth`'i aşıyorsa `true` (480 dahil değil).
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width > maxContentWidth;
}
