import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_component_colors.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/utils/stable_hash.dart';

/// Avatar — prototip `Avatar` (`art.js:43`), CSS `.avatar` (css:217).
///
/// Daire; fotoğraf yoksa [seed]'den türeyen 135° HSL gradyan ([gradientFor],
/// `art.js:41`) üstünde [initials] (Montserrat 700, `size × 0.4`,
/// `#fff` — K-55). [image] verilirse baş harf zemininin üstüne `cover` ile
/// çizilir; yüklenirken ve hata durumunda baş harfler görünür kalır (ayrı
/// durum yok). Boyutlar `GuSizes.avatarSizes`; varsayılan 40.
///
/// * [initials] çağırandan gelir (`fullName.initials`, `string_x.dart`).
/// * Baş harf ölçeklenmez (K-57): `TextScaler.noScaling`; daireye sığmayan
///   metin kırpılır (`overflow:hidden`).
/// * [ring] → 2 px `bg.surface` halka, kutunun **içinde** (`.avatar-group
///   .avatar{border:2px solid}`, css:218; `border-box`): dış ölçü ve baş
///   harf boyutu [size]'tan, gradyan dairesi `size − 4`.
/// * [semanticLabel] verilmezse dekoratiftir (`aria-hidden`; ad çağıranda).
class GuAvatar extends StatelessWidget {
  const GuAvatar({
    required this.initials,
    required this.seed,
    this.size = GuSizes.avatar,
    this.image,
    this.semanticLabel,
    this.ring = false,
    super.key,
  });

  /// Baş harfler (1–2 harf; `'?'` adsız).
  final String initials;

  /// Renk tohumu (`user.avatarSeed ?? user.id`); aynı tohum → aynı gradyan.
  final String seed;

  /// Çap (dp).
  final double size;

  /// Fotoğraf; `null` → yalnız baş harf zemini.
  final ImageProvider? image;

  /// Erişilebilirlik etiketi; `null` → dekoratif.
  final String? semanticLabel;

  /// `bg.surface` halka (avatar grubu).
  final bool ring;

  /// Renk çemberi (derece).
  static const int _hueCircle = 360;

  /// Tohumun birinci gradyan durağı tonu, 0–359 (`art.js:41`
  /// `hashStr('av:' + seed) % 360`).
  static int hueFor(String seed) =>
      GuStableHash.fnv1a32('av:$seed') % _hueCircle;

  /// Tohumdan 135° gradyan (`art.js:41` `avatarColors`): `hsl(hue 48% 42%)`
  /// → `hsl(hue + 36 55% 32%)`, sol üstten sağ alta.
  static LinearGradient gradientFor(String seed) {
    final hue = hueFor(seed);
    final hue2 = (hue + GuComponentColors.avatarHueShift) % _hueCircle;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        HSLColor.fromAHSL(
          1,
          hue.toDouble(),
          GuComponentColors.avatarSaturation1,
          GuComponentColors.avatarLightness1,
        ).toColor(),
        HSLColor.fromAHSL(
          1,
          hue2.toDouble(),
          GuComponentColors.avatarSaturation2,
          GuComponentColors.avatarLightness2,
        ).toColor(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final photo = image;
    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradientFor(seed),
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(
                initials,
                style: gu.text
                    .avatarInitialsFor(size)
                    .copyWith(color: gu.component.avatarInitials),
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
              ),
            ),
            if (photo != null)
              Image(
                image: photo,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
    if (ring) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          color: gu.colors.bgSurface,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: GuInsets.sym(
            h: GuSizes.avatarGroupBorder,
            v: GuSizes.avatarGroupBorder,
          ),
          child: content,
        ),
      );
    }
    content = SizedBox.square(dimension: size, child: content);
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: content);
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(child: content),
    );
  }
}
