import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/format/relative_time_formatter.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// Yorum satırı — FED-02 yorum listesi ve SHT-09 (prototip
/// `screens-clubs.js:176`, `sheets.js:48`): avatar + ad (+ rol rozeti) +
/// göreli zaman + gövde metni (+ "…" menüsü). Kişi satırı kompozisyonudur
/// (CD-27); ölçüleri `.tile` değil satır içi stildir.
///
/// * Yerleşim: dikey dolgu 8, üstten hizalı; avatar 32 · aralık 8 (`row
///   gap10` → 8, K-42) · metin sütunu (aralık 2): ad (`labelL`
///   `text.heading`) + rozet + göreli zaman (`caption`) aynı satırda, sığmazsa
///   alt satıra iner (`row gap6 wrap`); altında yorum metni (`bodyM`) · sonda
///   40'lık "…" düğmesi.
/// * [author] yorum sahibinin güncel belgesidir; `null` → "Silinmiş
///   kullanıcı". [role] üye dışındaki rollerde rozet olarak çizilir
///   (`role !== 'member'`).
/// * Avatara dokunma [onAuthor] (CLB-07); "…" [onMenu] (kendi yorumu → DLG-11,
///   başkası → SHT-27). Geri çağrı verilmeyen öğe çizilmez / düz kalır
///   (SHT-09 satırında ikisi de yoktur).
/// * Göreli zaman uygulama saatinden (`AppClock`) hesaplanır; henüz sunucu
///   zamanı gelmemiş yorum "Az önce"dir.
/// * Erişilebilirlik: avatar düğmesi yazarın adıyla okunur; ad, zaman ve
///   metin düz metindir; menü ayrı düğmedir ("Daha fazla").
/// * Anahtarları çağıran verir (D-18, CD-86): [authorKey]
///   `<ID>.author.<commentId>`, [menuKey] `<ID>.commentMenu.<commentId>`.
class CommentRow extends ConsumerWidget {
  /// [comment] yorumunun satırı.
  const CommentRow({
    required this.comment,
    this.author,
    this.role,
    this.onAuthor,
    this.authorKey,
    this.onMenu,
    this.menuKey,
    super.key,
  });

  /// Yorum.
  final CommentModel comment;

  /// Yorum sahibinin güncel belgesi; `null` → "Silinmiş kullanıcı".
  final UserModel? author;

  /// Yorum sahibinin kulüpteki rolü; üye dışındaysa rozet çizilir.
  final ClubRole? role;

  /// Avatara dokunma → profil (CLB-07); `null` → düz avatar.
  final VoidCallback? onAuthor;

  /// Avatar düğmesinin anahtarı (`<ID>.author.<commentId>`).
  final Key? authorKey;

  /// "…" menüsü; `null` → düğme çizilmez.
  final VoidCallback? onMenu;

  /// Menü düğmesinin anahtarı (`<ID>.commentMenu.<commentId>`).
  final Key? menuKey;

  /// Silinmiş kullanıcının avatar metni ve renk tohumu (`art.js:44`).
  static const String _unknown = '?';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gu = context.gu;
    final l10n = context.l10n;
    final author = this.author;
    final role = author == null ? null : this.role;
    final onAuthor = this.onAuthor;
    final onMenu = this.onMenu;
    final created = comment.createdAt;
    final authorName = author?.name ?? l10n.commonDeletedUser;

    final String seed;
    if (author == null) {
      seed = _unknown;
    } else {
      seed = author.avatarSeed.isEmpty ? author.uid : author.avatarSeed;
    }
    final avatar = GuAvatar(
      initials: (author?.name ?? _unknown).initials,
      seed: seed,
      size: GuSizes.commentAvatar,
    );

    return Padding(
      padding: GuInsets.v8,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onAuthor == null)
            avatar
          else
            GuTapTarget(
              key: authorKey,
              onTap: onAuthor,
              semanticLabel: authorName,
              child: avatar,
            ),
          GuGap.h8,
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: GuSpacing.s2,
              children: [
                Wrap(
                  spacing: GuSpacing.s6,
                  runSpacing: GuSpacing.s6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      authorName,
                      style: gu.text.labelL.copyWith(
                        color: gu.colors.textHeading,
                      ),
                    ),
                    if (role != null && role != ClubRole.member)
                      MemberRow.roleBadge(l10n, role),
                    Text(
                      created == null
                          ? l10n.timeJustNow
                          : RelativeTimeFormatter(
                              l10n,
                              ref.watch(appClockProvider),
                            ).format(created),
                      style: gu.text.caption,
                    ),
                  ],
                ),
                Text(comment.text, style: gu.text.bodyM),
              ],
            ),
          ),
          if (onMenu != null) ...[
            GuGap.h8,
            GuIconButton(
              key: menuKey,
              icon: GuIcons.moreHorizontal,
              semanticLabel: l10n.a11yMore,
              size: GuIconButtonSize.sm,
              onPressed: onMenu,
            ),
          ],
        ],
      ),
    );
  }
}
