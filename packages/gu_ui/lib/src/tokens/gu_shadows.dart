import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Yükseklik gölgeleri (`ThemeExtension`). Değerler: `docs/token-map.md §6`.
///
/// Dönüşüm: CSS `x y blur rgba(r,g,b,a)` → `BoxShadow(offset: Offset(x, y),
/// blurRadius: cssBlurToRadius(blur), color: Color(0xAARRGGBB))`;
/// `spreadRadius: 0`. CSS gölge bulanıklığı Gauss σ = `blur / 2` çizer;
/// Flutter `blurRadius`'u σ = `r × 0.57735 + 0.5`'e çevirir
/// (`Shadow.convertRadiusToSigma`). Aynı σ için `r = (blur / 2 − 0.5) /
/// 0.57735` ([cssBlurToRadius]); `const` gölgeler bu formülü CSS değeri
/// okunur kalacak biçimde `const` ifade olarak yazar. Koyu temada CSS
/// `--e1/--e2/--e3: none` (css:74) → `const []`. Token olmayan türevler (§6.2)
/// burada yazılmaz; widget'ta `GuShadows.cssBlurToRadius` ile kurulur.
/// Kullanım: `context.gu.shadows.e1`.
@immutable
final class GuShadows extends ThemeExtension<GuShadows> with Equatable {
  /// Tüm alanları verilen gölge kümesi.
  const GuShadows({
    required this.e0,
    required this.e1,
    required this.e2,
    required this.e3,
    required this.ctaBar,
    required this.fab,
    required this.switchThumb,
  });

  // ── registry (reg.SHADOWS, css:36–39; CD-20) ────────────────────────

  /// registry · `e0` `none` (css:36).
  final List<BoxShadow> e0;

  /// registry · `e1` (css:37; `.card` 203, `.seg` seçili 222).
  final List<BoxShadow> e1;

  /// registry · `e2` (css:38; `.popmenu` 279, `.dialog` 282, `.toast` 290).
  final List<BoxShadow> e2;

  /// registry · `e3` (css:39; `.sheet` 268).
  final List<BoxShadow> e3;

  // ── CSS-derived (CD-20) ─────────────────────────────────────────────

  /// CSS-derived · yapışkan CTA çubuğu (`.ctabar` css:296; koyu `none` css:299).
  final List<BoxShadow> ctaBar;

  /// CSS-derived · FAB (açık `var(--e2)` css:158; koyu css:159).
  final List<BoxShadow> fab;

  /// CSS-derived · switch topuzu (`.switch>i` css:234; iki temada aynı).
  final List<BoxShadow> switchThumb;

  /// `Shadow.convertRadiusToSigma` çarpanı (`σ = r × 0.57735 + 0.5`).
  static const double _sigmaScale = 0.57735;

  /// `Shadow.convertRadiusToSigma` sabit terimi.
  static const double _sigmaOffset = 0.5;

  /// CSS `box-shadow` bulanıklığı (px) → Flutter `BoxShadow.blurRadius`:
  /// CSS σ = `cssBlur / 2` ile Flutter σ = `r × 0.57735 + 0.5` eşitlenir;
  /// σ ≤ 0.5 (r ≤ 0) → 0 (Flutter `blurRadius ≤ 0` bulanıklık çizmez).
  static double cssBlurToRadius(double cssBlur) {
    final radius = (cssBlur / 2 - _sigmaOffset) / _sigmaScale;
    return radius > 0 ? radius : 0;
  }

  // registry · `0 1px 2px rgba(16,24,40,.06), 0 1px 3px rgba(16,24,40,.08)`.
  static const List<BoxShadow> _e1Light = [
    BoxShadow(
      offset: Offset(0, 1),
      blurRadius: (2 / 2 - _sigmaOffset) / _sigmaScale,
      color: Color(0x0F101828),
    ),
    BoxShadow(
      offset: Offset(0, 1),
      blurRadius: (3 / 2 - _sigmaOffset) / _sigmaScale,
      color: Color(0x14101828),
    ),
  ];

  // registry · `0 4px 12px rgba(16,24,40,.10)`.
  static const List<BoxShadow> _e2Light = [
    BoxShadow(
      offset: Offset(0, 4),
      blurRadius: (12 / 2 - _sigmaOffset) / _sigmaScale,
      color: Color(0x1A101828),
    ),
  ];

  // registry · `0 -8px 32px rgba(16,24,40,.16)`.
  static const List<BoxShadow> _e3Light = [
    BoxShadow(
      offset: Offset(0, -8),
      blurRadius: (32 / 2 - _sigmaOffset) / _sigmaScale,
      color: Color(0x29101828),
    ),
  ];

  // CSS-derived · `.ctabar{box-shadow:0 -4px 16px rgba(16,24,40,.06)}` css:296.
  static const List<BoxShadow> _ctaBarLight = [
    BoxShadow(
      offset: Offset(0, -4),
      blurRadius: (16 / 2 - _sigmaOffset) / _sigmaScale,
      color: Color(0x0F101828),
    ),
  ];

  // CSS-derived · `[data-theme="dark"] .fab{box-shadow:0 4px 16px
  // rgba(0,0,0,.4)}` css:159.
  static const List<BoxShadow> _fabDark = [
    BoxShadow(
      offset: Offset(0, 4),
      blurRadius: (16 / 2 - _sigmaOffset) / _sigmaScale,
      color: Color(0x66000000),
    ),
  ];

  // CSS-derived · `.switch>i{box-shadow:0 1px 2px rgba(0,0,0,.2)}` css:234.
  static const List<BoxShadow> _switchThumb = [
    BoxShadow(
      offset: Offset(0, 1),
      blurRadius: (2 / 2 - _sigmaOffset) / _sigmaScale,
      color: Color(0x33000000),
    ),
  ];

  /// Açık tema gölgeleri (css:36–39, 158, 234, 296).
  static const GuShadows light = GuShadows(
    e0: [],
    e1: _e1Light,
    e2: _e2Light,
    e3: _e3Light,
    ctaBar: _ctaBarLight,
    fab: _e2Light,
    switchThumb: _switchThumb,
  );

  /// Koyu tema gölgeleri (css:74 `--e1/--e2/--e3: none`, 159, 234, 299).
  static const GuShadows dark = GuShadows(
    e0: [],
    e1: [],
    e2: [],
    e3: [],
    ctaBar: [],
    fab: _fabDark,
    switchThumb: _switchThumb,
  );

  @override
  GuShadows copyWith({
    List<BoxShadow>? e0,
    List<BoxShadow>? e1,
    List<BoxShadow>? e2,
    List<BoxShadow>? e3,
    List<BoxShadow>? ctaBar,
    List<BoxShadow>? fab,
    List<BoxShadow>? switchThumb,
  }) => GuShadows(
    e0: e0 ?? this.e0,
    e1: e1 ?? this.e1,
    e2: e2 ?? this.e2,
    e3: e3 ?? this.e3,
    ctaBar: ctaBar ?? this.ctaBar,
    fab: fab ?? this.fab,
    switchThumb: switchThumb ?? this.switchThumb,
  );

  @override
  GuShadows lerp(covariant ThemeExtension<GuShadows>? other, double t) {
    if (other is! GuShadows) return this;
    return GuShadows(
      e0: _lerpList(e0, other.e0, t),
      e1: _lerpList(e1, other.e1, t),
      e2: _lerpList(e2, other.e2, t),
      e3: _lerpList(e3, other.e3, t),
      ctaBar: _lerpList(ctaBar, other.ctaBar, t),
      fab: _lerpList(fab, other.fab, t),
      switchThumb: _lerpList(switchThumb, other.switchThumb, t),
    );
  }

  static List<BoxShadow> _lerpList(
    List<BoxShadow> a,
    List<BoxShadow> b,
    double t,
  ) => BoxShadow.lerpList(a, b, t) ?? const [];

  @override
  List<Object?> get props => [e0, e1, e2, e3, ctaBar, fab, switchThumb];
}
