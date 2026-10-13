import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// "İlk kulübünü bul" kartı — hiçbir kulübe üye olmayan kullanıcıya CLB-01'in
/// başında, "Kulüplerim" şeridinin yerinde gösterilir (prototip
/// `screens-clubs.js:26`).
///
/// Soluk kart (`.card.is-muted` + `.card-body`): 72'lik illüstrasyon · başlık
/// (titleS) · açıklama (bodyS, `text.secondary`) · "Keşfet" (küçük, tonal).
/// Dış dolgu `px16 pb16`. Düğmenin anahtarı çağırandan
/// ([discoverKey] `CLB-01.discover`).
class FirstClubCard extends StatelessWidget {
  /// "Keşfet"e basınca [onDiscover] çağrılır (liste başına kaydırma).
  const FirstClubCard({required this.onDiscover, this.discoverKey, super.key});

  /// İllüstrasyon kenarı (`screens-clubs.js:26` `size=${72}`).
  /// `GuSizes.illustrationSizes` (56 · 72 · 80 · 96 · 100 · 140 · 160 · 200)
  /// kümesinin ikinci değeri.
  static final double illustrationSize = GuSizes.illustrationSizes[1];

  /// "Keşfet" — kulüp listesine kaydırır.
  final VoidCallback onDiscover;

  /// "Keşfet" düğmesinin anahtarı.
  final Key? discoverKey;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    return Padding(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        right: GuSpacing.s16,
        bottom: GuSpacing.s16,
      ),
      child: GuCard(
        muted: true,
        padding: GuCard.bodyPadding,
        child: Row(
          spacing: GuSpacing.s12,
          children: [
            GuIllustration(GuIllustrations.emptyClubs, size: illustrationSize),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: GuSpacing.s6,
                children: [
                  Text(l10n.clubsFirstTitle, style: gu.text.titleS),
                  Text(
                    l10n.clubsFirstDesc,
                    style: gu.text.bodyS.copyWith(
                      color: gu.colors.textSecondary,
                    ),
                  ),
                  GuButton(
                    key: discoverKey,
                    label: l10n.clubsFirstCta,
                    size: GuButtonSize.sm,
                    variant: GuButtonVariant.tonal,
                    onPressed: onDiscover,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
