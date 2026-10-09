import 'package:flutter/widgets.dart';

/// Boşluk ölçeği (dp). Değerler: `docs/token-map.md §4`.
///
/// Kaynak: `registry.json#tokens.SPACING = [4,8,12,16,20,24,32,40,48]`
/// (core:45) + CSS yardımcı sınıfları css:101–103. `s10` yazılmaz
/// (CD-99, K-42: `.gap10` CSS'te tanımsız, tarayıcıda etkisiz).
abstract final class GuSpacing {
  // ── registry (reg.SPACING, core:45; CD-20) ──────────────────────────

  /// registry · `SPACING[0]` = 4 (`.gap4`, `.mt4` css:101–103).
  static const double s4 = 4;

  /// registry · `SPACING[1]` = 8 (`.gap8`, `.py8`, `.row{gap:8px}` css:100–103).
  static const double s8 = 8;

  /// registry · `SPACING[2]` = 12 (`.gap12`, `.p12`, `.py12` css:101–103).
  static const double s12 = 12;

  /// registry · `SPACING[3]` = 16 (`.gap16`, `.p16`, `.px16` css:101–103).
  static const double s16 = 16;

  /// registry · `SPACING[4]` = 20 (`.gap20`, `.p20` css:101–102).
  static const double s20 = 20;

  /// registry · `SPACING[5]` = 24 (`.gap24`, `.pb24`, `.mt24` css:101–103).
  static const double s24 = 24;

  /// registry · `SPACING[6]` = 32 (`.empty{padding:32px 24px}` css:300).
  static const double s32 = 32;

  /// registry · `SPACING[7]` = 40 (splash sürüm `bottom:40px` screens-auth.js:33).
  static const double s40 = 40;

  /// registry · `SPACING[8]` = 48 (`.btn/.input/.iconbtn` 48 — ölçüler `GuSizes`).
  static const double s48 = 48;

  // ── CSS-derived (CD-20; css:101 `.gapN{gap:Npx}`) ──────────────────

  /// CSS-derived · `.gap2{gap:2px}` css:101 (6 ekran / 43 kullanım).
  static const double s2 = 2;

  /// CSS-derived · `.gap6{gap:6px}` css:101 (23 ekran / 313 kullanım).
  static const double s6 = 6;
}

/// `GuSpacing` değerleriyle sabit `SizedBox` aralayıcılar (token-map §4).
///
/// `h*` yatay (`width`), `v*` dikey (`height`) boşluktur.
abstract final class GuGap {
  // ── registry (reg.SPACING; CD-20) ───────────────────────────────────

  /// registry · yatay 4 (`.gap4` css:101).
  static const SizedBox h4 = SizedBox(width: GuSpacing.s4);

  /// registry · dikey 4 (`.mt4` css:103).
  static const SizedBox v4 = SizedBox(height: GuSpacing.s4);

  /// registry · yatay 8 (`.gap8`, `.row{gap:8px}` css:100–101).
  static const SizedBox h8 = SizedBox(width: GuSpacing.s8);

  /// registry · dikey 8 (`.mt8 .mb8` css:103).
  static const SizedBox v8 = SizedBox(height: GuSpacing.s8);

  /// registry · yatay 12 (`.gap12` css:101).
  static const SizedBox h12 = SizedBox(width: GuSpacing.s12);

  /// registry · dikey 12 (`.mt12 .mb12` css:103).
  static const SizedBox v12 = SizedBox(height: GuSpacing.s12);

  /// registry · yatay 16 (`.gap16` css:101).
  static const SizedBox h16 = SizedBox(width: GuSpacing.s16);

  /// registry · dikey 16 (`.mt16 .mb16` css:103).
  static const SizedBox v16 = SizedBox(height: GuSpacing.s16);

  /// registry · yatay 20 (`.gap20` css:101).
  static const SizedBox h20 = SizedBox(width: GuSpacing.s20);

  /// registry · dikey 20 (`.gap20` css:101).
  static const SizedBox v20 = SizedBox(height: GuSpacing.s20);

  /// registry · yatay 24 (`.gap24` css:101).
  static const SizedBox h24 = SizedBox(width: GuSpacing.s24);

  /// registry · dikey 24 (`.mt24 .mb24` css:103).
  static const SizedBox v24 = SizedBox(height: GuSpacing.s24);

  /// registry · yatay 32 (`SPACING[6]`).
  static const SizedBox h32 = SizedBox(width: GuSpacing.s32);

  /// registry · dikey 32 (`SPACING[6]`).
  static const SizedBox v32 = SizedBox(height: GuSpacing.s32);

  /// registry · yatay 40 (`SPACING[7]`).
  static const SizedBox h40 = SizedBox(width: GuSpacing.s40);

  /// registry · dikey 40 (`SPACING[7]`).
  static const SizedBox v40 = SizedBox(height: GuSpacing.s40);

  /// registry · yatay 48 (`SPACING[8]`).
  static const SizedBox h48 = SizedBox(width: GuSpacing.s48);

  /// registry · dikey 48 (`SPACING[8]`).
  static const SizedBox v48 = SizedBox(height: GuSpacing.s48);
}

/// `GuSpacing` değerleriyle sabit `EdgeInsets` dolguları (token-map §4).
///
/// `all*` dört kenar, `h*` yatay, `v*` dikey, `hNvM` simetrik bileşik.
/// `sym` / `only` yardımcıları yalnızca `GuSpacing` / `GuSizes` sabitleriyle
/// çağrılır (HC04).
abstract final class GuInsets {
  // ── registry (reg.SPACING; CD-20) ───────────────────────────────────

  /// registry · 4 dört kenar.
  static const EdgeInsets all4 = EdgeInsets.all(GuSpacing.s4);

  /// registry · 8 dört kenar.
  static const EdgeInsets all8 = EdgeInsets.all(GuSpacing.s8);

  /// registry · yatay 8.
  static const EdgeInsets h8 = EdgeInsets.symmetric(horizontal: GuSpacing.s8);

  /// registry · dikey 8 (`.py8` css:102).
  static const EdgeInsets v8 = EdgeInsets.symmetric(vertical: GuSpacing.s8);

  /// registry · 12 dört kenar (`.p12` css:102).
  static const EdgeInsets all12 = EdgeInsets.all(GuSpacing.s12);

  /// registry · yatay 12.
  static const EdgeInsets h12 = EdgeInsets.symmetric(
    horizontal: GuSpacing.s12,
  );

  /// registry · dikey 12 (`.py12` css:102).
  static const EdgeInsets v12 = EdgeInsets.symmetric(vertical: GuSpacing.s12);

  /// registry · 16 dört kenar (`.p16` css:102).
  static const EdgeInsets all16 = EdgeInsets.all(GuSpacing.s16);

  /// registry · yatay 16 = sayfa yatay dolgusu (`.px16` css:102).
  static const EdgeInsets h16 = EdgeInsets.symmetric(
    horizontal: GuSpacing.s16,
  );

  /// registry · dikey 16 (`.py16` css:102).
  static const EdgeInsets v16 = EdgeInsets.symmetric(vertical: GuSpacing.s16);

  /// registry · yatay 16 + dikey 8.
  static const EdgeInsets h16v8 = EdgeInsets.symmetric(
    horizontal: GuSpacing.s16,
    vertical: GuSpacing.s8,
  );

  /// registry · yatay 16 + dikey 12.
  static const EdgeInsets h16v12 = EdgeInsets.symmetric(
    horizontal: GuSpacing.s16,
    vertical: GuSpacing.s12,
  );

  /// registry · 20 dört kenar (`.p20` css:102).
  static const EdgeInsets all20 = EdgeInsets.all(GuSpacing.s20);

  /// registry · yatay 20 + dikey 12.
  static const EdgeInsets h20v12 = EdgeInsets.symmetric(
    horizontal: GuSpacing.s20,
    vertical: GuSpacing.s12,
  );

  /// registry · 24 dört kenar.
  static const EdgeInsets all24 = EdgeInsets.all(GuSpacing.s24);

  /// registry · yatay 24.
  static const EdgeInsets h24 = EdgeInsets.symmetric(
    horizontal: GuSpacing.s24,
  );

  /// registry · 32 dört kenar.
  static const EdgeInsets all32 = EdgeInsets.all(GuSpacing.s32);

  // ── yardımcılar ─────────────────────────────────────────────────────

  /// Simetrik dolgu: `h` yatay, `v` dikey (yalnızca token sabitleriyle).
  static EdgeInsets sym({double h = 0, double v = 0}) =>
      EdgeInsets.symmetric(horizontal: h, vertical: v);

  /// Kenar bazlı dolgu (yalnızca token sabitleriyle).
  static EdgeInsets only({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) => EdgeInsets.only(left: left, top: top, right: right, bottom: bottom);
}
