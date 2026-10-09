/// Boyut token'ları — `docs/token-map.md` §8.1–§8.10 (PLAN §7.7; CD-97).
///
/// Görsel ölçülerdir; etkin dokunma alanı `GuTapTarget` ile ≥ 44/48 tutulur
/// (D-22, K-03). Ad kuralı `<bileşen><Özellik>[<Varyant>]`. Gruplar (CD-20):
///
/// * **CSS-derived** — `component-css.css` kuralından ölçülür (`css:N`).
/// * **JS-derived** — prototip bileşenlerinin satır içi değerleri
///   (`ui.js:N`, `cards.js:N`, …) ve `Icon size=` dağılımı (§8.7).
/// * **Platform-derived** — platform dokunma hedefleri (D-22, CD-97).
///
/// Registry'de (`registry.json#tokens`) boyut grubu yoktur. Sayaç/adet
/// sabitleri (`textareaRows`, `avatarGroupMax`, `calendarDotsMax`,
/// `calendarWeeks`) tüketici imzaları `int` beklediği için `int`'tir.
/// Token testi: `test/tokens/gu_sizes_test.dart` (tablo uzunluğu 402).
abstract final class GuSizes {
  // ===========================================================================
  // CSS-derived (CD-20) — `design/extracted/component-css.css`; `css:N` = satır.
  // ===========================================================================

  // ── §8.1 Uygulama çubuğu, alt sekme, yapışkan CTA (`ds_nav.webp`) ──

  /// css:127 `.appbar{min-height:56px}`.
  static const double appBarMinHeight = 56;

  /// css:127 `.appbar{padding:4px 8px}`.
  static const double appBarPaddingY = 4;

  /// css:127 `.appbar{padding:4px 8px}`.
  static const double appBarPaddingX = 8;

  /// css:127 `.appbar{gap:4px}`.
  static const double appBarGap = 4;

  /// css:129 `.appbar-title{padding:0 8px}`.
  static const double appBarTitlePaddingX = 8;

  /// css:130 `.appbar-large{padding:8px 16px 12px}`.
  static const double appBarLargePaddingTop = 8;

  /// css:130 `.appbar-large{padding:8px 16px 12px}`.
  static const double appBarLargePaddingX = 16;

  /// css:130 `.appbar-large{padding:8px 16px 12px}`.
  static const double appBarLargePaddingBottom = 12;

  /// css:128 `.appbar.is-surface{border-bottom:1px solid var(--border-soft)}`.
  static const double appBarBorder = 1;

  /// css:134 `.bottomnav>button{min-height:56px}` —
  /// `--nav-h:84` = 56 + mock `--safe-bottom:28`; gerçek `viewPadding.bottom` eklenir (K-07).
  static const double bottomNavHeight = 56;

  /// css:134 `.bottomnav>button{gap:3px}`.
  static const double bottomNavGap = 3;

  /// css:133 `.bottomnav{border-top:1px solid var(--border-soft)}`.
  static const double bottomNavBorder = 1;

  /// css:136 `.bottomnav>button[aria-current="page"]::before{width:28px}`.
  static const double bottomNavIndicatorWidth = 28;

  /// css:136 `.bottomnav>button[aria-current="page"]::before{height:3px}`.
  static const double bottomNavIndicatorHeight = 3;

  /// css:137 `.nav-badge{min-width:18px}`.
  static const double navBadgeMinWidth = 18;

  /// css:137 `.nav-badge{height:18px}`.
  static const double navBadgeHeight = 18;

  /// css:137 `.nav-badge{padding:0 5px}`.
  static const double navBadgePaddingX = 5;

  /// css:137 `.nav-badge{border:2px solid var(--bg-surface)}`.
  static const double navBadgeBorder = 2;

  /// css:137 `.nav-badge{top:6px}`.
  static const double navBadgeTop = 6;

  /// css:137 `.nav-badge{left:calc(50% + 4px)}` —
  /// `left:calc(50% + 4px)` → ortadan +4.
  static const double navBadgeOffsetX = 4;

  /// css:296 `.ctabar{padding:12px 16px calc(12px + var(--safe-bottom))}` —
  /// alt dolguya `viewPadding.bottom` eklenir; `.in-nav` 12 (css:297).
  static const double ctaBarPaddingY = 12;

  /// css:296 `.ctabar{padding:12px 16px calc(12px + var(--safe-bottom))}`.
  static const double ctaBarPaddingX = 16;

  /// css:296 `.ctabar{gap:12px}`.
  static const double ctaBarGap = 12;

  /// css:296 `.ctabar{border-top:1px solid var(--border-soft)}`.
  static const double ctaBarBorder = 1;

  // ── §8.2 Düğmeler (`ds_buttons.webp`) ──

  /// css:139 `.btn{min-height:48px}` —
  /// min-height (K-08).
  static const double buttonHeight = 48;

  /// css:141 `.btn-sm{min-height:40px}`.
  static const double buttonHeightSm = 40;

  /// css:141 `.btn-lg{min-height:56px}`.
  static const double buttonHeightLg = 56;

  /// css:139 `.btn{padding:0 20px}`.
  static const double buttonPaddingX = 20;

  /// css:141 `.btn-sm{padding:0 14px}`.
  static const double buttonPaddingXSm = 14;

  /// css:141 `.btn-lg{padding:0 24px}`.
  static const double buttonPaddingXLg = 24;

  /// css:139 `.btn{gap:8px}`.
  static const double buttonGap = 8;

  /// css:144 `.btn-outline{border:1px solid var(--border-default)}` —
  /// `.btn-danger-outline` aynı (css:146).
  static const double buttonBorder = 1;

  /// css:145 `.btn-text{min-height:44px}`.
  static const double textButtonHeight = 44;

  /// css:145 `.btn-text{padding:0 12px}`.
  static const double textButtonPaddingX = 12;

  /// css:148 `.btn-ghost{padding:0 12px}`.
  static const double ghostButtonPaddingX = 12;

  /// css:257 `.banner .btn-text{min-height:36px}`.
  static const double bannerTextButtonHeight = 36;

  /// css:257 `.banner .btn-text{padding:0 10px}`.
  static const double bannerTextButtonPaddingX = 10;

  /// css:153 `.spinner{width:20px}`.
  static const double spinner = 20;

  /// css:153 `.spinner{border:2.5px solid currentColor}` —
  /// 270° yay (`border-right-color:transparent`).
  static const double spinnerStroke = 2.5;

  /// css:82 `.gu-root :focus-visible{outline:2px solid var(--focus-ring)}` —
  /// `.btn.is-focus` aynı (css:150).
  static const double focusRingWidth = 2;

  /// css:82 `.gu-root :focus-visible{outline-offset:2px}`.
  static const double focusRingOffset = 2;

  /// css:154 `.iconbtn{width:48px}`.
  static const double iconButton = 48;

  /// css:156 `.iconbtn.is-sm{width:40px}`.
  static const double iconButtonSm = 40;

  /// css:157 `.iconbtn .dot-badge{top:8px}`.
  static const double dotBadgeTop = 8;

  /// css:157 `.iconbtn .dot-badge{right:8px}`.
  static const double dotBadgeRight = 8;

  /// css:157 `.iconbtn .dot-badge{min-width:18px}`.
  static const double dotBadgeMinWidth = 18;

  /// css:157 `.iconbtn .dot-badge{height:18px}`.
  static const double dotBadgeHeight = 18;

  /// css:157 `.iconbtn .dot-badge{padding:0 5px}`.
  static const double dotBadgePaddingX = 5;

  /// css:155 `.iconbtn.on-cover{backdrop-filter:blur(6px)}` —
  /// `BackdropFilter` sigma.
  static const double onCoverBlur = 6;

  /// css:158 `.fab{height:56px}` —
  /// radius `GuRadius.md`.
  static const double fabHeight = 56;

  /// css:158 `.fab{padding:0 20px 0 16px}`.
  static const double fabPaddingLeft = 16;

  /// css:158 `.fab{padding:0 20px 0 16px}`.
  static const double fabPaddingRight = 20;

  /// css:158 `.fab{gap:8px}`.
  static const double fabGap = 8;

  /// css:158 `.fab{right:16px}` —
  /// alt: `viewPadding.bottom + 16`.
  static const double fabMargin = 16;

  /// css:305 `.quick{padding:14px 8px}`.
  static const double quickPaddingY = 14;

  /// css:305 `.quick{padding:14px 8px}`.
  static const double quickPaddingX = 8;

  /// css:305 `.quick{gap:8px}`.
  static const double quickGap = 8;

  /// css:306 `.quick .quick-icon{width:40px}` —
  /// kutu radius `GuRadius.sm`.
  static const double quickIconBox = 40;

  /// css:305 `.quick{border:1px solid var(--border-soft)}`.
  static const double quickBorder = 1;

  // ── §8.3 Girdiler (`ds_inputs.webp`, `ds_selection.webp`) ──

  /// css:161 `.field{gap:6px}`.
  static const double fieldGap = 6;

  /// css:163 `.input{min-height:48px}`.
  static const double inputHeight = 48;

  /// css:163 `.input{padding:0 14px}`.
  static const double inputPaddingX = 14;

  /// css:163 `.input{gap:8px}`.
  static const double inputGap = 8;

  /// css:163 `.input{border:1px solid transparent}`.
  static const double inputBorder = 1;

  /// css:169 `.input.is-multiline{padding:12px 14px}`.
  static const double inputMultilinePaddingY = 12;

  /// css:169 `.input textarea{min-height:88px}`.
  static const double textareaMinHeight = 88;

  /// css:171 `.field-help{gap:4px}`.
  static const double fieldHelpGap = 4;

  /// css:173 `.picker{min-height:48px}`.
  static const double pickerHeight = 48;

  /// css:173 `.picker{padding:0 14px}`.
  static const double pickerPaddingX = 14;

  /// css:231 `.switch{width:44px}`.
  static const double switchWidth = 44;

  /// css:231 `.switch{height:26px}`.
  static const double switchHeight = 26;

  /// css:234 `.switch>i{width:20px}`.
  static const double switchThumb = 20;

  /// css:234 `.switch>i{top:3px}`.
  static const double switchThumbInset = 3;

  /// css:235 `.switch[aria-checked="true"]>i{transform:translateX(18px)}`.
  static const double switchThumbTravel = 18;

  /// css:232 `.switch::after{inset:-11px -4px}` —
  /// → `GuTapTarget` 52×48.
  static const double switchHitInsetY = 11;

  /// css:232 `.switch::after{inset:-11px -4px}`.
  static const double switchHitInsetX = 4;

  /// css:237 `.check{width:22px}` —
  /// `.radio` aynı.
  static const double checkbox = 22;

  /// css:237 `.check{border:2px solid var(--text-muted)}`.
  static const double checkboxBorder = 2;

  /// css:241 `.radio[aria-checked="true"]>i{width:12px}`.
  static const double radioDot = 12;

  /// css:239 `.check::after{inset:-13px}` —
  /// → 48×48.
  static const double checkHitInset = 13;

  /// css:243 `.option-row{min-height:52px}`.
  static const double optionRowMinHeight = 52;

  /// css:243 `.option-row{padding:6px 16px}`.
  static const double optionRowPaddingY = 6;

  /// css:243 `.option-row{padding:6px 16px}`.
  static const double optionRowPaddingX = 16;

  /// css:243 `.option-row{gap:12px}`.
  static const double optionRowGap = 12;

  /// css:245 `.option-card{padding:14px 16px}`.
  static const double optionCardPaddingY = 14;

  /// css:245 `.option-card{padding:14px 16px}`.
  static const double optionCardPaddingX = 16;

  /// css:245 `.option-card{gap:12px}`.
  static const double optionCardGap = 12;

  /// css:245 `.option-card{border:1px solid var(--border-default)}`.
  static const double optionCardBorder = 1;

  /// css:220 `.seg{padding:3px}`.
  static const double segmentPadding = 3;

  /// css:220 `.seg{gap:2px}`.
  static const double segmentGap = 2;

  /// css:221 `.seg>button{min-height:40px}`.
  static const double segmentHeight = 40;

  /// css:221 `.seg>button{padding:0 8px}`.
  static const double segmentPaddingX = 8;

  /// css:221 `.seg>button{gap:6px}`.
  static const double segmentItemGap = 6;

  /// css:226 `.tabs>button{min-height:48px}`.
  static const double tabHeight = 48;

  /// css:226 `.tabs>button{padding:0 8px}`.
  static const double tabPaddingX = 8;

  /// css:229 `.tabs.is-scroll>button{padding:0 16px}`.
  static const double tabPaddingXScroll = 16;

  /// css:226 `.tabs>button{gap:6px}`.
  static const double tabGap = 6;

  /// css:228 `.tabs>button[aria-selected="true"]::after{height:2px}`.
  static const double tabIndicatorHeight = 2;

  /// css:228 `.tabs>button[aria-selected="true"]::after{left:16px}`.
  static const double tabIndicatorInset = 16;

  /// css:224 `.tabs{border-bottom:1px solid var(--border-soft)}`.
  static const double tabBorder = 1;

  /// css:228 `.tabs>button[aria-selected="true"]::after{bottom:-1px}` —
  /// **ek** — gösterge alt kenarlığın üstüne biner (`bottom:-1px`).
  static const double tabIndicatorBottomOverlap = 1;

  /// css:320 `.stepbar{gap:6px}`.
  static const double stepbarGap = 6;

  /// css:320 `.stepbar>i{height:4px}`.
  static const double stepbarHeight = 4;

  /// css:321 `.wheel{height:160px}`.
  static const double wheelHeight = 160;

  /// css:322 `.wheel>button{height:40px}`.
  static const double wheelItemHeight = 40;

  /// css:321 `.wheel{mask-image:linear-gradient(transparent,#000 30%,#000 70%,transparent)}`.
  static const double wheelMaskStart = 0.3;

  /// css:321 `.wheel{mask-image:linear-gradient(transparent,#000 30%,#000 70%,transparent)}`.
  static const double wheelMaskEnd = 0.7;

  // ── §8.4 Çip, rozet, nokta (`ds_badges.webp`, `ds_selection.webp`) ──

  /// css:176 `.chip{min-height:38px}`.
  static const double chipHeight = 38;

  /// css:176 `.chip{padding:0 14px}`.
  static const double chipPaddingX = 14;

  /// css:176 `.chip{gap:6px}`.
  static const double chipGap = 6;

  /// css:176 `.chip{border:1px solid var(--border-default)}`.
  static const double chipBorder = 1;

  /// css:179 `.chip::after{inset:-6px}`.
  static const double chipHitInset = 6;

  /// css:186 `.chip .chip-count{min-width:18px}`.
  static const double chipCountMinWidth = 18;

  /// css:186 `.chip .chip-count{height:18px}`.
  static const double chipCountHeight = 18;

  /// css:186 `.chip .chip-count{padding:0 5px}`.
  static const double chipCountPaddingX = 5;

  /// css:188 `.badge{height:22px}`.
  static const double badgeHeight = 22;

  /// css:188 `.badge{padding:0 8px}`.
  static const double badgePaddingX = 8;

  /// css:188 `.badge{gap:4px}`.
  static const double badgeGap = 4;

  /// css:190 `.badge-board{border:1px solid var(--border-default)}`.
  static const double badgeBorder = 1;

  /// css:200 `.badge-count{min-width:20px}`.
  static const double countBadgeMinWidth = 20;

  /// css:200 `.badge-count{height:20px}`.
  static const double countBadgeHeight = 20;

  /// css:200 `.badge-count{padding:0 6px}`.
  static const double countBadgePaddingX = 6;

  /// css:201 `.dot{width:8px}`.
  static const double dot = 8;

  /// css:107 `.hit::after{inset:-6px}`.
  static const double hitInset = 6;

  // ── §8.5 Kart, satır, avatar, görsel bileşenler (`ds_cards.webp`, `ds_special.webp`, `ds_feedback.webp`) ──

  /// css:203 `.card{border:1px solid var(--border-soft)}`.
  static const double cardBorder = 1;

  /// css:207 `.card-body{padding:16px}`.
  static const double cardBodyPadding = 16;

  /// css:426 `@keyframes highlight{0%{box-shadow:0 0 0 3px var(--brand-primary)}}`.
  static const double highlightRingWidth = 3;

  /// css:211 `.tile{min-height:56px}`.
  static const double tileMinHeight = 56;

  /// css:211 `.tile{padding:8px 16px}`.
  static const double tilePaddingY = 8;

  /// css:211 `.tile{padding:8px 16px}`.
  static const double tilePaddingX = 16;

  /// css:211 `.tile{gap:12px}`.
  static const double tileGap = 12;

  /// css:214 `.tile.in-card{padding:10px 16px}`.
  static const double tileInCardPaddingY = 10;

  /// css:215 `.group-head{padding:12px 16px 6px}`.
  static const double groupHeadPaddingTop = 12;

  /// css:215 `.group-head{padding:12px 16px 6px}`.
  static const double groupHeadPaddingX = 16;

  /// css:215 `.group-head{padding:12px 16px 6px}`.
  static const double groupHeadPaddingBottom = 6;

  /// css:108 `.section-title{margin:24px 0 12px}`.
  static const double sectionTitleMarginTop = 24;

  /// css:108 `.section-title{margin:24px 0 12px}`.
  static const double sectionTitleMarginBottom = 12;

  /// css:109 `.section-title:first-child{margin-top:8px}`.
  static const double sectionTitleFirstMarginTop = 8;

  /// css:108 `.section-title{gap:8px}`.
  static const double sectionTitleGap = 8;

  /// css:106 `.divider{height:1px}`.
  static const double divider = 1;

  /// css:218 `.avatar-group .avatar{margin-left:-8px}`.
  static const double avatarGroupOverlap = 8;

  /// css:218 `.avatar-group .avatar{border:2px solid var(--bg-surface)}`.
  static const double avatarGroupBorder = 2;

  /// css:398 `.emblem{width:72px}`.
  static const double emblem = 72;

  /// css:399 `.emblem.is-sm{width:44px}`.
  static const double emblemSm = 44;

  /// css:400 `.emblem.is-xs{width:32px}`.
  static const double emblemXs = 32;

  /// css:398 `.emblem{border:1px solid var(--border-soft)}`.
  static const double emblemBorder = 1;

  /// css:302 `.kpi{padding:14px 16px}`.
  static const double kpiPaddingY = 14;

  /// css:302 `.kpi{padding:14px 16px}`.
  static const double kpiPaddingX = 16;

  /// css:302 `.kpi{gap:6px}`.
  static const double kpiGap = 6;

  /// css:318 `.date-badge{width:48px}`.
  static const double dateBadgeWidth = 48;

  /// css:318 `.date-badge{height:52px}`.
  static const double dateBadgeHeight = 52;

  /// css:319 `.date-badge span{margin-top:3px}`.
  static const double dateBadgeMonthTop = 3;

  /// css:209 `.cover.r16-9{aspect-ratio:16/9}` —
  /// `AspectRatio`.
  static const double coverRatio16x9 = 16 / 9;

  /// css:209 `.cover.r3-2{aspect-ratio:3/2}`.
  static const double coverRatio3x2 = 3 / 2;

  /// css:209 `.cover.r1-1{aspect-ratio:1}`.
  static const double coverRatio1x1 = 1;

  /// css:395 `.parallax{height:220px}`.
  static const double parallaxHeight = 220;

  /// css:396 `.parallax .cover{transform:translateY(calc(var(--py,0) * .4px)) scale(calc(1 + var(--pz,0)))}` —
  /// `translateY(py × .4px)`.
  static const double parallaxFactor = 0.4;

  /// css:397 `.parallax-bar{padding:calc(var(--safe-top) - 4px) 8px 0}`.
  static const double parallaxBarPaddingX = 8;

  /// css:397 `.parallax-bar{padding:calc(var(--safe-top) - 4px) 8px 0}` —
  /// **ek** — `calc(safe − 4px)` → `viewPadding.top − 4`; `.viewer` üst satırı aynı (sheets.js:160).
  static const double parallaxBarTopOffset = 4;

  /// css:407 `.img-grid{gap:4px}`.
  static const double imageGridGap = 4;

  /// css:407 `.img-grid{border-radius:14px}`.
  static const double imageGridRadius = 14;

  /// css:405 `.notif-icon{width:40px}`.
  static const double notifIcon = 40;

  /// css:308 `.timeline-item{min-height:56px}`.
  static const double timelineItemMinHeight = 56;

  /// css:308 `.timeline-item{gap:12px}`.
  static const double timelineGap = 12;

  /// css:309 `.timeline-rail{width:24px}`.
  static const double timelineRailWidth = 24;

  /// css:310 `.timeline-dot{width:12px}`.
  static const double timelineDot = 12;

  /// css:310 `.timeline-dot{border:2px solid var(--bg-surface)}`.
  static const double timelineDotBorder = 2;

  /// css:310 `.timeline-dot{box-shadow:0 0 0 2px var(--border-default)}`.
  static const double timelineDotRing = 2;

  /// css:310 `.timeline-dot{margin-top:4px}`.
  static const double timelineDotTop = 4;

  /// css:312 `.timeline-line{width:2px}`.
  static const double timelineLineWidth = 2;

  /// css:312 `.timeline-line{margin:4px 0}`.
  static const double timelineLineMarginY = 4;

  /// css:328 `.poll-opt{padding:10px 12px}`.
  static const double pollOptionPaddingY = 10;

  /// css:328 `.poll-opt{padding:10px 12px}`.
  static const double pollOptionPaddingX = 12;

  /// css:328 `.poll-opt{gap:4px}`.
  static const double pollOptionGap = 4;

  /// css:328 `.poll-opt{border:1px solid var(--border-default)}`.
  static const double pollOptionBorder = 1;

  /// css:324 `.ticket-cut{border-top:2px dashed var(--border-default)}`.
  static const double ticketCutDash = 2;

  /// css:325 `.ticket-cut::before{width:24px}`.
  static const double ticketNotch = 24;

  /// css:325 `.ticket-cut::before{top:-13px}`.
  static const double ticketNotchTop = 13;

  /// css:325 `.ticket-cut::before{left:-28px}`.
  static const double ticketNotchOffset = 28;

  /// css:324 `.ticket-cut{margin:0 16px}`.
  static const double ticketCutMarginX = 16;

  /// css:326 `.qr{width:220px}`.
  static const double qr = 220;

  /// css:326 `.qr{padding:12px}`.
  static const double qrPadding = 12;

  /// css:327 `.qr.is-blur svg{filter:blur(3px)}`.
  static const double qrBlurSigma = 3;

  /// css:327 `.qr.is-void::after{height:4px}`.
  static const double qrVoidLineHeight = 4;

  /// css:327 `.qr.is-void::after{transform:rotate(-30deg)}`.
  static const double qrVoidAngleDeg = -30;

  /// css:327 `.qr.is-void::after{left:10%}`.
  static const double qrVoidLeft = 0.10;

  /// css:327 `.qr.is-void::after{width:80%}`.
  static const double qrVoidWidth = 0.80;

  /// css:402 `.scan-box{width:240px}`.
  static const double scanBox = 240;

  /// css:403 `.scan-box>i{width:36px}`.
  static const double scanCorner = 36;

  /// css:403 `.scan-box>i{border:3px solid #fff}`.
  static const double scanCornerStroke = 3;

  /// css:335 `.scanline{height:2px}`.
  static const double scanLineHeight = 2;

  /// css:335 `.scanline{left:10%}`.
  static const double scanLineInsetX = 0.10;

  /// css:335 `.scanline{box-shadow:0 0 12px var(--brand-primary)}`.
  static const double scanLineGlow = 12;

  /// css:422 `@keyframes scan{0%{top:8%}}`.
  static const double scanLineTopMin = 0.08;

  /// css:422 `@keyframes scan{50%{top:90%}}`.
  static const double scanLineTopMax = 0.90;

  /// css:401 `.scan-view{background:radial-gradient(ellipse at 50% 40%,#2a2f3a,#0b0d12 75%)}` —
  /// **ek** — merkez `50% 40%` → `Alignment(0, -0.2)`.
  static const double scanGradientStop = 0.75;

  /// css:410 `.map-ph{height:120px}`.
  static const double mapPlaceholderHeight = 120;

  /// css:410 `.map-ph{background:repeating-linear-gradient(45deg,var(--bg-surface-muted) 0 10px,var(--border-soft) 10px 20px)}`.
  static const double mapPlaceholderStripe = 10;

  /// css:410 `.map-ph{border:1px solid var(--border-soft)}`.
  static const double mapPlaceholderBorder = 1;

  /// css:342 `.mini-chart{height:120px}`.
  static const double miniChartHeight = 120;

  /// css:341 `.tooltip{padding:4px 8px}`.
  static const double tooltipPaddingY = 4;

  /// css:341 `.tooltip{padding:4px 8px}`.
  static const double tooltipPaddingX = 8;

  /// css:341 `.tooltip{transform:translate(-50%,-110%)}`.
  static const double tooltipOffsetYRatio = -1.10;

  /// css:259 `.prog{height:6px}`.
  static const double progressHeight = 6;

  /// css:261 `.prog.is-thin{height:4px}`.
  static const double progressHeightThin = 4;

  /// css:259 `.prog{min-width:40px}`.
  static const double progressMinWidth = 40;

  /// css:263 `.sk{border-radius:8px}` —
  /// = `GuRadius.skeleton`.
  static const double skeletonRadius = 8;

  /// css:300 `.empty{padding:32px 24px}`.
  static const double emptyPaddingY = 32;

  /// css:300 `.empty{padding:32px 24px}`.
  static const double emptyPaddingX = 24;

  /// css:300 `.empty{gap:12px}`.
  static const double emptyGap = 12;

  /// css:105 `.hscroll{padding:3px 16px}`.
  static const double hscrollPaddingY = 3;

  /// css:105 `.hscroll{gap:8px}`.
  static const double hscrollGap = 8;

  /// css:110 `.grid2{gap:12px}` —
  /// `.grid3` aynı.
  static const double gridGap = 12;

  /// css:123 `.screen-scroll{padding-bottom:calc(var(--safe-bottom) + 8px)}` —
  /// `viewPadding.bottom + 8`.
  static const double screenScrollBottomExtra = 8;

  /// css:394 `.dots>i{width:8px}`.
  static const double pageDot = 8;

  /// css:394 `.dots>i.is-active{width:24px}`.
  static const double pageDotActiveWidth = 24;

  /// css:394 `.dots{gap:6px}`.
  static const double pageDotGap = 6;

  /// css:391 `.splash{gap:16px}`.
  static const double splashGap = 16;

  /// css:393 `.onb-track>section{padding:0 32px}`.
  static const double onboardingPaddingX = 32;

  /// css:393 `.onb-track>section{gap:16px}`.
  static const double onboardingGap = 16;

  /// css:313 `.cal-grid{gap:2px}`.
  static const double calendarGap = 2;

  /// css:314 `.cal-day{min-height:44px}` —
  /// `aspect-ratio:1`.
  static const double calendarDayMinHeight = 44;

  /// css:314 `.cal-day{gap:2px}`.
  static const double calendarDayGap = 2;

  /// css:315 `.cal-day.is-today{box-shadow:inset 0 0 0 2px var(--brand-primary)}`.
  static const double calendarTodayRing = 2;

  /// css:316 `.cal-day .dots i{width:4px}`.
  static const double calendarDot = 4;

  /// css:316 `.cal-day .dots{gap:2px}`.
  static const double calendarDotGap = 2;

  /// css:316 `.cal-day .dots{height:4px}`.
  static const double calendarDotsHeight = 4;

  /// css:317 `.cal-head{padding:4px 0}`.
  static const double calendarHeadPaddingY = 4;

  // ── §8.6 Overlay'ler (`ds_overlays.webp`, `reference-shots/sheets|dialogs|toasts`) ──

  /// css:268 `.sheet{max-height:90%}` —
  /// K-07: `× (yükseklik − üst inset)`.
  static const double sheetMaxHeightRatio = 0.90;

  /// css:270 `.sheet.is-menu{max-height:80%}`.
  static const double sheetMenuMaxHeightRatio = 0.80;

  /// css:278 `.sheet-full{height:90%}`.
  static const double sheetFullHeightRatio = 0.90;

  /// css:271 `.sheet-handle{width:36px}`.
  static const double sheetHandleWidth = 36;

  /// css:271 `.sheet-handle{height:4px}`.
  static const double sheetHandleHeight = 4;

  /// css:271 `.sheet-handle{margin:8px auto 0}`.
  static const double sheetHandleTop = 8;

  /// css:272 `.sheet-head{min-height:56px}`.
  static const double sheetHeadMinHeight = 56;

  /// css:272 `.sheet-head{padding:6px 8px 6px 20px}`.
  static const double sheetHeadPaddingY = 6;

  /// css:272 `.sheet-head{padding:6px 8px 6px 20px}`.
  static const double sheetHeadPaddingLeft = 20;

  /// css:272 `.sheet-head{padding:6px 8px 6px 20px}`.
  static const double sheetHeadPaddingRight = 8;

  /// css:272 `.sheet-head{gap:8px}`.
  static const double sheetHeadGap = 8;

  /// css:274 `.sheet-body{padding:0 16px 16px}`.
  static const double sheetBodyPaddingX = 16;

  /// css:274 `.sheet-body{padding:0 16px 16px}`.
  static const double sheetBodyPaddingBottom = 16;

  /// css:275 `.sheet-body.is-flush{padding:0 0 8px}`.
  static const double sheetBodyFlushPaddingBottom = 8;

  /// css:276 `.sheet-foot{padding:12px 16px calc(12px + var(--safe-bottom))}` —
  /// alt dolguya `viewPadding.bottom` eklenir.
  static const double sheetFootPaddingY = 12;

  /// css:276 `.sheet-foot{padding:12px 16px calc(12px + var(--safe-bottom))}`.
  static const double sheetFootPaddingX = 16;

  /// css:276 `.sheet-foot{gap:12px}`.
  static const double sheetFootGap = 12;

  /// css:276 `.sheet-foot{border-top:1px solid var(--border-soft)}`.
  static const double sheetFootBorder = 1;

  /// css:269 `.gu-root[data-theme="dark"] .sheet{border-top:1px solid var(--border-default)}`.
  static const double sheetBorderDark = 1;

  /// css:279 `.popmenu{top:calc(var(--safe-top) + 48px)}` —
  /// `viewPadding.top + 48`.
  static const double popMenuTop = 48;

  /// css:279 `.popmenu{right:12px}`.
  static const double popMenuRight = 12;

  /// css:279 `.popmenu{min-width:200px}`.
  static const double popMenuMinWidth = 200;

  /// css:279 `.popmenu{padding:6px}`.
  static const double popMenuPadding = 6;

  /// css:279 `.popmenu{border:1px solid var(--border-soft)}`.
  static const double popMenuBorder = 1;

  /// css:280 `.popmenu .tile{min-height:48px}`.
  static const double popMenuTileMinHeight = 48;

  /// css:280 `.popmenu .tile{padding:6px 12px}`.
  static const double popMenuTilePaddingY = 6;

  /// css:280 `.popmenu .tile{padding:6px 12px}`.
  static const double popMenuTilePaddingX = 12;

  /// css:282 `.dialog{width:min(320px,calc(100% - 48px))}` —
  /// `width:min(320px, 100% − 48px)`.
  static const double dialogMaxWidth = 320;

  /// css:282 `.dialog{width:min(320px,calc(100% - 48px))}` —
  /// `calc(100% − 48px)` → yan başına 24.
  static const double dialogMarginX = 24;

  /// css:282 `.dialog{padding:24px 20px 16px}`.
  static const double dialogPaddingTop = 24;

  /// css:282 `.dialog{padding:24px 20px 16px}`.
  static const double dialogPaddingX = 20;

  /// css:282 `.dialog{padding:24px 20px 16px}`.
  static const double dialogPaddingBottom = 16;

  /// css:282 `.dialog{gap:12px}`.
  static const double dialogGap = 12;

  /// css:282 `.dialog{max-height:85%}`.
  static const double dialogMaxHeightRatio = 0.85;

  /// css:284 `.dialog-actions{gap:6px}`.
  static const double dialogActionsGap = 6;

  /// css:284 `.dialog-actions{margin-top:8px}`.
  static const double dialogActionsTop = 8;

  /// css:405 `.notif-icon{width:40px}` —
  /// dialog ikonu `notif-icon` (ui.js:186).
  static const double dialogIconBox = 40;

  /// css:288 `.toast-wrap{left:12px}`.
  static const double toastMarginX = 12;

  /// css:288 `.toast-wrap{bottom:calc(var(--safe-bottom) + 12px)}` —
  /// `viewPadding.bottom + 12`; alt sekme varken `bottomNavHeight + viewPadding.bottom + 12` (css:289).
  static const double toastBottomExtra = 12;

  /// css:290 `.toast{padding:12px 8px 12px 14px}`.
  static const double toastPaddingTop = 12;

  /// css:290 `.toast{padding:12px 8px 12px 14px}`.
  static const double toastPaddingRight = 8;

  /// css:290 `.toast{padding:12px 8px 12px 14px}`.
  static const double toastPaddingBottom = 12;

  /// css:290 `.toast{padding:12px 8px 12px 14px}`.
  static const double toastPaddingLeft = 14;

  /// css:290 `.toast{gap:10px}`.
  static const double toastGap = 10;

  /// css:290 `.toast{border-left:4px solid var(--toast-color,var(--state-info))}`.
  static const double toastAccent = 4;

  /// css:293 `.toast .toast-action{min-height:36px}`.
  static const double toastActionHeight = 36;

  /// css:293 `.toast .toast-action{padding:0 10px}`.
  static const double toastActionPaddingX = 10;

  /// css:248 `.banner{padding:10px 16px}`.
  static const double bannerPaddingY = 10;

  /// css:248 `.banner{padding:10px 16px}`.
  static const double bannerPaddingX = 16;

  /// css:248 `.banner{gap:10px}`.
  static const double bannerGap = 10;

  /// css:249 `.banner.is-card{margin:0 16px}`.
  static const double bannerCardMarginX = 16;

  // ===========================================================================
  // JS-derived — `design/prototype/app/*.js` satır içi ölçüler; `dosya:N` = satır.
  // ===========================================================================

  // ── §8.1 Uygulama çubuğu, alt sekme, yapışkan CTA (`ds_nav.webp`) ──

  /// shell.js:12 `name=${icons[tb]} size=${24}`.
  static const double bottomNavIcon = 24;

  // ── §8.2 Düğmeler (`ds_buttons.webp`) ──

  /// ui.js:14 `size=${size === 'sm' ? 18 : 20}`.
  static const double buttonIcon = 20;

  /// ui.js:14 `size=${size === 'sm' ? 18 : 20}`.
  static const double buttonIconSm = 18;

  /// ui.js:14 `name=${iconRight} size=${18}`.
  static const double buttonIconTrailing = 18;

  /// shell.js:21 `width:32px;height:32px` —
  /// toast kapat düğmesi.
  static const double iconButtonXs = 32;

  /// ui.js:17 `size = 24`.
  static const double iconButtonIcon = 24;

  /// ui.js:128 `name=${icon} size=${20}`.
  static const double quickIcon = 20;

  // ── §8.3 Girdiler (`ds_inputs.webp`, `ds_selection.webp`) ──

  /// ui.js:29 `rows=${rows || 4}` —
  /// `int` — `GuInput(int rows = GuSizes.textareaRows)`.
  static const int textareaRows = 4;

  /// ui.js:28 `<span class="in-icon"><${Icon} name=${icon} size=${20} />`.
  static const double inputIcon = 20;

  /// ui.js:30 `name="lock" size=${18}`.
  static const double inputLockIcon = 18;

  /// ui.js:33 `name="triangle-alert" size=${14}`.
  static const double fieldHelpIcon = 14;

  /// ui.js:23 `Math.floor(maxLength * 0.8)`.
  static const double counterThresholdRatio = 0.8;

  /// ui.js:39 `name="chevron-down" size=${20}`.
  static const double pickerChevron = 20;

  /// ui.js:46 `name="check" size=${16} stroke=${3}` —
  /// kalınlık 1.75 (K-24).
  static const double checkboxIcon = 16;

  /// ui.js:59 `name=${o.icon} size=${16}`.
  static const double segmentIcon = 16;

  /// ui.js:62 `name=${tb.icon} size=${16}`.
  static const double tabIcon = 16;

  /// sheets.js:138 `<div style="height:60px" />` —
  /// **ek** — (160 − 40) / 2.
  static const double wheelSpacer = 60;

  /// sheets.js:140 `border-top:1px solid var(--border-default);border-bottom:1px solid var(--border-default)` —
  /// **ek**.
  static const double wheelSelectionBorder = 1;

  // ── §8.4 Çip, rozet, nokta (`ds_badges.webp`, `ds_selection.webp`) ──

  /// ui.js:55 `name=${icon} size=${16}`.
  static const double chipIcon = 16;

  /// ui.js:56 `name="x" size=${14}`.
  static const double chipRemoveIcon = 14;

  /// ui.js:56 `margin-right:-4px` —
  /// **ek** — kaldır ikonu sağ dolguyu daraltır.
  static const double chipRemoveMarginRight = -4;

  /// ui.js:66 `size=${12} stroke=${2.2}` —
  /// kalınlık 1.75 (K-24).
  static const double badgeIcon = 12;

  // ── §8.5 Kart, satır, avatar, görsel bileşenler (`ds_cards.webp`, `ds_special.webp`, `ds_feedback.webp`) ──

  /// ui.js:75 `"chevron-right" size=${20}`.
  static const double tileChevron = 20;

  /// art.js:43 `size = 40` —
  /// varsayılan.
  static const double avatar = 40;

  /// prototip `Avatar size=` dağılımı (bundle/pages hariç 26 çağrı) —
  /// `double` parametre; test kümeyi JS çağrılarından doğrular.
  static const List<double> avatarSizes = [30, 32, 36, 40, 44, 48, 56, 96, 120];

  /// art.js:48 `size = 28` —
  /// `GuAvatarGroup.size` varsayılanı.
  static const double avatarGroupSize = 28;

  /// art.js:48 `max = 4` —
  /// `int` — `GuAvatarGroup(int max = GuSizes.avatarGroupMax)`.
  static const int avatarGroupMax = 4;

  /// art.js:50 `padding: '0 6px'`.
  static const double avatarMorePaddingX = 6;

  /// art.js:50 `Math.max(10, Math.round(size * 0.38))`.
  static const double avatarMoreMinFont = 10;

  /// art.js:50 `Math.max(10, Math.round(size * 0.38))`.
  static const double avatarMoreFontRatio = 0.38;

  /// cards.js:38 ClubCard 24, screens-clubs.js:92 CLB-03 28, screens-events.js:69 EVT-02 32 (K-47) —
  /// **ek**.
  static const List<double> avatarGroupSizes = [24, 28, 32];

  /// art.js:45 `Math.round(size * 0.4)`.
  static const double avatarInitialsRatio = 0.4;

  /// screens-profile.js:11/:28 `is-xs` kamera rozeti 14 (CD-91), cards.js:31
  /// `is-xs` 16, sheets.js:88 `is-sm` 20, cards.js:36 `is-sm` 22 — **ek** —
  /// ikon boyutunu çağıran verir (T-01: 14 eklendi, CD-120).
  static const List<double> emblemIconSizes = [14, 16, 20, 22];

  /// ekran `Logo size=` kullanımları: FED-03 20, AUT-01 72, SET-04 80, SYS-01 96 (CD-90; shell.js:52 SideMenu 32 maketi hariç).
  static const List<double> logoSizes = [20, 72, 80, 96];

  /// ui.js:127 `name=${icon} size=${16}`.
  static const double kpiIcon = 16;

  /// art.js:33 `const k = h / 24 * 0.8` —
  /// **ek** — CD-26 ikon katmanı.
  static const double coverIconScale = 0.8;

  /// art.js:33 `const ix = w - 24 * k * 0.85` —
  /// **ek**.
  static const double coverIconOffsetXRatio = 0.85;

  /// art.js:33 `const iy = h - 24 * k * 0.9` —
  /// **ek**.
  static const double coverIconOffsetYRatio = 0.9;

  /// art.js:34 `stroke-width="1.1"` —
  /// **ek** — `flutter_svg` ile 1.75 kalır (K-24).
  static const double coverIconStroke = 1.1;

  /// sheets.js:116 `style="width:72px;height:72px"` —
  /// **ek** — SHT-24 sonuç ikonu.
  static const double notifIconLg = 72;

  /// sheets.js:116 `name=${icon} size=${36}` —
  /// **ek**.
  static const double notifIconLgIcon = 36;

  /// ui.js:134 `const w = 320, h = 110, pad = 10`.
  static const double miniChartViewW = 320;

  /// ui.js:134 `const w = 320, h = 110, pad = 10`.
  static const double miniChartViewH = 110;

  /// ui.js:134 `const w = 320, h = 110, pad = 10`.
  static const double miniChartPad = 10;

  /// ui.js:137 `r=${sel === i ? 6 : 4}`.
  static const double miniChartPoint = 4;

  /// ui.js:137 `r=${sel === i ? 6 : 4}`.
  static const double miniChartPointSelected = 6;

  /// ui.js:137 `stroke-width="2"`.
  static const double miniChartPointStroke = 2;

  /// ui.js:137 `stroke-width="2.5"` —
  /// dolum opaklığı `GuOpacity.miniChartFill`.
  static const double miniChartLine = 2.5;

  /// ui.js:93 `size = 96, stroke = 10`.
  static const double donut = 96;

  /// ui.js:93 `size = 96, stroke = 10`.
  static const double donutStroke = 10;

  /// ui.js:93 `font-size=${size / 4.5}`.
  static const double donutValueDivisor = 4.5;

  /// ui.js:151 `function SuccessCheck({ size = 96 })`.
  static const double successCheck = 96;

  /// `SuccessCheck size=` kullanımları 72×1, 110×1.
  static const List<double> successCheckSizes = [72, 110];

  /// ui.js:151 `r="40" fill="none" stroke="var(--state-success)" stroke-width="4"`.
  static const double successCircleStroke = 4;

  /// ui.js:151 `stroke-width="5"`.
  static const double successCheckStroke = 5;

  /// ui.js:151 `cx="48" cy="48" r="40"` —
  /// viewBox 96.
  static const double successCircleR = 40;

  /// ui.js:94 `h = 14`.
  static const double skeletonLineHeight = 14;

  /// ui.js:97 `w="60%" h=${16}`.
  static const double skeletonTitleHeight = 16;

  /// ui.js:98 `w="80%" h=${12}`.
  static const double skeletonSubHeight = 12;

  /// ui.js:97 `h=${140}`.
  static const double skeletonCardCover = 140;

  /// ui.js:98 `w=${40} h=${40} circle`.
  static const double skeletonAvatar = 40;

  /// ui.js:98 satır (55%, 80%) + ui.js:97 kart (60%, 90%, 40%).
  static const List<double> skeletonWidthRatios = [
    0.55,
    0.80,
    0.60,
    0.90,
    0.40,
  ];

  /// ui.js:101 `padding: '20px 16px'`.
  static const double emptyCompactPaddingY = 20;

  /// ui.js:101 `padding: '20px 16px'`.
  static const double emptyCompactPaddingX = 16;

  /// ui.js:101 `max-width:280px`.
  static const double emptyDescMaxWidth = 280;

  /// ui.js:107 `padding: '24px 16px'`.
  static const double emptyInlinePaddingY = 24;

  /// art.js:88 `size = 140` —
  /// varsayılan.
  static const double illustration = 140;

  /// ui.js:101 `size=${compact ? 96 : 140}`.
  static const double illustrationCompact = 96;

  /// `Illustration size=` kullanımları + varsayılan 140 (K-48).
  static const List<double> illustrationSizes = [
    56,
    72,
    80,
    96,
    100,
    140,
    160,
    200,
  ];

  /// ui.js:123 `padding:20px 16px 8px`.
  static const double listEndPaddingTop = 20;

  /// ui.js:123 `padding:20px 16px 8px`.
  static const double listEndPaddingX = 16;

  /// ui.js:123 `padding:20px 16px 8px`.
  static const double listEndPaddingBottom = 8;

  /// screens-auth.js:33 `Logo} size=${96}` —
  /// **ek** — SYS-01.
  static const double splashLogo = 96;

  /// screens-auth.js:33 `position:absolute;bottom:40px` —
  /// **ek**.
  static const double splashVersionBottom = 40;

  /// ui.js:149 `minHeight: '36px'`.
  static const double calendarDayMinHeightCompact = 36;

  /// ui.js:149 `Math.min(3, dotsFor(k))` —
  /// `int`.
  static const int calendarDotsMax = 3;

  /// ui.js:143 `for (let i = 0; i < 42; i++)` —
  /// `int` — 42 hücre = 6 hafta × 7.
  static const int calendarWeeks = 6;

  // ── §8.6 Overlay'ler (`ds_overlays.webp`, `reference-shots/sheets|dialogs|toasts`) ──

  /// ui.js:173 `if (dy > 120) close()` —
  /// CD-24; görüntüleyici aynı eşik (sheets.js:158).
  static const double sheetDragCloseThreshold = 120;

  /// sheets.js:160 `1 - dy / 400` —
  /// **ek** — SHT-34 görüntüleyici.
  static const double viewerDragFadeDistance = 400;

  /// ui.js:186 `name=${icon} size=${20}`.
  static const double dialogIcon = 20;

  /// shell.js:21 `name=${icon} size=${18}`.
  static const double toastIcon = 18;

  /// shell.js:21 `width:32px;height:32px`.
  static const double toastCloseButton = 32;

  /// shell.js:21 `name="x" size=${16}`.
  static const double toastCloseIcon = 16;

  /// ui.js:88 `name=${icon || defIcon} size=${18}`.
  static const double bannerIcon = 18;

  /// ui.js:90 `name="x" size=${18}`.
  static const double bannerDismissIcon = 18;

  /// ui.js:160 `pull > 60` —
  /// CD-24.
  static const double refreshTriggerDistance = 60;

  /// ui.js:159 `Math.min(90, dy * 0.6)` —
  /// CD-24.
  static const double refreshMaxPull = 90;

  /// ui.js:162 `refreshing ? 48 : pull`.
  static const double refreshIndicatorHeight = 48;

  /// ui.js:159 `Math.min(90, dy * 0.6)`.
  static const double refreshPullFactor = 0.6;

  /// ui.js:162 `name="arrow-up" size=${20}`.
  static const double refreshIcon = 20;

  // ── §8.7 İkon boyutları (`GuIcon` varsayılanı 24; prototip `Icon size=` dağılımı) ──

  /// `Icon size=12` — rozet.
  static const double icon12 = 12;

  /// `Icon size=14` — yardım / kaldır / satır içi meta.
  static const double icon14 = 14;

  /// `Icon size=16` — çip / segment / sekme / KPI / onay.
  static const double icon16 = 16;

  /// `Icon size=18` — sm düğme, banner, toast, kilit.
  static const double icon18 = 18;

  /// `Icon size=20` — düğme, girdi, chevron, hızlı eylem, dialog.
  static const double icon20 = 20;

  /// `Icon size=22` — PostCard aksiyonları, amblem-sm.
  static const double icon22 = 22;

  /// `Icon size=24` — ikon düğme, alt sekme.
  static const double icon24 = 24;

  /// `Icon size=30`.
  static const double icon30 = 30;

  /// `Icon size=34`.
  static const double icon34 = 34;

  /// `Icon size=36` — SHT-24.
  static const double icon36 = 36;

  /// `Icon size=64`.
  static const double icon64 = 64;

  // ── §8.9 Ürün/ekran düzeyinde satır içi ölçüler (**ek**; F-L 10 + K-30/K-31/K-32/K-46/CD-91 10) ──

  /// cards.js:124 `style="width:auto;padding:0 10px;gap:6px;border-radius:12px"` —
  /// K-32 sayaçlı `GuIconButton`.
  static const double iconButtonCountPaddingX = 10;

  /// cards.js:124 `style="width:auto;padding:0 10px;gap:6px;border-radius:12px"`.
  static const double iconButtonCountGap = 6;

  /// cards.js:124 `name="heart" size=${22}` —
  /// `message-circle` cards.js:125, `bookmark` cards.js:128 aynı.
  static const double postActionIcon = 22;

  /// cards.js:32 `style="padding:10px 12px 12px"`.
  static const double clubCardBodyPaddingTop = 10;

  /// cards.js:32 `style="padding:10px 12px 12px"`.
  static const double clubCardBodyPaddingX = 12;

  /// cards.js:32 `style="padding:10px 12px 12px"`.
  static const double clubCardBodyPaddingBottom = 12;

  /// cards.js:31 `position:absolute;left:10px;bottom:10px`.
  static const double clubCardEmblemOffset = 10;

  /// sheets.js:48 `Avatar} user=${a} size=${32}`.
  static const double commentAvatar = 32;

  /// cards.js:175 `Avatar} user=${u} size=${44}`.
  static const double applicationRowAvatar = 44;

  /// cards.js:110 `Avatar} user=${author} size=${40}`.
  static const double postAvatar = 40;

  /// cards.js:176 `width: '44px', height: '44px'` —
  /// K-32, K-46.
  static const double iconButtonTonal = 44;

  /// cards.js:42 `style="width:132px;text-align:left"` —
  /// K-30, K-46.
  static const double myClubCardWidth = 132;

  /// cards.js:172 `padding:6px 8px 6px 16px;min-height:64px` —
  /// K-31, K-46.
  static const double applicationRowMinHeight = 64;

  /// screens-profile.js:11 `border:2px solid var(--bg-canvas)` —
  /// CD-91, K-46 — PRF-01 kamera rozeti.
  static const double avatarBadgeBorder = 2;

  /// screens-clubs.js:89 `margin-top:-36px` —
  /// K-46 — CLB-03.
  static const double parallaxEmblemOverlap = 36;

  /// cards.js:145 `Math.abs(d) > 8` —
  /// K-46 — NTF-01.
  static const double notificationSwipeDeadZone = 8;

  /// cards.js:146 `if (dx < -90)` —
  /// K-46 — `dx > 90` okundu.
  static const double notificationSwipeThreshold = 90;

  /// cards.js:145 `Math.max(-140, Math.min(140, d))` —
  /// K-46.
  static const double notificationSwipeMax = 140;

  /// sheets.js:161 `transform: zoom && k === i ? 'scale(1.8)' : 'none'` —
  /// K-46 — SHT-34 çift dokunma yakınlaştırması (süre `GuMotion.viewerZoom`).
  static const double viewerZoomScale = 1.8;

  /// screens-manage.js:57 `transform: … 'translateX(40px)'` —
  /// K-46 — MGT-02 onaylanan/reddedilen başvuru satırının çıkış kayması
  /// (süre `GuMotion.applicationLeave`).
  static const double applicationLeaveOffsetX = 40;

  // ===========================================================================
  // Platform-derived — CSS/JS karşılığı yok; karar kaynağı (CD-97).
  // ===========================================================================

  // ── §8.10 Platform türevi dokunma hedefleri (**ek**, CD-97) ──

  /// D-22, K-03 — iOS etkin dokunma alanı ≥ 44 pt.
  static const double tapTargetIos = 44;

  /// D-22, K-03 — Android etkin dokunma alanı ≥ 48 dp.
  static const double tapTargetAndroid = 48;
}
