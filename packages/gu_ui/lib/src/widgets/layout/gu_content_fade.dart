import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';

/// İçerik değişiminde kısa solma — kullanıcı kararı (2026-10-16; D-06 eki,
/// tasarımdan sapma: prototipte sekme / segment içerik değişimi
/// animasyonsuzdur).
///
/// [value] değişince [child] `GuMotion.tabSwitch` (200 ms, `easeStandard`)
/// boyunca saydamdan opağa solar; eski içerik aynı karede kalkar (yalnızca
/// giriş solması). İlk çizimde ve [value] aynı kaldıkça animasyon yoktur;
/// hareket azaltılmışsa (`MediaQuery.disableAnimations`) içerik anında
/// opaktır. Solma sırasında anlam ağacı ve dokunma hedefleri yerindedir
/// (`alwaysIncludeSemantics`).
///
/// Sayfa içi sekme / segment / süzgeç (CLB-03, PRF-03, MGT-02/04/08,
/// ADM-02/04/05, NTF-01, …) değişiminde içerik alanını sarar; kaydırma
/// görünümü içindeki dilim [GuSliverContentFade] ile sarılır. Sayfa geçişi
/// değildir (rota geçişi D-06, platform varsayılanı).
class GuContentFade extends StatefulWidget {
  /// [value] değişince [child] solarak girer.
  const GuContentFade({required this.value, required this.child, super.key});

  /// Değişimi izlenen değer (seçili sekme, süzgeç, …).
  final Object? value;

  /// Solan içerik.
  final Widget child;

  @override
  State<GuContentFade> createState() => _GuContentFadeState();
}

class _GuContentFadeState extends State<GuContentFade>
    with SingleTickerProviderStateMixin, _ContentFadeController<GuContentFade> {
  @override
  void didUpdateWidget(GuContentFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) restart();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: opacity,
    alwaysIncludeSemantics: true,
    child: widget.child,
  );
}

/// [GuContentFade]'in dilim (sliver) karşılığı: kaydırma görünümünde sekmeye
/// göre değişen dilimi ([sliver]) [value] değişince soldurur.
class GuSliverContentFade extends StatefulWidget {
  /// [value] değişince [sliver] solarak girer.
  const GuSliverContentFade({
    required this.value,
    required this.sliver,
    super.key,
  });

  /// Değişimi izlenen değer (seçili sekme, süzgeç, …).
  final Object? value;

  /// Solan dilim.
  final Widget sliver;

  @override
  State<GuSliverContentFade> createState() => _GuSliverContentFadeState();
}

class _GuSliverContentFadeState extends State<GuSliverContentFade>
    with
        SingleTickerProviderStateMixin,
        _ContentFadeController<GuSliverContentFade> {
  @override
  void didUpdateWidget(GuSliverContentFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) restart();
  }

  @override
  Widget build(BuildContext context) => SliverFadeTransition(
    opacity: opacity,
    alwaysIncludeSemantics: true,
    sliver: widget.sliver,
  );
}

/// Hâlini koruyan sekme kabı + seçim değişiminde kısa solma.
///
/// `IndexedStack` gibi tüm çocukları ağaçta tutar (kaydırma konumu, arama
/// metni, alt sekme hâli korunur); yalnızca [index] çocuğu sahnededir —
/// diğerleri `Offstage` + `TickerMode(enabled: false)` (go_router
/// `StatefulShellRoute.indexedStack` kabıyla aynı). [index] değişince yeni
/// çocuk [GuContentFade] ile solarak girer (`GuMotion.tabSwitch`; hareket
/// azaltılmışsa anında).
///
/// [lazy]: henüz seçilmemiş çocuk kurulmaz (`SizedBox.shrink`); ilk
/// seçildiği anda kurulur ve sonra ağaçta kalır (açılışta okuma yapan
/// bölümler gereksiz yere açılmaz — ADM-01 … ADM-05).
///
/// Kullanım: alt sekme dalları (`AppShellRouteData`
/// `$navigatorContainerBuilder`) ve admin bölmeli sayfası (ADM-01 kökü).
class GuFadeIndexedStack extends StatefulWidget {
  /// [children] içinden [index] gösterilir.
  const GuFadeIndexedStack({
    required this.index,
    required this.children,
    this.lazy = false,
    this.sizing = StackFit.loose,
    super.key,
  });

  /// Sahnedeki çocuğun sırası.
  final int index;

  /// Sekme içerikleri (sıra sabit; hâl sıraya bağlıdır).
  final List<Widget> children;

  /// Seçilmemiş çocuğu ilk seçilene kadar kurma.
  final bool lazy;

  /// `IndexedStack.sizing`.
  final StackFit sizing;

  @override
  State<GuFadeIndexedStack> createState() => _GuFadeIndexedStackState();
}

class _GuFadeIndexedStackState extends State<GuFadeIndexedStack> {
  /// Kurulmuş (en az bir kez seçilmiş) çocuklar ([GuFadeIndexedStack.lazy]).
  final Set<int> _built = <int>{};

  @override
  Widget build(BuildContext context) {
    final index = widget.index;
    _built.add(index);
    return GuContentFade(
      value: index,
      child: IndexedStack(
        index: index,
        sizing: widget.sizing,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            if (widget.lazy && !_built.contains(i))
              const SizedBox.shrink()
            else
              Offstage(
                offstage: i != index,
                child: TickerMode(
                  enabled: i == index,
                  child: widget.children[i],
                ),
              ),
        ],
      ),
    );
  }
}

/// [GuContentFade] / [GuSliverContentFade] ortak denetleyicisi: değer 1'de
/// (opak) başlar; [restart] saydamdan yeniden soldurur.
mixin _ContentFadeController<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: GuMotion.tabSwitch,
    value: 1,
  );

  late final Animation<double> opacity = CurvedAnimation(
    parent: _controller,
    curve: GuMotion.easeStandard,
  );

  /// İçeriği saydamdan soldurur; hareket azaltılmışsa anında opak.
  void restart() {
    final duration = context.gu.duration(GuMotion.tabSwitch);
    if (duration == Duration.zero) {
      _controller.value = 1;
      return;
    }
    _controller.duration = duration;
    unawaited(_controller.forward(from: 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
