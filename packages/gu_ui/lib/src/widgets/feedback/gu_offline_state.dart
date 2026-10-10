import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/widgets/display/gu_illustrations.dart';
import 'package:gu_ui/src/widgets/feedback/gu_empty_state.dart';
import 'package:gu_ui/src/widgets/primitives/gu_button.dart';

/// Tam ekran çevrimdışı durumu (SYS-03) — prototip `OfflineState`
/// (`ui.js:110–114`), CSS `.empty` + `.shake` (css:300, 334; keyframes
/// css:421). `GuEmptyState` gövdesini `offline` illüstrasyonuyla sarar
/// (CD-27).
///
/// * Tek görünüm: illüstrasyon 140, başlık, açıklama (genişlik sınırı yok),
///   `GuButton` primary + `refresh-cw`.
/// * [onRetry] `false` dönerse (hâlâ çevrimdışı) gövde 400 ms yatay sallanır
///   (`GuMotion.shake`, 0 / −8 / 8 / −5 / 5 / 0); TST-24'ü çağıran gösterir.
///   Azaltılmış harekette sallanmaz. [onRetry] beklenirken yeni dokunma yok
///   sayılır.
/// * Liste düzeyinde çevrimdışı bu widget değil, `GuBanner(kind: offline)` +
///   önbellektir (design-contract §6).
class GuOfflineState extends StatefulWidget {
  const GuOfflineState({
    required this.title,
    required this.description,
    required this.retryLabel,
    required this.onRetry,
    this.retryActionKey,
    super.key,
  });

  /// Başlık (`sys.offline.title`).
  final String title;

  /// Açıklama (`sys.offline.fullDesc`).
  final String description;

  /// Yeniden dene düğmesi metni (`common.retry`).
  final String retryLabel;

  /// Yeniden deneme; `true` → bağlantı var, `false` → hâlâ çevrimdışı
  /// (gövde sallanır).
  final Future<bool> Function() onRetry;

  /// Yeniden dene düğmesi anahtarı (`GuKey.action`, çağırandan — CD-111).
  final Key? retryActionKey;

  @override
  State<GuOfflineState> createState() => _GuOfflineStateState();
}

class _GuOfflineStateState extends State<GuOfflineState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: GuMotion.shake,
  );

  /// `@keyframes shake` (css:421): eşit aralıklı kareler, her aralık
  /// `easeStandard` ile (CSS zamanlama fonksiyonu kare aralığına uygulanır).
  late final Animation<double> _offsetX = _controller.drive(
    TweenSequence<double>([
      for (var i = 0; i < GuMotion.shakeOffsets.length - 1; i++)
        TweenSequenceItem(
          tween: Tween<double>(
            begin: GuMotion.shakeOffsets[i],
            end: GuMotion.shakeOffsets[i + 1],
          ).chain(CurveTween(curve: GuMotion.easeStandard)),
          weight: 1,
        ),
    ]),
  );

  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_busy) return;
    _busy = true;
    try {
      final online = await widget.onRetry();
      if (!online && mounted && !context.gu.reduceMotion) {
        unawaited(_controller.forward(from: 0));
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _offsetX,
    builder: (context, child) => Transform.translate(
      offset: Offset(_offsetX.value, 0),
      child: child,
    ),
    child: GuEmptyState.body(
      illustration: GuIllustrations.offline,
      title: widget.title,
      description: widget.description,
      descriptionMaxWidth: null,
      actions: GuButton(
        key: widget.retryActionKey,
        label: widget.retryLabel,
        icon: GuIcons.refreshCw,
        onPressed: () => unawaited(_retry()),
      ),
    ),
  );
}
