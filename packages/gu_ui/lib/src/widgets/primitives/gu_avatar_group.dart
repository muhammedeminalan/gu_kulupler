import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/primitives/gu_avatar.dart';

/// [GuAvatarGroup] öğesi: bir [GuAvatar]'ın verisi (boyut gruptan gelir).
@immutable
class GuAvatarData {
  const GuAvatarData({required this.initials, required this.seed, this.image});

  /// Baş harfler (`fullName.initials`).
  final String initials;

  /// Renk tohumu.
  final String seed;

  /// Fotoğraf; `null` → baş harf zemini.
  final ImageProvider? image;
}

/// Bindirmeli avatar dizisi — prototip `AvatarGroup` (`art.js:48`), CSS
/// `.avatar-group` + `.more` (css:218).
///
/// İlk [max] avatar 2 px `bg.surface` halkayla, her biri öncekinin üstüne
/// 8 px binerek çizilir (sonraki üstte). [moreLabel] verilirse sonda "+N"
/// hapı: en az [size] genişlik, yatay dolgu 6, `bg.surfaceMuted` zemin,
/// `text.secondary` Inter 600 (`GuTypography.avatarMoreFor`), `border-radius:
/// 50%` → metin genişledikçe elips.
///
/// * [size] ∈ `GuSizes.avatarGroupSizes` (24 ClubCard, 28 varsayılan / CLB-03,
///   32 EVT-02 — K-47).
/// * [moreLabel] çağırandan biçimlenmiş gelir ("+227"); kalan ≤ 0 ise `null`
///   verilir (`art.js:50` `rest > 0`).
/// * Metin ölçeklenmez (K-57). Avatarlar dekoratiftir; [semanticLabel]
///   verilirse grup tek etiketle okunur, verilmezse yalnız "+N" metni.
class GuAvatarGroup extends StatelessWidget {
  const GuAvatarGroup({
    required this.avatars,
    this.moreLabel,
    this.size = GuSizes.avatarGroupSize,
    this.max = GuSizes.avatarGroupMax,
    this.semanticLabel,
    super.key,
  });

  /// Gösterilecek kişiler; ilk [max] tanesi çizilir.
  final List<GuAvatarData> avatars;

  /// Sondaki "+N" hapının metni; `null` → hap yok.
  final String? moreLabel;

  /// Avatar çapı ve hap yüksekliği (dp).
  final double size;

  /// En çok çizilecek avatar sayısı.
  final int max;

  /// Erişilebilirlik etiketi; `null` → yalnız "+N" metni okunur.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    assert(
      GuSizes.avatarGroupSizes.contains(size),
      'GuAvatarGroup.size GuSizes.avatarGroupSizes içinde olmalı (K-47): $size',
    );
    final shown = avatars.take(max).toList(growable: false);
    final more = moreLabel;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, data) in shown.indexed)
          _Overlapped(
            size: size,
            // Son öğe bindirilmez (ardından gelen yoksa tam genişlik).
            overlap: more != null || index < shown.length - 1,
            child: GuAvatar(
              initials: data.initials,
              seed: data.seed,
              image: data.image,
              size: size,
              ring: true,
            ),
          ),
        if (more != null)
          Flexible(
            child: _MorePill(label: more, size: size),
          ),
      ],
    );
    final label = semanticLabel;
    if (label == null) return row;
    return Semantics(
      label: label,
      container: true,
      child: ExcludeSemantics(child: row),
    );
  }
}

/// Sonraki öğenin 8 px üstüne binmesi için yerleşim genişliğini daraltır
/// (CSS `margin-left:-8px`, css:218); çocuk tam [size] çizilir.
class _Overlapped extends StatelessWidget {
  const _Overlapped({
    required this.size,
    required this.overlap,
    required this.child,
  });

  final double size;
  final bool overlap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!overlap) return child;
    return SizedBox(
      width: size - GuSizes.avatarGroupOverlap,
      height: size,
      child: OverflowBox(
        alignment: AlignmentDirectional.centerStart,
        minWidth: size,
        maxWidth: size,
        minHeight: size,
        maxHeight: size,
        child: child,
      ),
    );
  }
}

/// "+N" hapı — `.avatar.more` (`art.js:50`, css:217–218).
class _MorePill extends StatelessWidget {
  const _MorePill({required this.label, required this.size});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: size,
        minHeight: size,
        maxHeight: size,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: gu.colors.bgSurface,
          shape: const OvalBorder(),
        ),
        child: Padding(
          padding: GuInsets.sym(
            h: GuSizes.avatarGroupBorder,
            v: GuSizes.avatarGroupBorder,
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: gu.colors.bgSurfaceMuted,
              shape: const OvalBorder(),
            ),
            child: Padding(
              padding: GuInsets.sym(h: GuSizes.avatarMorePaddingX),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: gu.text.avatarMoreFor(size),
                  textScaler: TextScaler.noScaling,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
