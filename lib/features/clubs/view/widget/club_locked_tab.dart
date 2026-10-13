import 'package:flutter/widgets.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-03 kilitli sekme bloğu — prototip `lockBlock`
/// (`screens-clubs.js:84`): kulübün içini görmeyen kullanıcıya "Gönderiler"
/// ve "Üyeler" sekmesinde gösterilir.
///
/// Ham `.empty` gövdesi (dolgu 32 / 24, aralık 12, ortalı): kilit
/// illüstrasyonu 100 dp · açıklama (`bodyM`, `text.secondary`) · [cta]
/// (`ClubCta`, orta boy).
class ClubLockedTab extends StatelessWidget {
  /// [text] açıklamalı kilit bloğu.
  const ClubLockedTab({required this.text, this.cta, super.key});

  /// Açıklama ("Gönderileri görmek için kulübe üye ol." …).
  final String text;

  /// Katılım eylemi (`ClubCta`); askıdaki kulüpte rozet.
  final Widget? cta;

  /// `screens-clubs.js:84` `Illustration size=100` —
  /// `GuSizes.illustrationSizes` (56 · 72 · 80 · 96 · 100 · 140 · 160 · 200)
  /// içindeki CLB-03 değeri.
  static final double illustrationSize = GuSizes.illustrationSizes[4];

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return Padding(
      padding: GuInsets.sym(
        h: GuSizes.emptyPaddingX,
        v: GuSizes.emptyPaddingY,
      ),
      child: Column(
        spacing: GuSizes.emptyGap,
        children: [
          GuIllustration(GuIllustrations.locked, size: illustrationSize),
          Text(
            text,
            style: gu.text.bodyM.copyWith(color: gu.colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          ?cta,
        ],
      ),
    );
  }
}
