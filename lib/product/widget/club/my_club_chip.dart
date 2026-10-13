import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

/// "Kulüplerim" şeridindeki küçük kulüp kartı — prototip `MyClubChip`
/// (`cards.js:41–45`; K-30: adı "chip", kendisi 132 genişliğinde karttır).
///
/// * 16:9 kapak; [manager] ise "Yönetici" rozeti, kulüp askıdaysa "Askıda"
///   rozeti (kapağın sol üstü, 6 / 6). Prototip ikisini aynı konuma üst üste
///   çizer; burada askı önceliklidir (tek rozet).
/// * Gövde dolgusu 8 / 10 / 10: ad (`labelM`, başlık rengi, 2 satır) ve
///   [unread] ise satırın sonunda 8 dp okunmamış bildirim noktası.
/// * Genişlik `GuSizes.myClubCardWidth` (132) sabittir: yatay şeritte
///   (`.hscroll`) yan yana dizilir. Basılı ölçek kart varsayılanıdır
///   (`.card.is-tappable:active` .99, `.pressable`'dan özgül — css:206, 340).
/// * Dokunma [onTap] (CLB-03). Anahtarı çağıran verir (D-18, CD-86):
///   [actionKey] `<ID>.myClub.<clubId>`.
///
/// Erişilebilirlik: kart tek düğmedir; etiketi rozet + ad (+ "Okunmamış
/// bildirim") metinlerinden birleşir.
///
/// ```dart
/// MyClubChip(
///   club: club,
///   manager: access == ClubAccess.manager,
///   unread: unreadClubIds.contains(club.id),
///   actionKey: GuKey.action('CLB-01.myClub.${club.id}'),
///   onTap: () => openClub(club),
/// )
/// ```
class MyClubChip extends StatelessWidget {
  /// [club] kulübünün "Kulüplerim" kartı.
  const MyClubChip({
    required this.club,
    required this.onTap,
    this.unread = false,
    this.manager = false,
    this.actionKey,
    super.key,
  });

  /// Kulüp.
  final ClubModel club;

  /// Kulübe ait okunmamış bildirim var (ad satırının sonunda nokta).
  final bool unread;

  /// Kullanıcı kulübün yöneticisi (başkan / yönetim kurulu): "Yönetici"
  /// rozeti.
  final bool manager;

  /// Dokunma — kulübü açar (CLB-03).
  final VoidCallback onTap;

  /// Kartın anahtarı (`<ID>.myClub.<clubId>`).
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final badge = club.isSuspended
        ? GuBadge(
            label: l10n.statusSuspended,
            kind: GuBadgeKind.danger,
            icon: GuIcons.ban,
          )
        : manager
        ? GuBadge(
            label: l10n.clubsCardManager,
            kind: GuBadgeKind.president,
            icon: GuIcons.shieldCheck,
          )
        : null;

    return SizedBox(
      width: GuSizes.myClubCardWidth,
      child: GuCard(
        key: actionKey,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoverMapper.club(
              club,
              overlays: [
                if (badge != null)
                  Positioned(
                    left: GuSpacing.s6,
                    top: GuSpacing.s6,
                    right: GuSpacing.s6,
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: badge,
                    ),
                  ),
              ],
            ),
            Padding(
              // `padding:8px 10px 10px` (cards.js:44): 10 = kulüp kartı
              // gövde ölçüsü (`cards.js:32` ile aynı değer).
              padding: GuInsets.only(
                left: GuSizes.clubCardBodyPaddingTop,
                top: GuSpacing.s8,
                right: GuSizes.clubCardBodyPaddingTop,
                bottom: GuSizes.clubCardBodyPaddingTop,
              ),
              child: Row(
                spacing: GuSpacing.s6,
                children: [
                  Expanded(
                    child: Text(
                      club.name,
                      style: gu.text.labelM.copyWith(
                        color: gu.colors.textHeading,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (unread)
                    Semantics(
                      label: l10n.clubsMyUnread,
                      child: SizedBox.square(
                        dimension: GuSizes.dot,
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: gu.colors.brandPrimary,
                            shape: const CircleBorder(),
                          ),
                        ),
                      ),
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
