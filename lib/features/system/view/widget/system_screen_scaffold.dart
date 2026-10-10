import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

/// SYS-02 / SYS-03 / SYS-04'ün ortak iskeleti — prototip
/// `AppBar` (başlıksız, geri) + `.screen-scroll.col` `justify-content:center`
/// (`screens-auth.js:36–40`, css:123).
///
/// Gövde ([child]: `.empty` bloğu) çubuğun altında kalan alanda dikeyde
/// ortalanır; alan yetmezse (küçük ekran + büyük yazı) kayar. Alt boşluk
/// gerçek güvenli alan + 8'dir (K-07).
class SystemScreenScaffold extends StatelessWidget {
  /// [backActionKey]: çubuktaki geri düğmesinin aksiyon anahtarı
  /// (`GuKey.action('SYS-0n.back')`).
  const SystemScreenScaffold({
    required this.backActionKey,
    required this.child,
    super.key,
  });

  /// Geri düğmesinin anahtarı.
  final Key backActionKey;

  /// Ortalanan gövde.
  final Widget child;

  /// Ekrandan çıkış — prototip `nav.back() || nav.resetTo('CLB-01')`: yığında
  /// dönülecek sayfa varsa geri, yoksa ana sayfa (oturuma göre nereye
  /// varılacağına router karar verir).
  static void leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      goHome(context);
    }
  }

  /// "Ana sayfaya dön" — prototip `nav.resetTo('CLB-01')`.
  static void goHome(BuildContext context) => const ClubsRoute().go(context);

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        MediaQuery.viewPaddingOf(context).bottom +
        GuSizes.screenScrollBottomExtra;
    return Scaffold(
      backgroundColor: context.gu.colors.bgCanvas,
      appBar: GuAppBar(
        onBack: () => leave(context),
        backSemanticLabel: context.l10n.a11yBack,
        backActionKey: backActionKey,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: GuInsets.only(bottom: bottomPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - bottomPadding),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
