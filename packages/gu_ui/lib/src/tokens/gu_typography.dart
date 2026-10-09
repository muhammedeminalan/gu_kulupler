import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';

/// Tipografi token'ları — `docs/token-map.md` §3 (PLAN §7.2, §7.2.1).
///
/// 43 `TextStyle` alanı: 11 ölçek (`/// registry`, `reg.TYPE_SCALE` =
/// `typography.json#scale`) + 26 CSS bileşen stili (`/// CSS-derived`) + 4 ek
/// (`bannerAction`/`toastAction` CSS, `splashTitle`/`ticketCode` JS — K-46) +
/// 2 boyut tabanı (`avatarInitialsBase`, `donutValueBase`; gerçek boyut
/// [avatarInitialsFor] / [donutValueFor] ile; `avatarMore` için
/// [avatarMoreFor]). `height = line / size` (4 ondalık); `letterSpacing` px
/// cinsinden (`em × fontSize`). Tüm stiller `leadingDistribution:
/// TextLeadingDistribution.even` taşır (CSS yarım satır aralığını üste ve alta
/// eşit dağıtır). Fontlar `assets/fonts` 7 TTF (PLAN §7.10); `package:` öneki
/// olmadan aile adıyla kullanılır.
///
/// Renk CSS'teki gibi bağlanır ([GuTypography.resolve]): `.t-display/.t-title-*` →
/// `textHeading`, `.t-caption/.t-overline` → `textMuted`, gövde/etiket →
/// `textPrimary` (kök `.gu-root{color:var(--text-primary)}` css:77);
/// bileşenler kendi CSS kuralının `color` değerini alır (rengi olmayan kural
/// kökten `textPrimary` devralır). Durum renkleri (seçili/pasif/hata)
/// çağıranda `copyWith(color:)` ile verilir. Erişim: `context.gu.text`
/// (CD-18).
///
/// Ölçeklenmeyen stiller ([nonScalingStyleNames], K-57): prototip bu kuralları
/// `calc(Npx*var(--ts))` yerine sabit px ile yazar; widget bunları
/// `TextScaler.noScaling` ile çizer.
@immutable
final class GuTypography extends ThemeExtension<GuTypography> with Equatable {
  const GuTypography({
    required this.display,
    required this.titleL,
    required this.titleM,
    required this.titleS,
    required this.bodyL,
    required this.bodyM,
    required this.bodyS,
    required this.labelL,
    required this.labelM,
    required this.caption,
    required this.overline,
    required this.button,
    required this.buttonSm,
    required this.buttonLg,
    required this.chip,
    required this.badge,
    required this.countBadge,
    required this.countBadgeLg,
    required this.fieldLabel,
    required this.input,
    required this.fieldHelp,
    required this.segment,
    required this.tab,
    required this.navLabel,
    required this.banner,
    required this.toast,
    required this.swipeAction,
    required this.kpiValue,
    required this.dateBadgeDay,
    required this.dateBadgeMonth,
    required this.calendarHead,
    required this.calendarDay,
    required this.wheel,
    required this.avatarMore,
    required this.quick,
    required this.tooltip,
    required this.mapPlaceholder,
    required this.bannerAction,
    required this.splashTitle,
    required this.ticketCode,
    required this.toastAction,
    required this.avatarInitialsBase,
    required this.donutValueBase,
  });

  /// Renkleri [GuColors]'tan bağlayarak tipografi kümesini kurar
  /// (PLAN §7.9.2: `GuTypography.resolve(GuColors.light | .dark)`).
  ///
  /// token-map §3.2'de `copyWith` ile tanımlı türevler temel stilden
  /// üretilir: `buttonSm`/`buttonLg`/`bannerAction` ← `button`,
  /// `splashTitle` ← `titleL`, `ticketCode` ← `titleS`, `toastAction` ←
  /// `toast`.
  factory GuTypography.resolve(GuColors c) {
    // ── temel stiller (türevlerin kaynağı) ───────────────────────────────
    final titleL = _montserrat(22, FontWeight.w700, 1.2727, c.textHeading);
    final titleS = _montserrat(16, FontWeight.w600, 1.3750, c.textHeading);
    final button = _inter(14, FontWeight.w600, 1.3, c.textPrimary);
    final toast = _inter(13, FontWeight.w500, 1.4, c.bgSurface);

    return GuTypography(
      // ── registry: reg.TYPE_SCALE (css:87–97) ──────────────────────────
      display: _montserrat(28, FontWeight.w700, 1.2143, c.textHeading),
      titleL: titleL,
      titleM: _montserrat(18, FontWeight.w600, 1.3333, c.textHeading),
      titleS: titleS,
      bodyL: _inter(16, FontWeight.w400, 1.5000, c.textPrimary),
      bodyM: _inter(15, FontWeight.w400, 1.4667, c.textPrimary),
      bodyS: _inter(13, FontWeight.w400, 1.3846, c.textPrimary),
      labelL: _inter(14, FontWeight.w600, 1.4286, c.textPrimary),
      labelM: _inter(12, FontWeight.w600, 1.3333, c.textPrimary),
      caption: _inter(12, FontWeight.w500, 1.3333, c.textMuted),
      overline: _montserrat(
        11,
        FontWeight.w600,
        1.2727,
        c.textMuted,
        letterSpacing: _overlineLetterSpacing,
      ),
      // ── CSS-derived: component-css.css `font:` satırları ───────────────
      button: button,
      // `.btn-sm`/`.btn-lg` yalnızca `font-size` değiştirir (css:141).
      buttonSm: button.copyWith(fontSize: 13),
      buttonLg: button.copyWith(fontSize: 16),
      chip: _inter(13, FontWeight.w600, 1.33, c.textPrimary),
      badge: _inter(12, FontWeight.w600, 1, c.textPrimary),
      countBadge: _inter(11, FontWeight.w700, 1.6364, c.brandOnPrimary),
      countBadgeLg: _inter(11, FontWeight.w700, 1.8182, c.brandOnPrimary),
      fieldLabel: _inter(12, FontWeight.w600, 1.33, c.textSecondary),
      input: _inter(15, FontWeight.w400, 1.47, c.textPrimary),
      fieldHelp: _inter(12, FontWeight.w500, 1.33, c.textMuted),
      segment: _inter(13, FontWeight.w600, 1.2, c.textSecondary),
      tab: _inter(14, FontWeight.w600, 1.2, c.textMuted),
      navLabel: _inter(11, FontWeight.w600, 1.2, c.textMuted),
      banner: _inter(13, FontWeight.w500, 1.4, c.textPrimary),
      toast: toast,
      swipeAction: _inter(13, FontWeight.w600, null, c.brandOnPrimary),
      kpiValue: _montserrat(
        26,
        FontWeight.w700,
        1.1,
        c.textHeading,
        fontFeatures: _tabular,
      ),
      dateBadgeDay: _montserrat(
        18,
        FontWeight.w700,
        1,
        c.brandOnPrimaryContainer,
      ),
      dateBadgeMonth: _inter(
        11,
        FontWeight.w600,
        1,
        c.brandOnPrimaryContainer,
      ),
      calendarHead: _inter(11, FontWeight.w600, null, c.textMuted),
      calendarDay: _inter(13, FontWeight.w500, null, c.textPrimary),
      wheel: _montserrat(18, FontWeight.w600, null, c.textMuted),
      avatarMore: _inter(11, FontWeight.w600, null, c.textSecondary),
      quick: _inter(12, FontWeight.w600, 1.3, c.textHeading),
      tooltip: _inter(11, FontWeight.w600, null, c.bgSurface),
      mapPlaceholder: _inter(
        12,
        FontWeight.w500,
        null,
        c.textMuted,
        fontFeatures: _tabular,
      ),
      // ── ek (token-map §3.2 #27–30) ─────────────────────────────────────
      bannerAction: button.copyWith(decoration: TextDecoration.underline),
      splashTitle: titleL.copyWith(letterSpacing: _splashTitleLetterSpacing),
      ticketCode: titleS.copyWith(
        letterSpacing: _ticketCodeLetterSpacing,
        fontFeatures: _tabular,
      ),
      // `.toast .toast-action{font-weight:700}` css:293; aile/boyut/satır
      // `.toast`'tan (düğme `font:inherit` css:79).
      toastAction: toast.copyWith(fontWeight: FontWeight.w700),
      // ── boyut tabanları (fontSize çağrıda: *For(size)) ─────────────────
      avatarInitialsBase: _montserrat(
        null,
        FontWeight.w700,
        null,
        c.brandOnPrimary,
      ),
      donutValueBase: _montserrat(null, FontWeight.w700, null, c.textHeading),
    );
  }

  /// Başlık ailesi (Montserrat 400/500/600/700 — `assets/fonts`, PLAN §7.10).
  static const String fontFamilyMontserrat = 'Montserrat';

  /// Gövde ailesi (Inter 400/500/600 — `assets/fonts`, PLAN §7.10); kök
  /// `.gu-root{font-family:Inter}` css:77.
  static const String fontFamilyInter = 'Inter';

  /// Prototipte sabit px ile yazılan (`--ts` ile ölçeklenmeyen) stiller
  /// (K-57): css:137/157/186 `countBadge`, css:200 `countBadgeLg`, css:218 +
  /// art.js:50 `avatarMore`, css:317 `calendarHead`, css:319
  /// `dateBadgeMonth`, css:337 `swipeAction`, css:341 `tooltip`, css:410
  /// `mapPlaceholder`, art.js:45 `avatarInitialsBase`, ui.js:93
  /// `donutValueBase` (SVG `font-size`). Widget bu stilleri
  /// `TextScaler.noScaling` ile çizer.
  static const Set<String> nonScalingStyleNames = {
    'countBadge',
    'countBadgeLg',
    'avatarMore',
    'calendarHead',
    'dateBadgeMonth',
    'swipeAction',
    'tooltip',
    'mapPlaceholder',
    'avatarInitialsBase',
    'donutValueBase',
  };

  /// Aile yedeği — CSS `Montserrat,sans-serif` / `Inter,sans-serif`
  /// (css:87–97; PLAN §7.2: yalnızca token dosyasında).
  static const List<String> _fallback = ['sans-serif'];

  /// `font-variant-numeric: tabular-nums` (`.tnum` css:99).
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// registry `overline.letterSpacing` `0.08em` × 11 px (css:97).
  static const double _overlineLetterSpacing = 0.88;

  /// JS-derived — SYS-01 `letter-spacing:.04em` × 22 px
  /// (screens-auth.js:33, shell.js:35).
  static const double _splashTitleLetterSpacing = 0.88;

  /// JS-derived — EVT-03 bilet kodu `letter-spacing:.12em` × 16 px
  /// (screens-events.js:83, K-46).
  static const double _ticketCodeLetterSpacing = 1.92;

  /// CSS-derived — `.avatar{letter-spacing:.02em}` (css:217).
  static const double _avatarLetterSpacingEm = 0.02;

  static TextStyle _montserrat(
    double? size,
    FontWeight weight,
    double? height,
    Color color, {
    double letterSpacing = 0,
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    color: color,
    fontFamily: fontFamilyMontserrat,
    fontFamilyFallback: _fallback,
    fontSize: size,
    fontWeight: weight,
    height: height,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: letterSpacing,
    fontFeatures: fontFeatures,
  );

  static TextStyle _inter(
    double size,
    FontWeight weight,
    double? height,
    Color color, {
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    color: color,
    fontFamily: fontFamilyInter,
    fontFamilyFallback: _fallback,
    fontSize: size,
    fontWeight: weight,
    height: height,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    fontFeatures: fontFeatures,
  );

  // ── registry — reg.TYPE_SCALE (11) ─────────────────────────────────────

  /// registry `display` — Montserrat 700 28/34, `textHeading` (css:87).
  final TextStyle display;

  /// registry `titleL` — Montserrat 700 22/28, `textHeading` (css:88).
  final TextStyle titleL;

  /// registry `titleM` — Montserrat 600 18/24, `textHeading` (css:89).
  final TextStyle titleM;

  /// registry `titleS` — Montserrat 600 16/22, `textHeading` (css:90).
  final TextStyle titleS;

  /// registry `bodyL` — Inter 400 16/24, `textPrimary` (css:91).
  final TextStyle bodyL;

  /// registry `bodyM` — Inter 400 15/22, `textPrimary` (css:92; kök css:77).
  final TextStyle bodyM;

  /// registry `bodyS` — Inter 400 13/18, `textPrimary` (css:93).
  final TextStyle bodyS;

  /// registry `labelL` — Inter 600 14/20, `textPrimary` (css:94).
  final TextStyle labelL;

  /// registry `labelM` — Inter 600 12/16, `textPrimary` (css:95).
  final TextStyle labelM;

  /// registry `caption` — Inter 500 12/16, `textMuted` (css:96).
  final TextStyle caption;

  /// registry `overline` — Montserrat 600 11/14, `letterSpacing` 0.88,
  /// `textMuted` (css:97). Büyük harfi çağıran uygular: `upperFor(locale)`
  /// (CD-11).
  final TextStyle overline;

  // ── CSS-derived — component-css.css (26) ───────────────────────────────

  /// CSS-derived `.btn` `600 14px/1.3 Inter` (css:139; `.fab` css:158).
  final TextStyle button;

  /// CSS-derived `.btn-sm` `font-size:13px` + `.btn` (css:141) =
  /// `button.copyWith(fontSize: 13)`.
  final TextStyle buttonSm;

  /// CSS-derived `.btn-lg` `font-size:16px` + `.btn` (css:141) =
  /// `button.copyWith(fontSize: 16)`.
  final TextStyle buttonLg;

  /// CSS-derived `.chip` `600 13px/1.33 Inter`, `textPrimary` (css:176).
  final TextStyle chip;

  /// CSS-derived `.badge` `600 12px/1 Inter` (css:188); renk türe göre.
  final TextStyle badge;

  /// CSS-derived `.nav-badge`/`.dot-badge`/`.chip-count` `700 11px/18px`,
  /// `#fff` = `brandOnPrimary` (css:137, 157, 186).
  /// Inter 700 paketli değil (D-12) → Flutter en yakın 600'ü çizer (K-56).
  /// **Ölçeklenmez (K-57)**: widget `TextScaler.noScaling` ile çizer.
  final TextStyle countBadge;

  /// CSS-derived `.badge-count` `700 11px/20px`, `#fff` (css:200).
  /// Inter 700 paketli değil (D-12) → Flutter en yakın 600'ü çizer (K-56).
  /// **Ölçeklenmez (K-57)**: widget `TextScaler.noScaling` ile çizer.
  final TextStyle countBadgeLg;

  /// CSS-derived `.field-label` `600 12px/1.33`, `textSecondary` (css:162).
  final TextStyle fieldLabel;

  /// CSS-derived `.input input` `400 15px/1.47`, `textPrimary` (css:166);
  /// yer tutucu `textMuted` (css:167).
  final TextStyle input;

  /// CSS-derived `.field-help` `500 12px/1.33`, `textMuted` (css:171);
  /// `.field-counter` (css:172) aynı yazı + `tabularFigures`, hata
  /// `stateDanger`.
  final TextStyle fieldHelp;

  /// CSS-derived `.seg>button` `600 13px/1.2`, pasif `textSecondary`
  /// (css:221; seçili `textHeading` css:222).
  final TextStyle segment;

  /// CSS-derived `.tabs>button` `600 14px/1.2`, pasif `textMuted`
  /// (css:226; seçili `brandPrimaryText` css:227).
  final TextStyle tab;

  /// CSS-derived `.bottomnav>button` `600 11px/1.2`, pasif `textMuted`
  /// (css:134; aktif `brandPrimaryText` css:135).
  final TextStyle navLabel;

  /// CSS-derived `.banner` `500 13px/1.4` (css:248); renk türe göre
  /// (css:250–255).
  final TextStyle banner;

  /// CSS-derived `.toast` `500 13px/1.4`, metin `bgSurface` (css:290).
  final TextStyle toast;

  /// CSS-derived `.notif-under` `600 13px`, `#fff` (css:337).
  /// **Ölçeklenmez (K-57)**: widget `TextScaler.noScaling` ile çizer.
  final TextStyle swipeAction;

  /// CSS-derived `.kpi .kpi-value` `700 26px/1.1 Montserrat`, tabular,
  /// `textHeading` (css:303; `is-accent` → `brandPrimaryText` css:304).
  final TextStyle kpiValue;

  /// CSS-derived `.date-badge b` `700 18px/1 Montserrat`;
  /// `brandOnPrimaryContainer` (css:318–319).
  final TextStyle dateBadgeDay;

  /// CSS-derived `.date-badge span` `600 11px/1 Inter`, büyük harf çağıranda
  /// (`upperFor(locale)`); `brandOnPrimaryContainer` (css:318–319).
  /// **Ölçeklenmez (K-57)**: widget `TextScaler.noScaling` ile çizer.
  final TextStyle dateBadgeMonth;

  /// CSS-derived `.cal-head` `600 11px Inter`, `textMuted` (css:317).
  /// **Ölçeklenmez (K-57)**: widget `TextScaler.noScaling` ile çizer.
  final TextStyle calendarHead;

  /// CSS-derived `.cal-day` `500 13px Inter`, `textPrimary` (css:314).
  final TextStyle calendarDay;

  /// CSS-derived `.wheel>button` `600 18px Montserrat`, pasif `textMuted`
  /// (css:322; seçili `textHeading`).
  final TextStyle wheel;

  /// CSS-derived `.avatar-group .more` `600 11px Inter`, `textSecondary`
  /// (css:218; gerçek boyut `max(10, round(size × .38))` art.js:50 →
  /// [avatarMoreFor]).
  /// **Ölçeklenmez (K-57)**: widget `TextScaler.noScaling` ile çizer.
  final TextStyle avatarMore;

  /// CSS-derived `.quick` `600 12px/1.3 Inter`, `textHeading` (css:305).
  final TextStyle quick;

  /// CSS-derived `.tooltip` `600 11px Inter`, metin `bgSurface` (css:341).
  /// **Ölçeklenmez (K-57)**: widget `TextScaler.noScaling` ile çizer.
  final TextStyle tooltip;

  /// CSS-derived `.map-ph` `500 12px` — CSS `ui-monospace` yerine Inter +
  /// tabular (CD-19, K-26), `textMuted` (css:410).
  /// **Ölçeklenmez (K-57)**: widget `TextScaler.noScaling` ile çizer.
  final TextStyle mapPlaceholder;

  // ── ek (token-map §3.2 #27–30) ─────────────────────────────────────────

  /// CSS-derived `.banner .btn-text` altı çizili, `.btn` yazısı
  /// (css:257 + css:139) = `button.copyWith(decoration: underline)`; renk
  /// banner metniyle aynı (`inherit`).
  final TextStyle bannerAction;

  /// JS-derived SYS-01 `t-title-l` + `letter-spacing:.04em`
  /// (screens-auth.js:33, shell.js:35) = `titleL.copyWith(letterSpacing:)`.
  final TextStyle splashTitle;

  /// JS-derived EVT-03 bilet kodu `t-title-s tnum` + `letter-spacing:.12em`
  /// (screens-events.js:83, K-46) = `titleS.copyWith(letterSpacing:,
  /// fontFeatures: tabular)`.
  final TextStyle ticketCode;

  /// CSS-derived toast eylem düğmesi (`Geri al`, eylem etiketi):
  /// `.toast .toast-action{font-weight:700}` css:293 + `.toast` yazısı
  /// `500 13px/1.4 Inter` css:290 (düğme `font:inherit` css:79) =
  /// `toast.copyWith(fontWeight: w700)`. Renk `bgSurface` =
  /// `GuComponentColors.toastActionForeground` (açık `#FFF` css:293, koyu
  /// `#1E2024` CD-98/K-41); toast widget'ı component rengini uygular.
  /// Inter 700 paketli değil (D-12) → Flutter en yakın 600'ü çizer (K-56).
  final TextStyle toastAction;

  // ── boyut tabanları (fontSize null) ────────────────────────────────────

  /// JS-derived avatar baş harfi tabanı — `.avatar` `700 Montserrat`, `#fff`
  /// (css:217); boyut için [avatarInitialsFor]. Renk
  /// `GuComponentColors.avatarInitials` ile aynı (`#FFF`, css `.avatar`);
  /// `GuAvatar` (T-04) component rengini uygular.
  /// **Ölçeklenmez (K-57)**: widget `TextScaler.noScaling` ile çizer.
  final TextStyle avatarInitialsBase;

  /// JS-derived donut yüzde tabanı — Montserrat 700, `textHeading`
  /// (ui.js:93); boyut için [donutValueFor].
  /// **Ölçeklenmez (K-57)**: widget `TextScaler.noScaling` ile çizer.
  final TextStyle donutValueBase;

  /// Avatar baş harfi stili: `fontSize = round(size ×
  /// GuSizes.avatarInitialsRatio)` (art.js:45), `letterSpacing = fontSize ×
  /// 0.02` (css:217).
  TextStyle avatarInitialsFor(double size) {
    final fontSize = (size * GuSizes.avatarInitialsRatio).roundToDouble();
    return avatarInitialsBase.copyWith(
      fontSize: fontSize,
      letterSpacing: fontSize * _avatarLetterSpacingEm,
    );
  }

  /// Avatar grubu "+N" stili: `fontSize = max(GuSizes.avatarMoreMinFont,
  /// round(size × GuSizes.avatarMoreFontRatio))` (art.js:50); taban
  /// [avatarMore].
  TextStyle avatarMoreFor(double size) => avatarMore.copyWith(
    fontSize: math.max(
      GuSizes.avatarMoreMinFont,
      (size * GuSizes.avatarMoreFontRatio).roundToDouble(),
    ),
  );

  /// Donut yüzde stili: `fontSize = size / GuSizes.donutValueDivisor`
  /// (ui.js:93).
  TextStyle donutValueFor(double size) =>
      donutValueBase.copyWith(fontSize: size / GuSizes.donutValueDivisor);

  /// 43 alan, tanım sırasıyla (`Equatable` eşitliği).
  @override
  List<Object?> get props => [
    display,
    titleL,
    titleM,
    titleS,
    bodyL,
    bodyM,
    bodyS,
    labelL,
    labelM,
    caption,
    overline,
    button,
    buttonSm,
    buttonLg,
    chip,
    badge,
    countBadge,
    countBadgeLg,
    fieldLabel,
    input,
    fieldHelp,
    segment,
    tab,
    navLabel,
    banner,
    toast,
    swipeAction,
    kpiValue,
    dateBadgeDay,
    dateBadgeMonth,
    calendarHead,
    calendarDay,
    wheel,
    avatarMore,
    quick,
    tooltip,
    mapPlaceholder,
    bannerAction,
    splashTitle,
    ticketCode,
    toastAction,
    avatarInitialsBase,
    donutValueBase,
  ];

  @override
  GuTypography copyWith({
    TextStyle? display,
    TextStyle? titleL,
    TextStyle? titleM,
    TextStyle? titleS,
    TextStyle? bodyL,
    TextStyle? bodyM,
    TextStyle? bodyS,
    TextStyle? labelL,
    TextStyle? labelM,
    TextStyle? caption,
    TextStyle? overline,
    TextStyle? button,
    TextStyle? buttonSm,
    TextStyle? buttonLg,
    TextStyle? chip,
    TextStyle? badge,
    TextStyle? countBadge,
    TextStyle? countBadgeLg,
    TextStyle? fieldLabel,
    TextStyle? input,
    TextStyle? fieldHelp,
    TextStyle? segment,
    TextStyle? tab,
    TextStyle? navLabel,
    TextStyle? banner,
    TextStyle? toast,
    TextStyle? swipeAction,
    TextStyle? kpiValue,
    TextStyle? dateBadgeDay,
    TextStyle? dateBadgeMonth,
    TextStyle? calendarHead,
    TextStyle? calendarDay,
    TextStyle? wheel,
    TextStyle? avatarMore,
    TextStyle? quick,
    TextStyle? tooltip,
    TextStyle? mapPlaceholder,
    TextStyle? bannerAction,
    TextStyle? splashTitle,
    TextStyle? ticketCode,
    TextStyle? toastAction,
    TextStyle? avatarInitialsBase,
    TextStyle? donutValueBase,
  }) {
    return GuTypography(
      display: display ?? this.display,
      titleL: titleL ?? this.titleL,
      titleM: titleM ?? this.titleM,
      titleS: titleS ?? this.titleS,
      bodyL: bodyL ?? this.bodyL,
      bodyM: bodyM ?? this.bodyM,
      bodyS: bodyS ?? this.bodyS,
      labelL: labelL ?? this.labelL,
      labelM: labelM ?? this.labelM,
      caption: caption ?? this.caption,
      overline: overline ?? this.overline,
      button: button ?? this.button,
      buttonSm: buttonSm ?? this.buttonSm,
      buttonLg: buttonLg ?? this.buttonLg,
      chip: chip ?? this.chip,
      badge: badge ?? this.badge,
      countBadge: countBadge ?? this.countBadge,
      countBadgeLg: countBadgeLg ?? this.countBadgeLg,
      fieldLabel: fieldLabel ?? this.fieldLabel,
      input: input ?? this.input,
      fieldHelp: fieldHelp ?? this.fieldHelp,
      segment: segment ?? this.segment,
      tab: tab ?? this.tab,
      navLabel: navLabel ?? this.navLabel,
      banner: banner ?? this.banner,
      toast: toast ?? this.toast,
      swipeAction: swipeAction ?? this.swipeAction,
      kpiValue: kpiValue ?? this.kpiValue,
      dateBadgeDay: dateBadgeDay ?? this.dateBadgeDay,
      dateBadgeMonth: dateBadgeMonth ?? this.dateBadgeMonth,
      calendarHead: calendarHead ?? this.calendarHead,
      calendarDay: calendarDay ?? this.calendarDay,
      wheel: wheel ?? this.wheel,
      avatarMore: avatarMore ?? this.avatarMore,
      quick: quick ?? this.quick,
      tooltip: tooltip ?? this.tooltip,
      mapPlaceholder: mapPlaceholder ?? this.mapPlaceholder,
      bannerAction: bannerAction ?? this.bannerAction,
      splashTitle: splashTitle ?? this.splashTitle,
      ticketCode: ticketCode ?? this.ticketCode,
      toastAction: toastAction ?? this.toastAction,
      avatarInitialsBase: avatarInitialsBase ?? this.avatarInitialsBase,
      donutValueBase: donutValueBase ?? this.donutValueBase,
    );
  }

  /// Alan alan `TextStyle.lerp` (PLAN §7.9.2).
  @override
  GuTypography lerp(covariant ThemeExtension<GuTypography>? other, double t) {
    if (other is! GuTypography) return this;
    TextStyle mix(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return GuTypography(
      display: mix(display, other.display),
      titleL: mix(titleL, other.titleL),
      titleM: mix(titleM, other.titleM),
      titleS: mix(titleS, other.titleS),
      bodyL: mix(bodyL, other.bodyL),
      bodyM: mix(bodyM, other.bodyM),
      bodyS: mix(bodyS, other.bodyS),
      labelL: mix(labelL, other.labelL),
      labelM: mix(labelM, other.labelM),
      caption: mix(caption, other.caption),
      overline: mix(overline, other.overline),
      button: mix(button, other.button),
      buttonSm: mix(buttonSm, other.buttonSm),
      buttonLg: mix(buttonLg, other.buttonLg),
      chip: mix(chip, other.chip),
      badge: mix(badge, other.badge),
      countBadge: mix(countBadge, other.countBadge),
      countBadgeLg: mix(countBadgeLg, other.countBadgeLg),
      fieldLabel: mix(fieldLabel, other.fieldLabel),
      input: mix(input, other.input),
      fieldHelp: mix(fieldHelp, other.fieldHelp),
      segment: mix(segment, other.segment),
      tab: mix(tab, other.tab),
      navLabel: mix(navLabel, other.navLabel),
      banner: mix(banner, other.banner),
      toast: mix(toast, other.toast),
      swipeAction: mix(swipeAction, other.swipeAction),
      kpiValue: mix(kpiValue, other.kpiValue),
      dateBadgeDay: mix(dateBadgeDay, other.dateBadgeDay),
      dateBadgeMonth: mix(dateBadgeMonth, other.dateBadgeMonth),
      calendarHead: mix(calendarHead, other.calendarHead),
      calendarDay: mix(calendarDay, other.calendarDay),
      wheel: mix(wheel, other.wheel),
      avatarMore: mix(avatarMore, other.avatarMore),
      quick: mix(quick, other.quick),
      tooltip: mix(tooltip, other.tooltip),
      mapPlaceholder: mix(mapPlaceholder, other.mapPlaceholder),
      bannerAction: mix(bannerAction, other.bannerAction),
      splashTitle: mix(splashTitle, other.splashTitle),
      ticketCode: mix(ticketCode, other.ticketCode),
      toastAction: mix(toastAction, other.toastAction),
      avatarInitialsBase: mix(avatarInitialsBase, other.avatarInitialsBase),
      donutValueBase: mix(donutValueBase, other.donutValueBase),
    );
  }
}
