import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// Günlük bildirimli duyuru hakkı çubuğu — "Bugünkü duyuru hakkı" + `{used}/
/// {limit}` sayacı + ilerleme çubuğu (Q-10; widget-catalog P23, CD-109).
///
/// * **Düz** (varsayılan; FED-03, `screens-clubs.js:208`): `.col gap6` —
///   `.t-caption` satırı (etiket solda, tabular sayaç sağda) + `GuProgress`.
/// * **Kart** ([card]; MGT-01, `screens-manage.js:27`): `Card card-body col
///   gap8` — etiket `labelL` başlık renginde, sayaç `caption`, çubuğun
///   altında kalan hak ("{n} duyuru hakkın kaldı") ya da "Bugünkü duyuru
///   hakkın doldu.".
///
/// Hak dolduğunda ([used] ≥ [limit]) çubuk `warning` çizilir. Etkileşimi
/// yoktur.
class AnnouncementQuotaBar extends StatelessWidget {
  /// [limit] haktan [used] tanesi kullanılmış.
  const AnnouncementQuotaBar({
    required this.used,
    required this.limit,
    this.card = false,
    super.key,
  }) : assert(limit > 0, 'limit pozitif olmalı.');

  /// Bugün gönderilen bildirimli duyuru sayısı.
  final int used;

  /// Günlük sınır (`Limits.announcementDailyLimit`).
  final int limit;

  /// Kart görünümü (MGT-01): kart çerçevesi + kalan hak metni.
  final bool card;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final label = l10n.composeDailyQuota;
    final limitReached = used >= limit;
    final caption = gu.text.caption;

    final counter = Text(
      '$used/$limit',
      style: caption.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final progress = GuProgress(
      value: used.clamp(0, limit).toDouble(),
      max: limit.toDouble(),
      kind: limitReached ? GuProgressKind.warning : GuProgressKind.brand,
      semanticLabel: label,
    );

    if (!card) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s6,
        children: [
          Row(
            spacing: GuSpacing.s8,
            children: [
              Expanded(child: Text(label, style: caption)),
              counter,
            ],
          ),
          progress,
        ],
      );
    }
    return GuCard(
      padding: GuInsets.all16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s8,
        children: [
          Row(
            spacing: GuSpacing.s8,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: gu.text.labelL.copyWith(color: gu.colors.textHeading),
                ),
              ),
              counter,
            ],
          ),
          progress,
          Text(
            limitReached
                ? l10n.composeLimitReached
                : l10n.mgtQuotaLeft(limit - used),
            style: caption,
          ),
        ],
      ),
    );
  }
}
