import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/manage/activity_texts.dart';
import 'package:gu_kulupler/product/widget/manage/activity_visuals.dart';
import 'package:gu_ui/gu_ui.dart';

/// Faaliyet satırı — prototip `ActivityRow` (`screens-manage.js:34–39`):
/// `GuTile` (kart içi) + eylemci avatarı (36) + metin (`bodyS`, eylemci adı
/// kalın) + göreli zaman + türün ikonu (18, `textMuted`; [ActivityVisuals]).
/// MGT-01 "Son hareketler" (kart içi, ayraçlı) ve MGT-10 (düz) listeleri
/// kullanır. Zaman çizelgesi rayı yoktur (K-36).
///
/// * Metni çağıran [ActivityTexts] ile üretir ([text]); zamanı çağıran
///   biçimler ([timeLabel]).
/// * Anahtarı çağıran verir (D-18): [actionKey] satırın kendisidir
///   (`<ID>.row.<activityId>`).
/// * Dokunma hedefi (etkinlik / gönderi / başvurular / profil / ayarlar)
///   çağıranın [onTap]'idir.
class ActivityRow extends StatelessWidget {
  /// [activity] kaydının satırı.
  const ActivityRow({
    required this.activity,
    required this.text,
    required this.timeLabel,
    required this.onTap,
    required this.actionKey,
    this.actor,
    this.actorImage,
    this.inCard = true,
    super.key,
  });

  /// Faaliyet kaydı (tür → ikon).
  final ActivityModel activity;

  /// Satır metni ([ActivityTexts.text]).
  final ActivityText text;

  /// Göreli zaman ("3 sa önce").
  final String timeLabel;

  /// Satıra dokunma.
  final VoidCallback onTap;

  /// Satırın aksiyon anahtarı (`GuKey.action`); çağıran verir.
  final Key actionKey;

  /// Eylemi yapan kullanıcı (avatar); `null` → `?`.
  final UserModel? actor;

  /// Eylemcinin profil fotoğrafı (`ref.userAvatarImage(actor)`); `null` →
  /// baş harfler.
  final ImageProvider? actorImage;

  /// Kart içi satır (`Tile inCard`).
  final bool inCard;

  /// Silinmiş / bilinmeyen kullanıcının avatar metni ve tohumu.
  static const String _unknown = '?';

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final actor = this.actor;
    final live = actor == null || actor.isDeleted || actor.isAnonymized
        ? null
        : actor;
    return GuTile(
      key: actionKey,
      title: text.text,
      // `.tile-title` bloğu body-m (15 / 22), içindeki cümle `t-body-s`
      // (13 / 18) span'idir: satır kutusu bloğun 22'sidir (css:92–93) →
      // span metni body-m strut'u ile çizilir.
      titleWidget: Text.rich(
        span(text, gu.text.titleL.fontWeight),
        semanticsLabel: text.text,
        strutStyle: StrutStyle.fromTextStyle(gu.text.bodyM),
      ),
      titleStyle: gu.text.bodyS.copyWith(color: gu.colors.textHeading),
      subtitle: timeLabel,
      leading: GuAvatar(
        initials: (live?.name ?? _unknown).initials,
        seed: live == null
            ? _unknown
            : (live.avatarSeed.isEmpty ? live.uid : live.avatarSeed),
        size: GuSizes.activityRowAvatar,
        image: live == null ? null : actorImage,
        semanticLabel: live?.name ?? context.l10n.commonDeletedUser,
      ),
      trailing: GuIcon(
        ActivityVisuals.icon(activity.kind),
        size: GuSizes.icon18,
        color: gu.colors.textMuted,
      ),
      padding: inCard ? GuTilePadding.inCard : GuTilePadding.normal,
      onTap: onTap,
    );
  }

  /// [text] cümlesi; içindeki ilk eylemci adı [bold] kalınlıkta (prototip
  /// `text.replace(actor, '<b>actor</b>')`, `screens-manage.js:38`). Ad boşsa
  /// ya da cümlede yoksa düz metin.
  static TextSpan span(ActivityText text, FontWeight? bold) {
    final sentence = text.text;
    final name = text.actorName;
    final start = name.isEmpty ? -1 : sentence.indexOf(name);
    if (start < 0) return TextSpan(text: sentence);
    final end = start + name.length;
    return TextSpan(
      children: [
        if (start > 0) TextSpan(text: sentence.substring(0, start)),
        TextSpan(
          text: name,
          style: TextStyle(fontWeight: bold),
        ),
        if (end < sentence.length) TextSpan(text: sentence.substring(end)),
      ],
    );
  }
}
