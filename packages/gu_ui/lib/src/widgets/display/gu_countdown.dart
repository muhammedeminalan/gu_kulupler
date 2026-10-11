import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';

/// Kalan süreyi çizen kurucu: [remaining] hiçbir zaman eksi olmaz.
typedef GuCountdownBuilder =
    Widget Function(BuildContext context, Duration remaining);

/// Hedef ana kadar geri sayan destek widget'ı — prototip `useCountdown`
/// (`core.js:658`; CD-96). Kendi görünümü yoktur: kalan süreyi [builder]'a
/// verir, metin (ARB) ve stil çağırandadır.
///
/// Kullanım: DLG-02 giriş kilidi (30 sn), AUT-01 kilit, AUT-03 / AUT-04
/// "Tekrar gönder" (60 sn). Hedef an State'te tutulur (`lockedUntil`,
/// `resendAvailableAt`); widget her adımda [until] − [now] farkını yeniden
/// hesaplar, kendi sayacını **tutmaz** — uygulama arka planda beklese de
/// dönüşte doğru değeri gösterir.
///
/// * Saat çağırandan gelir ([now] = `appClock.nowUtc`); widget
///   `DateTime.now()` çağırmaz (testte sahte saat).
/// * Her [tick]'te (varsayılan `GuMotion.countdownTick`, 1 sn) yeniden
///   kurulur. Azaltılmış hareket ayarı etkilemez (animasyon değil, bilgi).
/// * Süre dolunca zamanlayıcı durur ve [onDone] **bir kez** çağrılır; widget
///   süresi dolmuş bir hedefle kurulduysa ilk kareden sonra çağrılır.
/// * [until] değişirse sayım yeni hedefle baştan başlar ([onDone] yeniden
///   kurulur).
/// * Ekranda saniye göstermek için [secondsLeft] (yukarı yuvarlar: 29,2 sn
///   kala "30"; prototip `Math.ceil`).
class GuCountdown extends StatefulWidget {
  const GuCountdown({
    required this.until,
    required this.now,
    required this.builder,
    this.onDone,
    this.tick = GuMotion.countdownTick,
    super.key,
  });

  /// Sayımın biteceği an.
  final DateTime until;

  /// Şu anı veren saat (`appClock.nowUtc`).
  final DateTime Function() now;

  /// Kalan süreyle içeriği kurar.
  final GuCountdownBuilder builder;

  /// Süre dolduğunda bir kez çağrılır.
  final VoidCallback? onDone;

  /// Yeniden hesaplama aralığı.
  final Duration tick;

  /// [remaining] süresinin ekranda gösterilecek saniyesi: yukarı yuvarlanır,
  /// eksi olmaz (`0` yalnızca süre dolduğunda).
  static int secondsLeft(Duration remaining) {
    if (remaining <= Duration.zero) return 0;
    final micros = remaining.inMicroseconds;
    return (micros + Duration.microsecondsPerSecond - 1) ~/
        Duration.microsecondsPerSecond;
  }

  @override
  State<GuCountdown> createState() => _GuCountdownState();
}

class _GuCountdownState extends State<GuCountdown> {
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(GuCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.until != widget.until || oldWidget.tick != widget.tick) {
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration get _remaining {
    final left = widget.until.difference(widget.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Sayımı (yeniden) başlatır. Hedef geçmişteyse zamanlayıcı kurulmaz;
  /// [GuCountdown.onDone] yapım sırasında değil, kareden sonra çağrılır.
  void _start() {
    _timer?.cancel();
    _timer = null;
    _done = false;
    if (_remaining > Duration.zero) {
      _timer = Timer.periodic(widget.tick, (_) => _onTick());
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _remaining <= Duration.zero) _finish();
    });
  }

  void _onTick() {
    if (!mounted) return;
    // Kalan süre her yapımda saatten okunur; burada yalnızca yeniden kurulur.
    setState(() {});
    if (_remaining <= Duration.zero) _finish();
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    if (_done) return;
    _done = true;
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining);
}
