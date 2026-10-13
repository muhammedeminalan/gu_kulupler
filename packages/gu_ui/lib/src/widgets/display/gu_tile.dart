import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/utils/gu_tap_target.dart';

/// Satır dolgusu — tek mekanizma (K-35; ayrı `inCard` bayrağı yok).
enum GuTilePadding {
  /// `.tile{padding:8px 16px}` (css:211).
  normal(GuSizes.tilePaddingY),

  /// `.tile.in-card{padding:10px 16px}` (css:214).
  inCard(GuSizes.tileInCardPaddingY),

  /// `NotificationRow` satır içi `padding:12px 16px` (`cards.js:151`; K-46).
  notification(GuSpacing.s12);

  const GuTilePadding(this.vertical);

  /// Dikey dolgu (dp).
  final double vertical;

  /// Yatay `GuSizes.tilePaddingX` + dikey [vertical].
  EdgeInsets get insets => EdgeInsets.symmetric(
    horizontal: GuSizes.tilePaddingX,
    vertical: vertical,
  );
}

/// Tek satır primitifi — prototip `Tile` (`ui.js:74`) ve sheet `Row`
/// (`sheets.js:5`), CSS `.tile` / `.tile-text` / `.trailing` / `.in-card` /
/// `.is-plain` / `.is-danger` (css:211–214). `UserRow`, `MemberRow`,
/// `NotificationRow`, `ActivityRow` bunu sarar (CD-27, G1).
///
/// Yerleşim: [leading] · metin sütunu ([title] bodyM `text.heading`,
/// [subtitle] bodyS `text.muted`, [sub2] caption) · [trailing]
/// (`text.muted`) · [chevron] (`chevron-right` 20). En az yükseklik 56,
/// aralık 12, tam genişlik; metinler sarar.
///
/// Durumlar: [onTap] yoksa statik satır (`div.is-plain`); varsa düğme —
/// basılıyken zemin `bg.surfaceMuted` (css:212 `:hover` → basılı, K-53;
/// [plain] ise yok). [danger] başlığı `state.danger` yapar (css:213; ikon
/// rengini çağıran verir). [disabled] opaklık `GuOpacity.disabled`, dokunma
/// çağrılmaz. [alignStart] üstten hizalar (`NotificationRow`, K-35).
/// [titleSpan] verilirse başlık zengin metindir (CLB-02 arama sonucunda
/// eşleşen kısım kalın — `Highlight`, `screens-clubs.js:36`); taban stil
/// aynıdır, [title] erişilebilirlik etiketi olarak kalır.
/// [titleWidget] verilirse başlık satırı o widget'tır (ad + rozet —
/// `UserRow`, `ui.js:131`); [sub2Widget] verilirse üçüncü satır o widget'tır
/// (katılım oranı çubuğu — `MemberRow`, `cards.js:167`). İkisi de satırın
/// taban stilini (`DefaultTextStyle`) alır ve kendi semantiğini taşır.
/// `key` (`GuKey.action`) satırın kendisidir.
class GuTile extends StatefulWidget {
  const GuTile({
    required this.title,
    this.subtitle,
    this.sub2,
    this.leading,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.padding = GuTilePadding.normal,
    this.alignStart = false,
    this.plain = false,
    this.danger = false,
    this.disabled = false,
    this.titleStyle,
    this.titleSpan,
    this.titleWidget,
    this.sub2Widget,
    super.key,
  }) : assert(
         titleSpan == null || titleWidget == null,
         'titleSpan ve titleWidget birlikte verilemez',
       ),
       assert(
         sub2 == null || sub2Widget == null,
         'sub2 ve sub2Widget birlikte verilemez',
       );

  /// Başlık.
  final String title;

  /// Başlığın zengin metni; verilirse [title] yerine çizilir ([title]
  /// erişilebilirlik etiketidir).
  final InlineSpan? titleSpan;

  /// Başlık satırının yerine çizilen widget (ad + rozet). Taban başlık stili
  /// `DefaultTextStyle` olarak verilir; [title] çizilmez, widget kendi
  /// semantiğini taşır.
  final Widget? titleWidget;

  /// İkinci satır (bodyS, `text.muted`).
  final String? subtitle;

  /// Üçüncü satır (caption).
  final String? sub2;

  /// Üçüncü satırın yerine çizilen widget (`caption` `DefaultTextStyle` ile).
  final Widget? sub2Widget;

  /// Baştaki öğe (ikon 20/22, avatar, amblem, `GuIconBox`).
  final Widget? leading;

  /// Sondaki öğe; metin rengi `text.muted`.
  final Widget? trailing;

  /// Sonda `chevron-right` (ui.js:75).
  final bool chevron;

  /// Dokunma; `null` → statik satır.
  final VoidCallback? onTap;

  /// Dolgu varyantı.
  final GuTilePadding padding;

  /// Çocukları üstten hizalar (varsayılan dikey orta).
  final bool alignStart;

  /// Basılı zemin rengi çizilmez (`.is-plain`).
  final bool plain;

  /// Yıkıcı eylem görünümü (başlık `state.danger`).
  final bool danger;

  /// Devre dışı: soluk, dokunma çağrılmaz.
  final bool disabled;

  /// Başlık stil üst yazımı (prototip `titleClass`; ör. `ActivityRow`
  /// bodyS). Varsayılan stille birleştirilir.
  final TextStyle? titleStyle;

  @override
  State<GuTile> createState() => _GuTileState();
}

class _GuTileState extends State<GuTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final text = gu.text;
    final leading = widget.leading;
    final trailing = widget.trailing;
    final subtitle = widget.subtitle;
    final sub2 = widget.sub2;
    final titleSpan = widget.titleSpan;
    final titleWidget = widget.titleWidget;
    final sub2Widget = widget.sub2Widget;
    final titleStyle = text.bodyM
        .copyWith(
          color: widget.danger ? colors.stateDanger : colors.textHeading,
        )
        .merge(widget.titleStyle);

    final row = Row(
      crossAxisAlignment: widget.alignStart
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      spacing: GuSizes.tileGap,
      children: [
        ?leading,
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (titleWidget != null)
                DefaultTextStyle(style: titleStyle, child: titleWidget)
              else if (titleSpan == null)
                Text(widget.title, style: titleStyle)
              else
                Text.rich(
                  titleSpan,
                  style: titleStyle,
                  semanticsLabel: widget.title,
                ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: text.bodyS.copyWith(color: colors.textMuted),
                ),
              if (sub2 != null) Text(sub2, style: text.caption),
              if (sub2Widget != null)
                DefaultTextStyle(style: text.caption, child: sub2Widget),
            ],
          ),
        ),
        if (trailing != null)
          DefaultTextStyle(
            style: text.bodyM.copyWith(color: colors.textMuted),
            child: trailing,
          ),
        if (widget.chevron)
          GuIcon(
            GuIcons.chevronRight,
            size: GuSizes.tileChevron,
            color: colors.textMuted,
          ),
      ],
    );

    final body = Opacity(
      opacity: widget.disabled ? GuOpacity.disabled : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _pressed && !widget.plain ? colors.bgSurfaceMuted : null,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: GuSizes.tileMinHeight),
          child: Padding(padding: widget.padding.insets, child: row),
        ),
      ),
    );

    if (widget.onTap == null) return body;
    return GuTapTarget(
      onTap: widget.onTap,
      onPressedChanged: _setPressed,
      enabled: !widget.disabled,
      child: body,
    );
  }
}
