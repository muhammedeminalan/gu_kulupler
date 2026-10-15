import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/format/relative_time_formatter.dart';
import 'package:gu_ui/gu_ui.dart';

/// MGT-08 içerik satırı — prototip `Tile` (`screens-manage.js:165`):
/// tür ikonu (`.notif-icon` 40 · ikon 18: duyuru `megaphone` brand, anket
/// `chart-column` info, gönderi `file-text` neutral) · başlık (sabitse önce
/// 14'lük brand `pin`; duyuruda başlık, değilse metin — tek satır) ·
/// "{göreli zaman} · {n} beğeni · {n} yorum" (+ gizlenmişse " · gizlendi") ·
/// "⋮" (`more-vertical`).
///
/// Prototipteki şikayet rozeti (`content.reports`, `sub2`) çizilmez:
/// şikayetler yalnızca süper admince okunur (rules-spec §3.10), kulüp
/// yönetimine sayı kaynağı yoktur. Anahtarlar çağırandan
/// (`MGT-08.row.<id>`, `MGT-08.menu.<id>`).
class ManageContentRow extends ConsumerWidget {
  /// [post] gönderisinin yönetim satırı.
  const ManageContentRow({
    required this.post,
    required this.actionKey,
    required this.menuKey,
    required this.onTap,
    required this.onMenu,
    super.key,
  });

  /// Gönderi.
  final PostModel post;

  /// Satırın aksiyon anahtarı (`MGT-08.row.<id>`).
  final Key actionKey;

  /// "⋮" düğmesinin aksiyon anahtarı (`MGT-08.menu.<id>`).
  final Key menuKey;

  /// Satıra dokunma (FED-02).
  final VoidCallback onTap;

  /// "⋮" (açılır menü).
  final VoidCallback onMenu;

  /// Alt satır parçaları arasındaki ayraç (`' · '`).
  static const String _separator = ' · ';

  /// [type] türünün ikonu ve tonu (`screens-manage.js:165`).
  static (GuIcons, GuIconBoxTone) visualOf(PostType type) => switch (type) {
    PostType.announcement => (GuIcons.megaphone, GuIconBoxTone.brand),
    PostType.poll => (GuIcons.chartColumn, GuIconBoxTone.info),
    PostType.post => (GuIcons.fileText, GuIconBoxTone.neutral),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gu = context.gu;
    final l10n = context.l10n;
    final clock = ref.watch(appClockProvider);
    final formats = AppDateFormats(Localizations.localeOf(context), clock);
    final created = post.createdAt;
    final title = post.title ?? post.text;
    final (icon, tone) = visualOf(post.type);
    final subtitle = [
      if (created != null) RelativeTimeFormatter(l10n, clock).format(created),
      l10n.contentStats(
        formats.number(post.likeCount),
        formats.number(post.commentCount),
      ),
      if (post.isHidden) l10n.contentHidden,
    ].join(_separator);
    return GuTile(
      key: actionKey,
      title: title,
      titleWidget: Row(
        spacing: GuSpacing.s6,
        children: [
          if (post.pinned)
            GuIcon(
              GuIcons.pin,
              size: GuSizes.icon14,
              color: gu.colors.brandPrimaryText,
            ),
          Flexible(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      subtitle: subtitle,
      leading: GuIconBox(icon: icon, tone: tone, iconSize: GuSizes.icon18),
      trailing: GuIconButton(
        key: menuKey,
        icon: GuIcons.moreVertical,
        semanticLabel: l10n.a11yMore,
        onPressed: onMenu,
      ),
      onTap: onTap,
    );
  }
}
