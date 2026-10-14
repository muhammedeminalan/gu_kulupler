import 'package:flutter/widgets.dart';
import 'package:gu_ui/gu_ui.dart';

/// Profil fotoğrafı düğmesi — prototip `button.rel` + `Avatar size=96` +
/// `span.emblem.is-xs` kamera rozeti (`screens-profile.js:11` PRF-01, `:28`
/// PRF-02).
///
/// Rozet sağ alt köşede (`right:-2px;bottom:-2px`), zemin `brand.primary`,
/// ikon `camera` 14 `brand.onPrimary`; [bordered] → PRF-01'deki 2 px
/// `bg.canvas` kenarlığı (CD-91). Dokunma SHT-16'yı açar (çağıran).
/// Anahtar çağırandan ([actionKey]; D-18); avatar görseli çağıranda çözülür
/// ([image]: seçilmiş fotoğraf önizlemesi ya da `storageImageResolverProvider`
/// ile `avatarPath`, CD-143).
class ProfileAvatarButton extends StatelessWidget {
  /// [initials] / [seed] avatarı ve kamera rozetiyle düğme.
  const ProfileAvatarButton({
    required this.initials,
    required this.seed,
    required this.semanticLabel,
    required this.onTap,
    required this.actionKey,
    this.image,
    this.bordered = false,
    super.key,
  });

  /// Avatar baş harfleri.
  final String initials;

  /// Avatar gradyan tohumu (`users.avatarSeed`).
  final String seed;

  /// Profil fotoğrafı; `null` → baş harfler.
  final ImageProvider? image;

  /// Erişilebilirlik etiketi (`aria-label` "Fotoğrafı değiştir").
  final String semanticLabel;

  /// Dokunma (SHT-16).
  final VoidCallback onTap;

  /// Düğmenin anahtarı (`PRF-01.avatar` / `PRF-02.avatar`).
  final Key actionKey;

  /// Rozette 2 px `bg.canvas` kenarlığı (PRF-01).
  final bool bordered;

  /// `Avatar size=96` — `GuSizes.avatarSizes` içindeki 96.
  static final double avatarSize = GuSizes.avatarSizes[7];

  @override
  Widget build(BuildContext context) {
    final colors = context.gu.colors;
    return GuActionSurface(
      key: actionKey,
      borderRadius: GuRadius.borderFull,
      semanticLabel: semanticLabel,
      onTap: onTap,
      builder: (context, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          GuAvatar(
            initials: initials,
            seed: seed,
            size: avatarSize,
            image: image,
          ),
          Positioned(
            right: -GuSpacing.s2,
            bottom: -GuSpacing.s2,
            child: GuEmblem(
              icon: GuIcons.camera,
              size: GuEmblemSize.xs,
              iconSize: GuSizes.icon14,
              background: colors.brandPrimary,
              foreground: colors.brandOnPrimary,
              borderColor: bordered ? colors.bgCanvas : null,
              borderWidth: bordered ? GuSizes.avatarBadgeBorder : 0,
            ),
          ),
        ],
      ),
    );
  }
}
