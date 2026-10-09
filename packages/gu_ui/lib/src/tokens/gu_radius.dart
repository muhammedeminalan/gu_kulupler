import 'package:flutter/painting.dart';

/// Köşe yarıçapları (dp). Değerler: `docs/token-map.md §5`.
///
/// Kaynak: `registry.json#tokens.RADIUS = {sm:12, md:16, lg:20, xl:28,
/// full:999}` (core:46), CSS `--r-*` css:31–35; CSS türevleri
/// `border-radius:Npx` satırlarından.
abstract final class GuRadius {
  // ── registry (reg.RADIUS, css:31–35; CD-20) ─────────────────────────

  /// registry · `r.sm` 12 (`.btn` css:139, `.input` 163, `.toast` 290).
  static const double sm = 12;

  /// registry · `r.md` 16 (`.option-card` css:245, `.popmenu` 279, `.fab` 158).
  static const double md = 16;

  /// registry · `r.lg` 20 (`.card` css:203, `.dialog` 282, `.ticket` 323).
  static const double lg = 20;

  /// registry · `r.xl` 28 (`.sheet` üst köşeler css:268).
  static const double xl = 28;

  /// registry · `r.full` 999 (`.iconbtn` css:154, `.badge` 188; hap/daire).
  static const double full = 999;

  // ── CSS-derived (CD-20) ─────────────────────────────────────────────

  /// CSS-derived · 10 (`.chip` css:176, `.seg>button` 221, `.popmenu .tile` 280).
  static const double chip = 10;

  /// CSS-derived · 9 (`.emblem.is-xs` css:400).
  static const double emblemXs = 9;

  /// CSS-derived · 8 (`.sk` css:263, `.toast-action` 293).
  static const double skeleton = 8;

  /// CSS-derived · 6 (`.check` css:238, `:focus-visible` 82, `.tooltip` 341).
  static const double checkbox = 6;

  /// CSS-derived · 4 (`.scan-box>i` css:403, `.dots>i` 394).
  static const double scanCorner = 4;

  /// CSS-derived · 3 (`.prog`/`.prog>i` css:259–260, nav göstergesi 136).
  static const double progress = 3;

  /// CSS-derived · 2 (`.sheet-handle` css:271, `.stepbar>i` 320, sekme göstergesi 228).
  static const double handle = 2;

  /// CSS-derived · 14 (`.img-grid` css:407).
  static const double imageGrid = 14;

  /// CSS-derived · 13 (`.switch` css:231 = yükseklik 26 / 2).
  static const double switchTrack = 13;

  // ── BorderRadius · registry ─────────────────────────────────────────

  /// registry · `BorderRadius` `sm` (12) dört köşe.
  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));

  /// registry · `BorderRadius` `md` (16) dört köşe.
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));

  /// registry · `BorderRadius` `lg` (20) dört köşe.
  static const BorderRadius borderLg = BorderRadius.all(Radius.circular(lg));

  /// registry · `BorderRadius` `xl` (28) dört köşe.
  static const BorderRadius borderXl = BorderRadius.all(Radius.circular(xl));

  /// registry · `BorderRadius` `full` (999) dört köşe (hap/daire).
  static const BorderRadius borderFull = BorderRadius.all(
    Radius.circular(full),
  );

  /// registry · yalnızca üst köşeler `xl` (`.sheet{border-radius:var(--r-xl)
  /// var(--r-xl) 0 0}` css:268).
  static const BorderRadius topXl = BorderRadius.vertical(
    top: Radius.circular(xl),
  );

  // ── BorderRadius · CSS-derived ──────────────────────────────────────

  /// CSS-derived · alt sekme göstergesi `border-radius:0 0 3px 3px` css:136.
  static const BorderRadius navIndicator = BorderRadius.vertical(
    bottom: Radius.circular(progress),
  );

  /// CSS-derived · sekme göstergesi `border-radius:2px 2px 0 0` css:228.
  static const BorderRadius tabIndicator = BorderRadius.vertical(
    top: Radius.circular(handle),
  );

  /// CSS-derived · `BorderRadius` `chip` (10) dört köşe.
  static const BorderRadius borderChip = BorderRadius.all(
    Radius.circular(chip),
  );

  /// CSS-derived · `BorderRadius` `emblemXs` (9) dört köşe.
  static const BorderRadius borderEmblemXs = BorderRadius.all(
    Radius.circular(emblemXs),
  );

  /// CSS-derived · `BorderRadius` `skeleton` (8) dört köşe.
  static const BorderRadius borderSkeleton = BorderRadius.all(
    Radius.circular(skeleton),
  );

  /// CSS-derived · `BorderRadius` `checkbox` (6) dört köşe.
  static const BorderRadius borderCheckbox = BorderRadius.all(
    Radius.circular(checkbox),
  );

  /// CSS-derived · `BorderRadius` `scanCorner` (4) dört köşe.
  static const BorderRadius borderScanCorner = BorderRadius.all(
    Radius.circular(scanCorner),
  );

  /// CSS-derived · `BorderRadius` `progress` (3) dört köşe.
  static const BorderRadius borderProgress = BorderRadius.all(
    Radius.circular(progress),
  );

  /// CSS-derived · `BorderRadius` `handle` (2) dört köşe.
  static const BorderRadius borderHandle = BorderRadius.all(
    Radius.circular(handle),
  );

  /// CSS-derived · `BorderRadius` `imageGrid` (14) dört köşe.
  static const BorderRadius borderImageGrid = BorderRadius.all(
    Radius.circular(imageGrid),
  );

  /// CSS-derived · `BorderRadius` `switchTrack` (13) dört köşe.
  static const BorderRadius borderSwitchTrack = BorderRadius.all(
    Radius.circular(switchTrack),
  );
}
