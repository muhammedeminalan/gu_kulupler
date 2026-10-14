import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// SET-05 gönderim sonrası "Mesajın alındı" kartı — prototip
/// `screens-profile.js:116` (`Card.card-body.col.gap12`, ortalı).
///
/// `SuccessCheck` 72 · başlık (`t-title-s`) · talep numaralı açıklama
/// (`t-body-s c-sec`, ortalı) · "Yeni talep" (`outline`,
/// `SET-05.newRequest`).
///
/// Design: SET-05
class SupportSentCard extends StatelessWidget {
  /// [ticketNo] (`#GU-XXXXXX`) numaralı talebin başarı kartı.
  const SupportSentCard({
    required this.ticketNo,
    required this.onNewRequest,
    super.key,
  });

  /// Gösterilen numara (`#` önekli).
  final String ticketNo;

  /// "Yeni talep": form sıfırlanır.
  final VoidCallback onNewRequest;

  /// "Yeni talep" düğmesinin anahtarı.
  static final Key newRequestKey = GuKey.action('SET-05.newRequest');

  /// `SuccessCheck size=72` (`screens-profile.js:116`).
  static final double _checkSize = GuSizes.successCheckSizes[0];

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    return GuCard(
      padding: GuCard.bodyPadding,
      child: Column(
        spacing: GuSpacing.s12,
        children: [
          GuSuccessCheck(size: _checkSize, semanticLabel: l10n.commonSuccess),
          Semantics(
            header: true,
            child: Text(
              l10n.supportSentTitle,
              style: gu.text.titleS,
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            l10n.supportSentDesc(ticketNo),
            style: gu.text.bodyS.copyWith(color: gu.colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          GuButton(
            key: newRequestKey,
            label: l10n.supportNewRequest,
            variant: GuButtonVariant.outline,
            onPressed: onNewRequest,
          ),
        ],
      ),
    );
  }
}
