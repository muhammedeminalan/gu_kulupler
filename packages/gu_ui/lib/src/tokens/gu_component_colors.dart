import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Registry dışı bileşen renkleri — 18 alan × açık/koyu (CD-17 → CD-87).
///
/// Değerler `docs/token-map.md` §2 ile birebir: 13 alan `component-css.css`
/// kurallarından (`/// CSS-derived`, §2 #1–13), 5 alan prototip JS satır içi
/// stillerinden (`/// JS-derived`, §2 #14–18; açık = koyu). `GuColors` 27
/// registry rengini taşır ve değişmez.
///
/// Bilinçli sapma: koyu `toastActionForeground` CSS'teki `var(--text-heading)`
/// (`#F5F5F1`, kontrast 1.2) yerine `#1E2024` (= `GuColors.dark.bgSurface`,
/// 12.45) — CD-98, K-41.
///
/// Erişim: `context.gu.component` (CD-18). Alan sırası = `props` sırası.
@immutable
final class GuComponentColors extends ThemeExtension<GuComponentColors>
    with Equatable {
  const GuComponentColors({
    required this.chipBorder,
    required this.onCoverScrim,
    required this.onCoverScrimPressed,
    required this.onCoverForeground,
    required this.toastActionBackground,
    required this.toastActionForeground,
    required this.scanViewGradientStart,
    required this.scanViewGradientEnd,
    required this.scanBoxCorner,
    required this.viewerBackground,
    required this.qrBackground,
    required this.avatarInitials,
    required this.coverInk,
    required this.scanMutedForeground,
    required this.scanPanelScrim,
    required this.scanOutlineBorder,
    required this.viewerHintForeground,
    required this.qrModule,
  });

  /// Açık tema (token-map §2 "Açık" sütunu).
  static const GuComponentColors light = GuComponentColors(
    chipBorder: Color(0xFFE2E8F0),
    onCoverScrim: Color(0x47000000),
    onCoverScrimPressed: Color(0x66000000),
    onCoverForeground: Color(0xFFFFFFFF),
    toastActionBackground: Color(0x1FFFFFFF),
    toastActionForeground: Color(0xFFFFFFFF),
    scanViewGradientStart: Color(0xFF2A2F3A),
    scanViewGradientEnd: Color(0xFF0B0D12),
    scanBoxCorner: Color(0xFFFFFFFF),
    viewerBackground: Color(0xFF000000),
    qrBackground: Color(0xFFFFFFFF),
    avatarInitials: Color(0xFFFFFFFF),
    coverInk: Color(0xFFFFFFFF),
    scanMutedForeground: Color(0xB3FFFFFF),
    scanPanelScrim: Color(0x59000000),
    scanOutlineBorder: Color(0x66FFFFFF),
    viewerHintForeground: Color(0x99FFFFFF),
    qrModule: Color(0xFF101828),
  );

  /// Koyu tema (token-map §2 "Koyu" sütunu; `toastActionForeground` CD-98).
  static const GuComponentColors dark = GuComponentColors(
    chipBorder: Color(0xFF4A5362),
    onCoverScrim: Color(0x47000000),
    onCoverScrimPressed: Color(0x66000000),
    onCoverForeground: Color(0xFFFFFFFF),
    toastActionBackground: Color(0x14000000),
    toastActionForeground: Color(0xFF1E2024),
    scanViewGradientStart: Color(0xFF2A2F3A),
    scanViewGradientEnd: Color(0xFF0B0D12),
    scanBoxCorner: Color(0xFFFFFFFF),
    viewerBackground: Color(0xFF000000),
    qrBackground: Color(0xFFFFFFFF),
    avatarInitials: Color(0xFFFFFFFF),
    coverInk: Color(0xFFFFFFFF),
    scanMutedForeground: Color(0xB3FFFFFF),
    scanPanelScrim: Color(0x59000000),
    scanOutlineBorder: Color(0x66FFFFFF),
    viewerHintForeground: Color(0x99FFFFFF),
    qrModule: Color(0xFF101828),
  );

  // ── CSS-derived (CD-20) — avatar gradyanı, statik ───────────────────────────
  // art.js:41 `avatarColors`: hue = hashStr('av:' + seed) % 360,
  // hue2 = (hue + 36) % 360, `hsl(hue 48% 42%)` → `hsl(hue2 55% 32%)`,
  // gradyan 135deg (`Alignment.topLeft` → `bottomRight`); hashStr = FNV-1a
  // 32 bit (core:418) → `GuStableHash.fnv1a32` (CD-94, T-04).

  /// CSS-derived — ikinci gradyan durağının ton kayması, derece
  /// (art.js:41 `(hue + 36) % 360`).
  static const int avatarHueShift = 36;

  /// CSS-derived — birinci durak doygunluğu (art.js:41 `hsl(hue 48% 42%)`).
  static const double avatarSaturation1 = 0.48;

  /// CSS-derived — birinci durak açıklığı (art.js:41 `hsl(hue 48% 42%)`).
  static const double avatarLightness1 = 0.42;

  /// CSS-derived — ikinci durak doygunluğu (art.js:41 `hsl(hue2 55% 32%)`).
  static const double avatarSaturation2 = 0.55;

  /// CSS-derived — ikinci durak açıklığı (art.js:41 `hsl(hue2 55% 32%)`).
  static const double avatarLightness2 = 0.32;

  // ── CSS-derived (CD-20) — §2 #1–13 ──────────────────────────────────────────

  /// CSS-derived — çip kenarlığı; açık `var(--border-default)` (css:176),
  /// koyu `#4A5362` (css:177).
  final Color chipBorder;

  /// CSS-derived — kapak üstü ikon düğmesi zemini `rgba(0,0,0,.28)`
  /// (css:155 `.iconbtn.on-cover`).
  final Color onCoverScrim;

  /// CSS-derived — kapak üstü ikon düğmesi basılı zemini `rgba(0,0,0,.4)`
  /// (css:155 `.iconbtn.on-cover:hover`; `:hover` → basılı, K-53).
  final Color onCoverScrimPressed;

  /// CSS-derived — kapak/tarayıcı/görüntüleyici üstü ön plan `#fff`
  /// (css:155, css:401, css:409).
  final Color onCoverForeground;

  /// CSS-derived — toast eylem düğmesi zemini; açık `rgba(255,255,255,.12)`
  /// (css:293), koyu `rgba(0,0,0,.08)` (css:294).
  final Color toastActionBackground;

  /// CSS-derived — toast eylem metni; açık `#fff` (css:293), koyu `#1E2024`
  /// (CSS `var(--text-heading)` yerine — CD-98, K-41; css:294). İki temada da
  /// `GuColors.bgSurface` ile aynı (`GuTypography.toastAction` rengi).
  final Color toastActionForeground;

  /// CSS-derived — QR tarayıcı radyal gradyan merkezi `#2a2f3a`
  /// (css:401 `.scan-view`).
  final Color scanViewGradientStart;

  /// CSS-derived — QR tarayıcı radyal gradyan dışı `#0b0d12` 75 %
  /// (css:401 `.scan-view`).
  final Color scanViewGradientEnd;

  /// CSS-derived — tarama kutusu köşeleri `#fff` (css:403 `.scan-box>i`).
  final Color scanBoxCorner;

  /// CSS-derived — tam ekran görüntüleyici zemini `#000`
  /// (css:409 `.viewer`).
  final Color viewerBackground;

  /// CSS-derived — QR kod zemini `#fff` (css:326 `.qr`; art.js:102).
  final Color qrBackground;

  /// CSS-derived — avatar baş harfleri `#fff` (css:217 `.avatar`;
  /// art.js:42). `GuTypography.avatarInitialsBase` rengiyle aynı.
  final Color avatarInitials;

  /// CSS-derived — kapak ikon katmanı `PALETTES.*.ink` (art.js:5–7).
  final Color coverInk;

  // ── JS-derived (CD-20, CD-87) — §2 #14–18, açık = koyu ──────────────────────

  /// JS-derived — MGT-07 izin açıklaması/sayaç/ipucu metni
  /// `rgba(255,255,255,.7)` (screens-manage.js:149, :151, :152).
  final Color scanMutedForeground;

  /// JS-derived — MGT-07 alt panel zemini `rgba(0,0,0,.35)`
  /// (screens-manage.js:153).
  final Color scanPanelScrim;

  /// JS-derived — MGT-07 outline düğme kenarlığı `rgba(255,255,255,.4)`
  /// (screens-manage.js:149, :154).
  final Color scanOutlineBorder;

  /// JS-derived — SHT-34 yakınlaştırma ipucu `rgba(255,255,255,.6)`
  /// (sheets.js:162).
  final Color viewerHintForeground;

  /// JS-derived — QR modül rengi `#101828` (art.js:102 `qrSVG`; koyu temada
  /// da sabit, CD-106h).
  final Color qrModule;

  /// 18 alan, token-map §2 sırasıyla (`Equatable` eşitliği).
  @override
  List<Object?> get props => [
    chipBorder,
    onCoverScrim,
    onCoverScrimPressed,
    onCoverForeground,
    toastActionBackground,
    toastActionForeground,
    scanViewGradientStart,
    scanViewGradientEnd,
    scanBoxCorner,
    viewerBackground,
    qrBackground,
    avatarInitials,
    coverInk,
    scanMutedForeground,
    scanPanelScrim,
    scanOutlineBorder,
    viewerHintForeground,
    qrModule,
  ];

  @override
  GuComponentColors copyWith({
    Color? chipBorder,
    Color? onCoverScrim,
    Color? onCoverScrimPressed,
    Color? onCoverForeground,
    Color? toastActionBackground,
    Color? toastActionForeground,
    Color? scanViewGradientStart,
    Color? scanViewGradientEnd,
    Color? scanBoxCorner,
    Color? viewerBackground,
    Color? qrBackground,
    Color? avatarInitials,
    Color? coverInk,
    Color? scanMutedForeground,
    Color? scanPanelScrim,
    Color? scanOutlineBorder,
    Color? viewerHintForeground,
    Color? qrModule,
  }) {
    return GuComponentColors(
      chipBorder: chipBorder ?? this.chipBorder,
      onCoverScrim: onCoverScrim ?? this.onCoverScrim,
      onCoverScrimPressed: onCoverScrimPressed ?? this.onCoverScrimPressed,
      onCoverForeground: onCoverForeground ?? this.onCoverForeground,
      toastActionBackground:
          toastActionBackground ?? this.toastActionBackground,
      toastActionForeground:
          toastActionForeground ?? this.toastActionForeground,
      scanViewGradientStart:
          scanViewGradientStart ?? this.scanViewGradientStart,
      scanViewGradientEnd: scanViewGradientEnd ?? this.scanViewGradientEnd,
      scanBoxCorner: scanBoxCorner ?? this.scanBoxCorner,
      viewerBackground: viewerBackground ?? this.viewerBackground,
      qrBackground: qrBackground ?? this.qrBackground,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      coverInk: coverInk ?? this.coverInk,
      scanMutedForeground: scanMutedForeground ?? this.scanMutedForeground,
      scanPanelScrim: scanPanelScrim ?? this.scanPanelScrim,
      scanOutlineBorder: scanOutlineBorder ?? this.scanOutlineBorder,
      viewerHintForeground: viewerHintForeground ?? this.viewerHintForeground,
      qrModule: qrModule ?? this.qrModule,
    );
  }

  /// Alan alan `Color.lerp`.
  @override
  GuComponentColors lerp(
    covariant ThemeExtension<GuComponentColors>? other,
    double t,
  ) {
    if (other is! GuComponentColors) return this;
    return GuComponentColors(
      chipBorder: Color.lerp(chipBorder, other.chipBorder, t)!,
      onCoverScrim: Color.lerp(onCoverScrim, other.onCoverScrim, t)!,
      onCoverScrimPressed: Color.lerp(
        onCoverScrimPressed,
        other.onCoverScrimPressed,
        t,
      )!,
      onCoverForeground: Color.lerp(
        onCoverForeground,
        other.onCoverForeground,
        t,
      )!,
      toastActionBackground: Color.lerp(
        toastActionBackground,
        other.toastActionBackground,
        t,
      )!,
      toastActionForeground: Color.lerp(
        toastActionForeground,
        other.toastActionForeground,
        t,
      )!,
      scanViewGradientStart: Color.lerp(
        scanViewGradientStart,
        other.scanViewGradientStart,
        t,
      )!,
      scanViewGradientEnd: Color.lerp(
        scanViewGradientEnd,
        other.scanViewGradientEnd,
        t,
      )!,
      scanBoxCorner: Color.lerp(scanBoxCorner, other.scanBoxCorner, t)!,
      viewerBackground: Color.lerp(
        viewerBackground,
        other.viewerBackground,
        t,
      )!,
      qrBackground: Color.lerp(qrBackground, other.qrBackground, t)!,
      avatarInitials: Color.lerp(avatarInitials, other.avatarInitials, t)!,
      coverInk: Color.lerp(coverInk, other.coverInk, t)!,
      scanMutedForeground: Color.lerp(
        scanMutedForeground,
        other.scanMutedForeground,
        t,
      )!,
      scanPanelScrim: Color.lerp(scanPanelScrim, other.scanPanelScrim, t)!,
      scanOutlineBorder: Color.lerp(
        scanOutlineBorder,
        other.scanOutlineBorder,
        t,
      )!,
      viewerHintForeground: Color.lerp(
        viewerHintForeground,
        other.viewerHintForeground,
        t,
      )!,
      qrModule: Color.lerp(qrModule, other.qrModule, t)!,
    );
  }
}
