import 'package:flutter/material.dart';

/// Registry renk token'ları — 27 alan × açık/koyu (D-14).
///
/// Değerler `docs/token-map.md` §1 ile birebir; kaynak
/// `design/extracted/registry.json#tokens.COLORS` (= `colors/tokens.json`),
/// CSS değişkenleri css:3–30 (açık) / css:46–73 (koyu). `rgba(r,g,b,a)`
/// → `AA = round(a × 255)`. Registry dışı bileşen renkleri
/// `GuComponentColors`'tadır (CD-17, CD-87).
///
/// Erişim: `context.gu.colors` (CD-18). Alan sırası = `props` sırası.
///
/// Eşitlik `Equatable` değil elle yazılır: `props` 27 registry rengi
/// sözleşmesidir (token-map §1, testler sayar) ve `brightness` bu listenin
/// dışında kalırken yine de `==`/`hashCode`'a girmelidir.
@immutable
final class GuColors extends ThemeExtension<GuColors> {
  const GuColors({
    required this.brightness,
    required this.brandPrimary,
    required this.brandPrimaryText,
    required this.brandPrimaryPressed,
    required this.brandOnPrimary,
    required this.brandPrimaryContainer,
    required this.brandOnPrimaryContainer,
    required this.bgCanvas,
    required this.bgSurface,
    required this.bgSurfaceMuted,
    required this.bgSurfaceRaised,
    required this.borderDefault,
    required this.borderSoft,
    required this.textPrimary,
    required this.textHeading,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.stateSuccess,
    required this.stateSuccessContainer,
    required this.stateWarning,
    required this.stateWarningContainer,
    required this.stateDanger,
    required this.stateDangerContainer,
    required this.stateInfo,
    required this.stateInfoContainer,
    required this.overlayScrim,
    required this.focusRing,
  });

  /// Açık tema — `reg.COLORS[k][0]` (css:3–30).
  static const GuColors light = GuColors(
    brightness: Brightness.light,
    brandPrimary: Color(0xFFD00A2D),
    brandPrimaryText: Color(0xFFD00A2D),
    brandPrimaryPressed: Color(0xFFA80824),
    brandOnPrimary: Color(0xFFFFFFFF),
    brandPrimaryContainer: Color(0xFFFCE8EC),
    brandOnPrimaryContainer: Color(0xFF7A0619),
    bgCanvas: Color(0xFFFAF9F6),
    bgSurface: Color(0xFFFFFFFF),
    bgSurfaceMuted: Color(0xFFF1F5F9),
    bgSurfaceRaised: Color(0xFFFFFFFF),
    borderDefault: Color(0xFFE2E8F0),
    borderSoft: Color(0xFFEEF1F5),
    textPrimary: Color(0xFF101828),
    textHeading: Color(0xFF1D293D),
    textSecondary: Color(0xFF45556C),
    textMuted: Color(0xFF62748E),
    textDisabled: Color(0xFFA3AEBF),
    stateSuccess: Color(0xFF15803D),
    stateSuccessContainer: Color(0xFFDCFCE7),
    stateWarning: Color(0xFFB45309),
    stateWarningContainer: Color(0xFFFEF3C7),
    stateDanger: Color(0xFFB42318),
    stateDangerContainer: Color(0xFFFEE4E2),
    stateInfo: Color(0xFF1D5FAD),
    stateInfoContainer: Color(0xFFE3F0FC),
    overlayScrim: Color(0x7A101828),
    focusRing: Color(0xFFD00A2D),
  );

  /// Koyu tema — `reg.COLORS[k][1]` (css:46–73).
  static const GuColors dark = GuColors(
    brightness: Brightness.dark,
    brandPrimary: Color(0xFFD00A2D),
    brandPrimaryText: Color(0xFFF2536C),
    brandPrimaryPressed: Color(0xFFB8082A),
    brandOnPrimary: Color(0xFFFFFFFF),
    brandPrimaryContainer: Color(0xFF3A0C16),
    brandOnPrimaryContainer: Color(0xFFFFD9E0),
    bgCanvas: Color(0xFF17191C),
    bgSurface: Color(0xFF1E2024),
    bgSurfaceMuted: Color(0xFF292E35),
    bgSurfaceRaised: Color(0xFF23272E),
    borderDefault: Color(0xFF39414B),
    borderSoft: Color(0xFF303740),
    textPrimary: Color(0xFFF1F1ED),
    textHeading: Color(0xFFF5F5F1),
    textSecondary: Color(0xFFC6CCD4),
    textMuted: Color(0xFFAEB5BF),
    textDisabled: Color(0xFF6B7480),
    stateSuccess: Color(0xFF4ADE80),
    stateSuccessContainer: Color(0xFF0F2E1A),
    stateWarning: Color(0xFFFBBF24),
    stateWarningContainer: Color(0xFF3A2A0A),
    stateDanger: Color(0xFFFF7A70),
    stateDangerContainer: Color(0xFF3B1512),
    stateInfo: Color(0xFF7DB7F2),
    stateInfoContainer: Color(0xFF0F2538),
    overlayScrim: Color(0x99000000),
    focusRing: Color(0xFFF2536C),
  );

  /// Bu renk kümesinin teması (`light` → açık, `dark` → koyu).
  final Brightness brightness;

  // ── registry (CD-20) — `reg.COLORS`, 27 alan ──────────────────────────────

  /// registry `brand.primary` — dolu butonlar, aktif sekme göstergesi,
  /// rozetler (css:4 / css:47).
  final Color brandPrimary;

  /// registry `brand.primaryText` — link, ikon, vurgulu metin
  /// (css:5 / css:48).
  final Color brandPrimaryText;

  /// registry `brand.primaryPressed` — basılı durum (css:6 / css:49).
  final Color brandPrimaryPressed;

  /// registry `brand.onPrimary` — kırmızı üstü metin/ikon (css:7 / css:50).
  final Color brandOnPrimary;

  /// registry `brand.primaryContainer` — tonal arka plan (css:8 / css:51).
  final Color brandPrimaryContainer;

  /// registry `brand.onPrimaryContainer` — tonal üstü metin
  /// (css:9 / css:52).
  final Color brandOnPrimaryContainer;

  /// registry `bg.canvas` — sayfa zemini (css:10 / css:53).
  final Color bgCanvas;

  /// registry `bg.surface` — kart yüzeyi (css:11 / css:54).
  final Color bgSurface;

  /// registry `bg.surfaceMuted` — girdi, çip, ikincil alan
  /// (css:12 / css:55).
  final Color bgSurfaceMuted;

  /// registry `bg.surfaceRaised` — sheet, dialog (css:13 / css:56).
  final Color bgSurfaceRaised;

  /// registry `border.default` — kenarlık (css:14 / css:57).
  final Color borderDefault;

  /// registry `border.soft` — ayraç (css:15 / css:58).
  final Color borderSoft;

  /// registry `text.primary` — gövde (css:16 / css:59).
  final Color textPrimary;

  /// registry `text.heading` — başlık (css:17 / css:60).
  final Color textHeading;

  /// registry `text.secondary` — ikincil (css:18 / css:61).
  final Color textSecondary;

  /// registry `text.muted` — yardımcı, zaman damgası (css:19 / css:62).
  final Color textMuted;

  /// registry `text.disabled` — devre dışı (css:20 / css:63).
  final Color textDisabled;

  /// registry `state.success` — onaylandı, katıldı (css:21 / css:64).
  final Color stateSuccess;

  /// registry `state.successContainer` — başarı zemini (css:22 / css:65).
  final Color stateSuccessContainer;

  /// registry `state.warning` — beklemede, dikkat (css:23 / css:66).
  final Color stateWarning;

  /// registry `state.warningContainer` — uyarı zemini (css:24 / css:67).
  final Color stateWarningContainer;

  /// registry `state.danger` — hata, silme (css:25 / css:68).
  final Color stateDanger;

  /// registry `state.dangerContainer` — hata zemini (css:26 / css:69).
  final Color stateDangerContainer;

  /// registry `state.info` — bilgi (css:27 / css:70).
  final Color stateInfo;

  /// registry `state.infoContainer` — bilgi zemini (css:28 / css:71).
  final Color stateInfoContainer;

  /// registry `overlay.scrim` — sheet/dialog arkası; açık
  /// `rgba(16,24,40,.48)`, koyu `rgba(0,0,0,.60)` (css:29 / css:72).
  final Color overlayScrim;

  /// registry `focus.ring` — 2 px halka, 2 px offset (css:30 / css:73;
  /// css:82).
  final Color focusRing;

  /// 27 renk alanı, tablo sırasıyla (token-map §1). `brightness` dahil değil.
  List<Object?> get props => [
    brandPrimary,
    brandPrimaryText,
    brandPrimaryPressed,
    brandOnPrimary,
    brandPrimaryContainer,
    brandOnPrimaryContainer,
    bgCanvas,
    bgSurface,
    bgSurfaceMuted,
    bgSurfaceRaised,
    borderDefault,
    borderSoft,
    textPrimary,
    textHeading,
    textSecondary,
    textMuted,
    textDisabled,
    stateSuccess,
    stateSuccessContainer,
    stateWarning,
    stateWarningContainer,
    stateDanger,
    stateDangerContainer,
    stateInfo,
    stateInfoContainer,
    overlayScrim,
    focusRing,
  ];

  @override
  GuColors copyWith({
    Brightness? brightness,
    Color? brandPrimary,
    Color? brandPrimaryText,
    Color? brandPrimaryPressed,
    Color? brandOnPrimary,
    Color? brandPrimaryContainer,
    Color? brandOnPrimaryContainer,
    Color? bgCanvas,
    Color? bgSurface,
    Color? bgSurfaceMuted,
    Color? bgSurfaceRaised,
    Color? borderDefault,
    Color? borderSoft,
    Color? textPrimary,
    Color? textHeading,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? stateSuccess,
    Color? stateSuccessContainer,
    Color? stateWarning,
    Color? stateWarningContainer,
    Color? stateDanger,
    Color? stateDangerContainer,
    Color? stateInfo,
    Color? stateInfoContainer,
    Color? overlayScrim,
    Color? focusRing,
  }) {
    return GuColors(
      brightness: brightness ?? this.brightness,
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandPrimaryText: brandPrimaryText ?? this.brandPrimaryText,
      brandPrimaryPressed: brandPrimaryPressed ?? this.brandPrimaryPressed,
      brandOnPrimary: brandOnPrimary ?? this.brandOnPrimary,
      brandPrimaryContainer:
          brandPrimaryContainer ?? this.brandPrimaryContainer,
      brandOnPrimaryContainer:
          brandOnPrimaryContainer ?? this.brandOnPrimaryContainer,
      bgCanvas: bgCanvas ?? this.bgCanvas,
      bgSurface: bgSurface ?? this.bgSurface,
      bgSurfaceMuted: bgSurfaceMuted ?? this.bgSurfaceMuted,
      bgSurfaceRaised: bgSurfaceRaised ?? this.bgSurfaceRaised,
      borderDefault: borderDefault ?? this.borderDefault,
      borderSoft: borderSoft ?? this.borderSoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textHeading: textHeading ?? this.textHeading,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      stateSuccess: stateSuccess ?? this.stateSuccess,
      stateSuccessContainer:
          stateSuccessContainer ?? this.stateSuccessContainer,
      stateWarning: stateWarning ?? this.stateWarning,
      stateWarningContainer:
          stateWarningContainer ?? this.stateWarningContainer,
      stateDanger: stateDanger ?? this.stateDanger,
      stateDangerContainer: stateDangerContainer ?? this.stateDangerContainer,
      stateInfo: stateInfo ?? this.stateInfo,
      stateInfoContainer: stateInfoContainer ?? this.stateInfoContainer,
      overlayScrim: overlayScrim ?? this.overlayScrim,
      focusRing: focusRing ?? this.focusRing,
    );
  }

  /// Alan alan `Color.lerp`; `brightness` `t < 0.5` ise bu, değilse `other`.
  @override
  GuColors lerp(covariant ThemeExtension<GuColors>? other, double t) {
    if (other is! GuColors) return this;
    return GuColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      brandPrimaryText: Color.lerp(
        brandPrimaryText,
        other.brandPrimaryText,
        t,
      )!,
      brandPrimaryPressed: Color.lerp(
        brandPrimaryPressed,
        other.brandPrimaryPressed,
        t,
      )!,
      brandOnPrimary: Color.lerp(brandOnPrimary, other.brandOnPrimary, t)!,
      brandPrimaryContainer: Color.lerp(
        brandPrimaryContainer,
        other.brandPrimaryContainer,
        t,
      )!,
      brandOnPrimaryContainer: Color.lerp(
        brandOnPrimaryContainer,
        other.brandOnPrimaryContainer,
        t,
      )!,
      bgCanvas: Color.lerp(bgCanvas, other.bgCanvas, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgSurfaceMuted: Color.lerp(bgSurfaceMuted, other.bgSurfaceMuted, t)!,
      bgSurfaceRaised: Color.lerp(bgSurfaceRaised, other.bgSurfaceRaised, t)!,
      borderDefault: Color.lerp(borderDefault, other.borderDefault, t)!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textHeading: Color.lerp(textHeading, other.textHeading, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      stateSuccess: Color.lerp(stateSuccess, other.stateSuccess, t)!,
      stateSuccessContainer: Color.lerp(
        stateSuccessContainer,
        other.stateSuccessContainer,
        t,
      )!,
      stateWarning: Color.lerp(stateWarning, other.stateWarning, t)!,
      stateWarningContainer: Color.lerp(
        stateWarningContainer,
        other.stateWarningContainer,
        t,
      )!,
      stateDanger: Color.lerp(stateDanger, other.stateDanger, t)!,
      stateDangerContainer: Color.lerp(
        stateDangerContainer,
        other.stateDangerContainer,
        t,
      )!,
      stateInfo: Color.lerp(stateInfo, other.stateInfo, t)!,
      stateInfoContainer: Color.lerp(
        stateInfoContainer,
        other.stateInfoContainer,
        t,
      )!,
      overlayScrim: Color.lerp(overlayScrim, other.overlayScrim, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GuColors || other.brightness != brightness) return false;
    final a = props;
    final b = other.props;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(brightness, Object.hashAll(props));
}
