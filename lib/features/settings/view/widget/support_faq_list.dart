import 'package:flutter/widgets.dart';
import 'package:gu_ui/gu_ui.dart';

/// SSS kartının tek satırı: sıra numarası (anahtar `SET-05.faq.<n>`), soru
/// ve cevap metni (ARB `faqQ<n>` / `faqA<n>`).
typedef SupportFaqItem = ({int index, String question, String answer});

/// SET-05 "Sık sorulan sorular" kartı — prototip `screens-profile.js:114`
/// (`Card` + `button.tile.in-card` + `.divider`).
///
/// Satır: soru (`t-body-m c-heading`) + sonda `chevron-down` / `chevron-up`
/// (20, `text.muted`); açık satırın altında cevap (`t-body-s c-sec`, yatay
/// 16, alt 16). Satırlar arasında ayraç. Liste boşsa (arama eşleşmedi)
/// [emptyText] (`t-body-s c-muted`, dolgu 16). Hangi satırın açık olduğu ve
/// süzme çağırandadır.
///
/// Design: SET-05
class SupportFaqList extends StatelessWidget {
  /// [items] sorularını, [expanded] satırı açık olarak çizer.
  const SupportFaqList({
    required this.items,
    required this.expanded,
    required this.onToggle,
    required this.emptyText,
    super.key,
  });

  /// Gösterilen sorular (süzülmüş, sıra numarasıyla).
  final List<SupportFaqItem> items;

  /// Açık sorunun sıra numarası; `null` → hepsi kapalı.
  final int? expanded;

  /// Satıra dokunuldu (sıra numarasıyla).
  final ValueChanged<int> onToggle;

  /// Eşleşen soru yokken gösterilen metin (`supportNoFaq`).
  final String emptyText;

  /// [index] sorusunun satır anahtarı (`SET-05.faq.<n>`).
  static Key keyOf(int index) => GuKey.action('SET-05.faq.$index');

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    if (items.isEmpty) {
      return GuCard(
        child: Padding(
          padding: GuInsets.all16,
          child: Text(
            emptyText,
            style: gu.text.bodyS.copyWith(color: colors.textMuted),
          ),
        ),
      );
    }
    return GuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (position, item) in items.indexed) ...[
            if (position > 0) const GuDivider(),
            _row(context, item),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, SupportFaqItem item) {
    final gu = context.gu;
    final isOpen = expanded == item.index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: isOpen,
          child: GuTile(
            key: keyOf(item.index),
            title: item.question,
            padding: GuTilePadding.inCard,
            trailing: GuIcon(
              isOpen ? GuIcons.chevronUp : GuIcons.chevronDown,
              size: GuSizes.icon20,
              color: gu.colors.textMuted,
            ),
            onTap: () => onToggle(item.index),
          ),
        ),
        if (isOpen)
          Padding(
            padding: GuInsets.only(
              left: GuSpacing.s16,
              right: GuSpacing.s16,
              bottom: GuSpacing.s16,
            ),
            child: Text(
              item.answer,
              style: gu.text.bodyS.copyWith(color: gu.colors.textSecondary),
            ),
          ),
      ],
    );
  }
}
