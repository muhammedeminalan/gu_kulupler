import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-03 "Hakkında" sekmesindeki kişi satırı — prototip `UserRow`'un kart
/// içi biçimi (`ui.js:129–132`; `screens-clubs.js:97–98`): avatar 40 · ad +
/// rozet · alt satır · `chevron-right`.
///
/// * Satır kabuğu `.tile.in-card`: en az 56, dolgu 10 / 16, aralık 12.
/// * Ad `bodyM` `text.heading`, tek satır + üç nokta; rozet adın yanında
///   durur, sığmazsa alt satıra iner (`row gap6 wrap`). Prototipteki sabit
///   `max-width:200px` yazılmaz (K-29).
/// * [onTap] verilirse satır düğmedir: basılıyken zemin `bg.surfaceMuted`,
///   sonda ok. Verilmezse (hesaba bağlanmamış danışman) düz satırdır.
/// * `key` (`GuKey.action`) satırın kendisidir.
class ClubPersonRow extends ConsumerStatefulWidget {
  /// [name] adlı kişinin satırı; avatar rengi [avatarSeed]'den türer.
  const ClubPersonRow({
    required this.name,
    required this.avatarSeed,
    this.subtitle,
    this.badge,
    this.onTap,
    super.key,
  });

  /// Görünen ad.
  final String name;

  /// Avatar renk tohumu.
  final String avatarSeed;

  /// Alt satır (bölüm · sınıf, rol adı); boşsa çizilmez.
  final String? subtitle;

  /// Adın yanındaki rozet (`GuRoleBadge`).
  final Widget? badge;

  /// Satıra dokunma; `null` → düz satır.
  final VoidCallback? onTap;

  @override
  ConsumerState<ClubPersonRow> createState() => _ClubPersonRowState();
}

class _ClubPersonRowState extends ConsumerState<ClubPersonRow> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final subtitle = widget.subtitle;
    final badge = widget.badge;
    final onTap = widget.onTap;

    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: _pressed ? colors.bgSurfaceMuted : null,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: GuSizes.tileMinHeight),
        child: Padding(
          padding: GuTilePadding.inCard.insets,
          child: Row(
            spacing: GuSizes.tileGap,
            children: [
              GuAvatar(
                initials: widget.name.initials,
                seed: widget.avatarSeed,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: GuSpacing.s6,
                      runSpacing: GuSpacing.s6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          widget.name,
                          style: gu.text.bodyM.copyWith(
                            color: colors.textHeading,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        ?badge,
                      ],
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: gu.text.bodyS.copyWith(color: colors.textMuted),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                GuIcon(
                  GuIcons.chevronRight,
                  size: GuSizes.tileChevron,
                  color: colors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return body;
    return GuTapTarget(
      onTap: onTap,
      onPressedChanged: _setPressed,
      child: body,
    );
  }
}
