import 'package:flutter/animation.dart';

/// Hareket süreleri, eğrileri ve animasyon ölçek/kayma değerleri.
/// Değerler: `docs/token-map.md §7` + `§7.1`.
///
/// Kaynak: `registry.json#tokens.MOTION` (core:48), CSS css:40–44, CSS
/// `@keyframes`/`animation:`/`transition:` satırları (css:153–426) ve
/// prototip JS. Azaltılmış hareket: `context.gu.duration(d)`.
/// Yazılmayanlar: `refreshSettle` (= `base`), SHT-24 oto-kapanma
/// (`AppDurations.qrSuccessAutoClose`, uygulama katmanı — CD-58).
abstract final class GuMotion {
  // ── registry (reg.MOTION, css:40–44; CD-20) ─────────────────────────

  /// registry · `motion.fast` 120 ms (`.btn` css:139, `.chip` 176, `.pressable` 340).
  static const Duration fast = Duration(milliseconds: 120);

  /// registry · `motion.base` 200 ms (ekran `pushIn/popIn/fadeIn` css:121, `.dialog` 282).
  static const Duration base = Duration(milliseconds: 200);

  /// registry · `motion.slow` 320 ms (`.sheet` css:268, `.toast` 290, `.prog>i` 260).
  static const Duration slow = Duration(milliseconds: 320);

  /// registry · `easeStandard` `cubic-bezier(.2,0,0,1)` = CSS
  /// `var(--ease-standard)`; yalnızca bu eğriyi açıkça yazan kurallar
  /// (ekran geçişi css:121, `.switch>i` topuzu 234, `.prog>i` 260,
  /// `.popmenu`/`.dialog` 279/282, `.poll-fill` 329, draw 332–333, shake 334,
  /// `.notif-front` 339, highlight 208, splashOut 425). Eğrisi yazılmamış
  /// geçişler [easeCss] kullanır.
  static const Cubic easeStandard = Cubic(0.2, 0, 0, 1);

  /// registry · `easeEmphasized` `cubic-bezier(.3,0,0,1)` (`.sheet` css:268,
  /// `.toast` 290, `.heart` 331, `.splash .logo` 392).
  static const Cubic easeEmphasized = Cubic(0.3, 0, 0, 1);

  // ── CSS-derived (CD-20; keyframe/animation satırları) ───────────────

  /// CSS-derived · CSS anahtar kelimesi `ease` = `cubic-bezier(.25,.1,.25,1)`:
  /// zamanlama fonksiyonu yazılmamış `transition`/`animation` bildirimlerinin
  /// eğrisi (css:134, 139, 154, 163, 176, 206, 221, 226, 231, 237, 267, 340,
  /// 394, 409, 427; JS ui.js:162 ×2, screens-manage.js:57). Örn. switch rayı
  /// rengi (`.switch` css:231) `easeCss`, topuzu (`.switch>i` css:234)
  /// [easeStandard].
  static const Cubic easeCss = Cubic(0.25, 0.1, 0.25, 1);

  /// CSS-derived · `.spinner{animation:spin .8s linear infinite}` css:153.
  static const Duration spin = Duration(milliseconds: 800);

  /// CSS-derived · `spin` eğrisi `linear` css:153.
  static const Curve spinCurve = Curves.linear;

  /// CSS-derived · `.sk{animation:shimmer 1.2s linear infinite}` css:263.
  static const Duration shimmer = Duration(milliseconds: 1200);

  /// CSS-derived · `shimmer` eğrisi `linear` css:263.
  static const Curve shimmerCurve = Curves.linear;

  /// CSS-derived · `.circle-draw{animation:draw .5s var(--ease-standard)}` css:333.
  static const Duration circleDraw = Duration(milliseconds: 500);

  /// CSS-derived · `.check-draw{animation:draw var(--motion-slow) …}` css:332.
  static const Duration checkDraw = slow;

  /// CSS-derived · `.check-draw` gecikmesi `.2s` css:332.
  static const Duration checkDrawDelay = Duration(milliseconds: 200);

  /// CSS-derived · `.shake{animation:shake .4s var(--ease-standard)}` css:334.
  static const Duration shake = Duration(milliseconds: 400);

  /// CSS-derived · `@keyframes shake` `translateX` 0/−8/8/−5/5/0 (dp) css:421.
  static const List<double> shakeOffsets = [0, -8, 8, -5, 5, 0];

  /// CSS-derived · `.scanline{animation:scan 2.2s ease-in-out infinite}` css:335.
  static const Duration scan = Duration(milliseconds: 2200);

  /// CSS-derived · `scan` eğrisi `ease-in-out` css:335.
  static const Curve scanCurve = Curves.easeInOut;

  /// CSS-derived · `.splash .logo{animation:splash 1.2s var(--ease-emphasized)}` css:392.
  static const Duration splash = Duration(milliseconds: 1200);

  /// CSS-derived · `@keyframes splash` %0 `scale(.7)` (opaklık 0) css:423.
  static const double splashStartScale = 0.7;

  /// CSS-derived · `@keyframes splash` %60 `scale(1.05)` (opaklık 1) css:423.
  static const double splashPeakScale = 1.05;

  /// CSS-derived · `@keyframes splash` tepe karesinin yeri (%60) css:423.
  static const double splashPeakAt = 0.6;

  /// CSS-derived · `.splash-overlay{animation:splashOut .3s 1.3s …}` css:425.
  static const Duration splashOut = Duration(milliseconds: 300);

  /// CSS-derived · `splashOut` gecikmesi `1.3s` css:425.
  static const Duration splashOutDelay = Duration(milliseconds: 1300);

  /// CSS-derived · `.card.is-highlight{animation:highlight 1.5s …}` css:208.
  static const Duration highlight = Duration(milliseconds: 1500);

  /// CSS-derived · `.poll-fill{transition:width .6s …}` css:329 (+ Donut ui:93).
  static const Duration fill = Duration(milliseconds: 600);

  /// CSS-derived · basılı ölçek `scale(.98)` (`.btn:active` css:140, `.pressable` 340).
  static const double pressScale = 0.98;

  /// CSS-derived · kart basılı ölçek `scale(.99)` (`.card.is-tappable` css:206).
  static const double cardPressScale = 0.99;

  /// CSS-derived · `@keyframes pop` %40 `scale(1.35)` css:419.
  static const double heartPopScale = 1.35;

  /// CSS-derived · `@keyframes dialogIn` başlangıç `scale(.96)` css:415.
  static const double dialogEnterScale = 0.96;

  /// CSS-derived · `@keyframes toastIn` başlangıç `translateY(24px)` css:416.
  static const double toastEnterOffsetY = 24;

  /// CSS-derived · `@keyframes pushIn` `translateX(16px)` (`popIn` −16) css:412–413.
  static const double pushEnterOffsetX = 16;

  /// CSS-derived · `.sheet{animation:sheetIn var(--motion-slow) …}` css:268
  /// (`translateY(100%) → 0` css:414; eğri `easeEmphasized`).
  static const Duration sheetEnter = slow;

  // ── JS-derived (CD-20) ──────────────────────────────────────────────

  /// JS-derived · standart toast süresi 4000 ms (core.js:567; CD-24).
  static const Duration toastDefault = Duration(milliseconds: 4000);

  /// JS-derived · aksiyonlu / Geri al'lı toast süresi 6000 ms (core.js:567; CD-24).
  static const Duration toastUndo = Duration(milliseconds: 6000);

  /// JS-derived · geri sayım adımı 1 s (core.js:658 `useCountdown`; CD-97).
  static const Duration countdownTick = Duration(seconds: 1);

  /// JS-derived · uzun basma menüsü 550 ms (cards.js:144; K-46).
  static const Duration longPress = Duration(milliseconds: 550);

  /// JS-derived · beğeni kalbi animasyon sıfırlama 400 ms (cards.js:100; K-46).
  static const Duration heartPopReset = Duration(milliseconds: 400);

  /// JS-derived · MGT-02 başvuru satırı çıkışı 250 ms (screens-manage.js:48, :57; K-46);
  /// eğri yazılmamış → [easeCss], kayma `GuSizes.applicationLeaveOffsetX`.
  static const Duration applicationLeave = Duration(milliseconds: 250);

  /// JS-derived · SHT-34 çift dokunma eşiği 300 ms (sheets.js:159; K-46).
  static const Duration viewerDoubleTap = Duration(milliseconds: 300);

  /// JS-derived · SHT-34 yakınlaştırma geçişi `transform .3s
  /// var(--ease-emphasized)` (sheets.js:161; K-46); eğri [easeEmphasized],
  /// ölçek `GuSizes.viewerZoomScale`.
  static const Duration viewerZoom = Duration(milliseconds: 300);
}
