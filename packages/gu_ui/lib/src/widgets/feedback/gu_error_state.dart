import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/display/gu_illustrations.dart';
import 'package:gu_ui/src/widgets/feedback/gu_empty_state.dart';
import 'package:gu_ui/src/widgets/primitives/gu_button.dart';

/// Hata durumu — prototip `ErrorState` (`ui.js:104–109`), CSS `.empty` +
/// `.row.gap8` + `.btn.is-loading` (css:300, 152). `GuEmptyState` gövdesini
/// `error` illüstrasyonuyla sarar (CD-27).
///
/// * Tam ekran (SYS-02): illüstrasyon 140, dolgu 32 / 24; [onHome] verilirse
///   yanında metin düğmesi ([homeLabel]).
/// * [inline] (`GuListState` içi): illüstrasyon 96, dolgu 24 / 16.
/// * Yeniden dene: `GuButton` primary + `refresh-cw`; [onRetry] Future'u
///   beklenirken düğme `loading` olur ve yeni dokunma yok sayılır (bayrak
///   widget içinde, CD-118; prototipteki 800 ms sahte gecikme yazılmaz).
/// * `role="alert"` → canlı bölge. Metinler çağırandan (ARB).
class GuErrorState extends StatefulWidget {
  const GuErrorState({
    required this.title,
    required this.description,
    required this.retryLabel,
    required this.onRetry,
    this.retryActionKey,
    this.homeLabel,
    this.onHome,
    this.homeActionKey,
    this.inline = false,
    super.key,
  }) : assert(
         onHome == null || homeLabel != null,
         'onHome verildiyse homeLabel de verilmeli.',
       );

  /// Başlık (`sys.error.title`).
  final String title;

  /// Açıklama (`sys.error.desc`).
  final String description;

  /// Yeniden dene düğmesi metni (`common.retry`).
  final String retryLabel;

  /// Yeniden deneme; tamamlanana dek düğme meşgul görünür.
  final Future<void> Function() onRetry;

  /// Yeniden dene düğmesi anahtarı (`GuKey.action`, çağırandan — CD-111).
  final Key? retryActionKey;

  /// Ana sayfa düğmesi metni (`sys.error.home`).
  final String? homeLabel;

  /// Ana sayfaya dönüş; `null` → düğme yok.
  final VoidCallback? onHome;

  /// Ana sayfa düğmesi anahtarı.
  final Key? homeActionKey;

  /// Liste içi küçük görünüm.
  final bool inline;

  @override
  State<GuErrorState> createState() => _GuErrorStateState();
}

class _GuErrorStateState extends State<GuErrorState> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeLabel = widget.homeLabel;
    final onHome = widget.onHome;
    return GuEmptyState.body(
      illustration: GuIllustrations.error,
      title: widget.title,
      description: widget.description,
      layout: widget.inline
          ? GuEmptyStateLayout.inline
          : GuEmptyStateLayout.regular,
      liveRegion: true,
      actions: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: GuSpacing.s8,
        runSpacing: GuSpacing.s8,
        children: [
          GuButton(
            key: widget.retryActionKey,
            label: widget.retryLabel,
            icon: GuIcons.refreshCw,
            loading: _busy,
            // `GuButton` meşgulken dokunmayı yok sayar.
            onPressed: () => unawaited(_retry()),
          ),
          if (homeLabel != null && onHome != null)
            GuButton(
              key: widget.homeActionKey,
              label: homeLabel,
              onPressed: onHome,
              variant: GuButtonVariant.text,
            ),
        ],
      ),
    );
  }
}
