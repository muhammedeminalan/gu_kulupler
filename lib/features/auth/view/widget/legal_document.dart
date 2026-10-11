import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/navigation/legal_tab.dart';
import 'package:gu_ui/gu_ui.dart';

/// Bir yasal metnin yerelleştirilmiş içeriği — prototip `legal.<tip>.*`
/// anahtarları (`screens-auth.js:153–158`): sekme adı, başlık ve 7 bölüm.
///
/// Metinler ARB'dedir (`legalKvkk*`, `legalGizlilik*`, `legalKosullar*`;
/// K-06); bu sınıf yalnızca [LegalTab] → anahtar eşlemesidir.
@immutable
final class LegalDocument {
  const LegalDocument._({
    required this.shortTitle,
    required this.title,
    required this.sections,
  });

  /// [tab] metninin [l10n] dilindeki içeriği.
  factory LegalDocument.of(AppLocalizations l10n, LegalTab tab) =>
      switch (tab) {
        LegalTab.kvkk => LegalDocument._(
          shortTitle: l10n.legalKvkkShort,
          title: l10n.legalKvkkTitle,
          sections: [
            (heading: l10n.legalKvkkH1, body: l10n.legalKvkkB1),
            (heading: l10n.legalKvkkH2, body: l10n.legalKvkkB2),
            (heading: l10n.legalKvkkH3, body: l10n.legalKvkkB3),
            (heading: l10n.legalKvkkH4, body: l10n.legalKvkkB4),
            (heading: l10n.legalKvkkH5, body: l10n.legalKvkkB5),
            (heading: l10n.legalKvkkH6, body: l10n.legalKvkkB6),
            (heading: l10n.legalKvkkH7, body: l10n.legalKvkkB7),
          ],
        ),
        LegalTab.gizlilik => LegalDocument._(
          shortTitle: l10n.legalGizlilikShort,
          title: l10n.legalGizlilikTitle,
          sections: [
            (
              heading: l10n.legalGizlilikH1,
              body: l10n.legalGizlilikB1(AppConstants.appName),
            ),
            (heading: l10n.legalGizlilikH2, body: l10n.legalGizlilikB2),
            (heading: l10n.legalGizlilikH3, body: l10n.legalGizlilikB3),
            (heading: l10n.legalGizlilikH4, body: l10n.legalGizlilikB4),
            (heading: l10n.legalGizlilikH5, body: l10n.legalGizlilikB5),
            (heading: l10n.legalGizlilikH6, body: l10n.legalGizlilikB6),
            (heading: l10n.legalGizlilikH7, body: l10n.legalGizlilikB7),
          ],
        ),
        LegalTab.kosullar => LegalDocument._(
          shortTitle: l10n.legalKosullarShort,
          title: l10n.legalKosullarTitle,
          sections: [
            (heading: l10n.legalKosullarH1, body: l10n.legalKosullarB1),
            (heading: l10n.legalKosullarH2, body: l10n.legalKosullarB2),
            (heading: l10n.legalKosullarH3, body: l10n.legalKosullarB3),
            (heading: l10n.legalKosullarH4, body: l10n.legalKosullarB4),
            (heading: l10n.legalKosullarH5, body: l10n.legalKosullarB5),
            (heading: l10n.legalKosullarH6, body: l10n.legalKosullarB6),
            (heading: l10n.legalKosullarH7, body: l10n.legalKosullarB7),
          ],
        ),
      };

  /// Her metindeki bölüm sayısı (`items = [1 … 7]`, `screens-auth.js:154`).
  static const int sectionCount = 7;

  /// [tab] sekmesinin adı (`legal.<tip>.short`).
  static String shortTitleOf(AppLocalizations l10n, LegalTab tab) =>
      switch (tab) {
        LegalTab.kvkk => l10n.legalKvkkShort,
        LegalTab.gizlilik => l10n.legalGizlilikShort,
        LegalTab.kosullar => l10n.legalKosullarShort,
      };

  /// Sekme adı (`legal.<tip>.short`).
  final String shortTitle;

  /// Metnin başlığı (`legal.<tip>.title`).
  final String title;

  /// Bölümler, sırasıyla (`legal.<tip>.h<n>` / `.b<n>`); numara = sıra + 1.
  final List<({String heading, String body})> sections;
}

/// AUT-06 metin bölümü — prototip `section.col.gap4`
/// (`screens-auth.js:158`): numaralı `titleS` başlık + `bodyM` ikincil
/// gövde.
class LegalSection extends StatelessWidget {
  /// [heading] numaralı başlıktır (`legalSectionHeading`).
  const LegalSection({required this.heading, required this.body, super.key});

  /// Numaralı bölüm başlığı ("1. Veri sorumlusu").
  final String heading;

  /// Bölüm metni.
  final String body;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s4,
      children: [
        Semantics(
          header: true,
          child: Text(heading, style: gu.text.titleS),
        ),
        Text(
          body,
          style: gu.text.bodyM.copyWith(color: gu.colors.textSecondary),
        ),
      ],
    );
  }
}
