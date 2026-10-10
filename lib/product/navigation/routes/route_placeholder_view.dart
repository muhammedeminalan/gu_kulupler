import 'package:flutter/material.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';

/// Sahibi task gerçek ekranı yazana kadar bir rotanın gösterdiği geçici
/// gövde (PLAN §13.2, §13.11): yalnızca başlık çubuğu.
///
/// Tasarım kimliği **taşımaz** — ekranın izi sahibi task'ta, gerçek view ile
/// gelir. Onu kullanan her rota satırı sahipli bir not taşır; son yer tutucu
/// kalktığında bu dosya silinir (T-43 yer tutucu taraması sıfır bulur).
class RoutePlaceholderView extends StatelessWidget {
  /// [title] başlığıyla yer tutucu.
  const RoutePlaceholderView({required this.title, super.key});

  /// Başlık metnini yerelleştirmeden seçer (rota sınıfı bağlam taşımaz).
  final String Function(AppLocalizations l10n) title;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.gu.colors.bgCanvas,
    appBar: GuAppBar(title: title(context.l10n)),
    body: const SizedBox.expand(),
  );
}
