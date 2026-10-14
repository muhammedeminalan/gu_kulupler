import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// FED-01 "yazı oluştur" girişi — prototip `Feed` (`screens-clubs.js:66`):
/// yalnızca yöneticiye, süzgeç çiplerinin üstünde çizilen dokunulabilir kart.
///
/// Kart dolgusu 12 / 16, aralık 12: kullanıcının avatarı (36) · "Kulübüne bir
/// şey yaz…" (`bodyM`, `text.muted`, tek satır) · kalem ikonu (18,
/// `brand.primaryText`). Dokunma [onTap] (→ FED-03).
///
/// Anahtarı çağıran verir (D-18, CD-86): `FeedComposeEntry(key:
/// GuKey.action('FED-01.compose'), …)`.
class FeedComposeEntry extends StatelessWidget {
  /// [user] kullanıcısının yazı oluşturma girişi.
  const FeedComposeEntry({
    required this.user,
    this.onTap,
    this.avatarImage,
    super.key,
  });

  /// Oturumdaki kullanıcı (avatar); `null` → `?`.
  final UserModel? user;

  /// Profil fotoğrafı (çağıran `ref.userAvatarImage(user)` ile çözer,
  /// T-27); `null` → baş harfler.
  final ImageProvider? avatarImage;

  /// Karta dokunma → FED-03.
  final VoidCallback? onTap;

  /// Avatar çapı (`screens-clubs.js:66` `Avatar size=36`).
  static final double avatarSize = GuSizes.avatarSizes[2];

  /// Belgesi olmayan kullanıcının avatar metni ve renk tohumu (`art.js:44`).
  static const String _unknown = '?';

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final user = this.user;
    return GuCard(
      onTap: onTap,
      semanticLabel: l10n.feedComposePlaceholder,
      padding: GuInsets.sym(h: GuSpacing.s16, v: GuSpacing.s12),
      child: Row(
        spacing: GuSpacing.s12,
        children: [
          GuAvatar(
            initials: (user?.name ?? _unknown).initials,
            seed: user == null
                ? _unknown
                : (user.avatarSeed.isEmpty ? user.uid : user.avatarSeed),
            size: avatarSize,
            image: avatarImage,
          ),
          Expanded(
            child: Text(
              l10n.feedComposePlaceholder,
              style: gu.text.bodyM.copyWith(color: gu.colors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GuIcon(
            GuIcons.pencil,
            size: GuSizes.icon18,
            color: gu.colors.brandPrimaryText,
          ),
        ],
      ),
    );
  }
}
