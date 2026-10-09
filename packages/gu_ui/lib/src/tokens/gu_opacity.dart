/// Opaklık token'ları — `docs/token-map.md` §8.8 (PLAN §7.7.8; HC17).
///
/// Widget katmanında opaklık literali yazılmaz; değerler buradan okunur.
/// Gruplar (CD-20): **CSS-derived** (`component-css.css`, `css:N`) ve
/// **JS-derived** (prototip satır içi değerleri). Mock opaklıklar
/// (`.homebar .85` css:117, durum çubuğu sinyali `.3` shell.js:10) yazılmaz.
/// Token testi: `test/tokens/gu_sizes_test.dart` (GuOpacity grubu, 9 kayıt).
abstract final class GuOpacity {
  // ===========================================================================
  // CSS-derived (CD-20) — `design/extracted/component-css.css`; `css:N` = satır.
  // ===========================================================================

  /// css:149 `.btn[aria-disabled="true"]{opacity:.5}` — `.chip` css:185,
  /// `.tile` css:213, `.switch` css:236, `.check,.radio` css:242 ve
  /// `OptionRow` satır içi stili (ui.js:49) aynı.
  static const double disabled = 0.5;

  /// css:156 `.iconbtn[aria-disabled="true"]{opacity:.45}`.
  static const double iconButtonDisabled = 0.45;

  /// css:165 `.input.is-disabled{opacity:.6}`.
  static const double inputDisabled = 0.6;

  /// css:327 `.qr.is-blur svg{opacity:.5}`.
  static const double qrBlurred = 0.5;

  /// css:143 `.btn-tonal:hover{filter:brightness(.96)}` — `:hover` → basılı
  /// durum (K-53).
  static const double tonalPressedBrightness = 0.96;

  /// css:143 `brightness(.96)` = 1 − 0.04 →
  /// `Color.lerp(brandPrimaryContainer, siyah, tonalPressedDarken)`.
  static const double tonalPressedDarken = 0.04;

  /// css:147 `.btn-danger:hover{filter:brightness(.92)}` = 1 − 0.08 (K-53).
  static const double dangerPressedDarken = 0.08;

  // ===========================================================================
  // JS-derived — `design/prototype/app/*.js` satır içi değerleri.
  // ===========================================================================

  /// ui.js:137 `opacity=".6"` — mini grafik alan dolgusu.
  static const double miniChartFill = 0.6;

  /// art.js:34 `opacity=".12"` — **ek**; kapak ikon katmanı (CD-26).
  static const double coverIcon = 0.12;
}
