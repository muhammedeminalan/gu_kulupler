import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// PRF-04 kayıt kartı — prototip `Card` + `card-body row gap12 start`
/// (`screens-profile.js:56`).
///
/// * Gönderi varken: "kulüp · göreli zaman" (caption) · başlık (titleS,
///   varsa) · metin (bodyS `text.secondary`, 2 satır) · sağda dolu değil yer
///   imi (`brand`); kart dokunulabilir (gönderi detayı).
/// * Gönderi kaldırıldıysa ([post] `null`): `ban` + "İçerik kaldırıldı"
///   (labelL `text.muted`) · sağda çöp kutusu; kart dokunulamaz.
///
/// Anahtarları çağıran verir: kart `PRF-04.post.<id>`, düğme
/// `PRF-04.unsave.<id>`.
class SavedPostCard extends StatelessWidget {
  /// [post] gönderisinin kartı.
  const SavedPostCard({
    required this.post,
    required this.cardKey,
    required this.unsaveKey,
    required this.onUnsave,
    this.meta,
    this.onOpen,
    super.key,
  });

  /// Erişilebilirlik etiketindeki metin uzunluğu (`p.text.slice(0, 40)`).
  static const int _labelLength = 40;

  /// Gönderi; `null` → kaldırıldı satırı.
  final PostModel? post;

  /// "Kulüp · göreli zaman" satırı (çağıran biçimler).
  final String? meta;

  /// Kartın anahtarı.
  final Key cardKey;

  /// "Kaydı kaldır" düğmesinin anahtarı.
  final Key unsaveKey;

  /// Karta dokunma; kaldırılmış gönderide yok sayılır.
  final VoidCallback? onOpen;

  /// "Kaydı kaldır".
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final text = gu.text;
    final l10n = context.l10n;
    final post = this.post;
    final meta = this.meta;
    final title = post?.title;

    final Widget body;
    if (post == null) {
      body = Row(
        spacing: GuSpacing.s6,
        children: [
          GuIcon(GuIcons.ban, size: GuSizes.icon16, color: colors.textMuted),
          Flexible(
            child: Text(
              l10n.savedRemoved,
              style: text.labelL.copyWith(color: colors.textMuted),
            ),
          ),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: GuSpacing.s4,
        children: [
          if (meta != null) Text(meta, style: text.caption),
          if (title != null && title.isNotEmpty)
            Text(title, style: text.titleS.copyWith(color: colors.textHeading)),
          Text(
            post.text,
            style: text.bodyS.copyWith(color: colors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return GuCard(
      key: cardKey,
      onTap: post == null ? null : onOpen,
      padding: GuCard.bodyPadding,
      semanticLabel: post == null
          ? l10n.savedRemoved
          : post.text.characters.take(_labelLength).toString(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: GuSpacing.s12,
        children: [
          Expanded(child: body),
          GuIconButton(
            key: unsaveKey,
            icon: post == null ? GuIcons.trash2 : GuIcons.bookmark,
            semanticLabel: l10n.feedUnsave,
            tone: GuIconButtonTone.brand,
            onPressed: onUnsave,
          ),
        ],
      ),
    );
  }
}
