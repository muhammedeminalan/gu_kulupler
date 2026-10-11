import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/features/auth/provider/register_view_model.dart';
import 'package:gu_kulupler/features/auth/view/legal_view.dart';
import 'package:gu_kulupler/features/auth/view/widget/legal_document.dart';
import 'package:gu_kulupler/product/navigation/legal_tab.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

/// AUT-06 ekranının etkileşim mantığı — prototip `Legal`
/// (`screens-auth.js:152–160`): seçili sekme, bölüme atlama, geri / onay.
///
/// Ekranın ViewModel'i yoktur (PLAN §12.4): veri okumaz, tek durumu seçili
/// sekmedir.
mixin LegalViewMixin on ConsumerState<LegalView> {
  /// Seçili sekme; ilk değer rota parametresidir (`/legal/:tip`).
  late LegalTab tab = widget.tip;

  /// Bölüm anahtarları (sıra = bölüm numarası − 1): atlama hedefleri.
  final List<GlobalKey> sectionKeys = List<GlobalKey>.generate(
    LegalDocument.sectionCount,
    (index) => GlobalKey(debugLabel: 'AUT-06 bölüm ${index + 1}'),
  );

  @override
  void didUpdateWidget(LegalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tip != widget.tip) tab = widget.tip;
  }

  /// `AUT-06.tab.<tip>` — sekme değişir; her sekmenin metni kendi kaydırma
  /// konumunu korur (`Scroll routeKey="legal-<tip>"`, `:158`).
  void onTabChanged(String id) {
    final next = LegalTab.values.byName(id);
    if (next == tab) return;
    setState(() => tab = next);
  }

  /// `AUT-06.jump.<n>` — [number] numaralı bölüm metnin görünen alanının
  /// başına yumuşak kaydırılır (`jump`, `:155`).
  void onJump(int number) {
    final target = sectionKeys[number - 1].currentContext;
    if (target == null) return;
    unawaited(
      Scrollable.ensureVisible(
        target,
        duration: context.gu.duration(GuMotion.base),
        curve: GuMotion.easeStandard,
      ),
    );
  }

  /// `AUT-06.back` — açan ekrana döner (`nav.back()`, `:156`).
  void onBack() => _leave();

  /// `AUT-06.accept` — "Okudum, anladım": açık kayıt formu varsa onay
  /// kutusunu işaretler ve açan ekrana `true` sonucuyla döner (`accept`,
  /// `:154`).
  void onAccept() {
    if (ref.exists(registerViewModelProvider)) {
      ref.read(registerViewModelProvider.notifier).acceptLegal();
    }
    _leave(accepted: true);
  }

  /// Ekrandan çıkış. Dönülecek sayfa yoksa (doğrudan bağlantı) ana sayfa;
  /// oturuma göre varılacak yere router karar verir.
  void _leave({bool? accepted}) {
    if (context.canPop()) {
      context.pop(accepted);
    } else {
      const ClubsRoute().go(context);
    }
  }
}
