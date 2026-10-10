import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';

/// Rozet türü — CSS `.badge-*` 12 sınıfı birebir (css:189–199; CD-80, K-33).
enum GuBadgeKind {
  /// `.badge-neutral` (css:198): `bg.surfaceMuted` + `text.muted`.
  neutral,

  /// `.badge-success` (css:195): `state.successContainer` + `state.success`.
  success,

  /// `.badge-danger` (css:196): `state.dangerContainer` + `state.danger`.
  danger,

  /// `.badge-pending` (css:194): `state.warningContainer` + `state.warning`.
  pending,

  /// `.badge-info` (css:197): `state.infoContainer` + `state.info`.
  info,

  /// `.badge-full` (css:198): `neutral` ile aynı çift.
  full,

  /// `.badge-brand` (css:199): `brand.primary` + `#fff`; prototipte çağrısı
  /// yok, CSS kümesiyle birebirlik için durur.
  brand,

  /// `.badge-president` (css:189): `brand.primaryContainer` +
  /// `brand.onPrimaryContainer` (rol rozeti; `cards.js:26,43,114` düz çağrı).
  president,

  /// `.badge-board` (css:190): `bg.surfaceMuted` + `text.heading` + 1 px
  /// `border.default` kenarlık.
  board,

  /// `.badge-advisor` (css:191): `state.warningContainer` + `state.warning`.
  advisor,

  /// `.badge-member` (css:192): `bg.surfaceMuted` + `text.secondary`.
  member,

  /// `.badge-superadmin` (css:193): `text.heading` zemin + `bg.surface` metin.
  superadmin;

  /// Zemin, metin / ikon ve (yalnız [board]) kenarlık rengi.
  ({Color background, Color foreground, Color? border}) resolve(GuColors c) =>
      switch (this) {
        neutral || full => (
          background: c.bgSurfaceMuted,
          foreground: c.textMuted,
          border: null,
        ),
        success => (
          background: c.stateSuccessContainer,
          foreground: c.stateSuccess,
          border: null,
        ),
        danger => (
          background: c.stateDangerContainer,
          foreground: c.stateDanger,
          border: null,
        ),
        pending || advisor => (
          background: c.stateWarningContainer,
          foreground: c.stateWarning,
          border: null,
        ),
        info => (
          background: c.stateInfoContainer,
          foreground: c.stateInfo,
          border: null,
        ),
        brand => (
          background: c.brandPrimary,
          foreground: c.brandOnPrimary,
          border: null,
        ),
        president => (
          background: c.brandPrimaryContainer,
          foreground: c.brandOnPrimaryContainer,
          border: null,
        ),
        board => (
          background: c.bgSurfaceMuted,
          foreground: c.textHeading,
          border: c.borderDefault,
        ),
        member => (
          background: c.bgSurfaceMuted,
          foreground: c.textSecondary,
          border: null,
        ),
        superadmin => (
          background: c.textHeading,
          foreground: c.bgSurface,
          border: null,
        ),
      };
}

/// Etiket rozeti — prototip `Badge` (`ui.js:66`), CSS `.badge` (css:188) +
/// `.badge-*` (css:189–199). Tek rozet gövdesi: `GuRoleBadge` ve
/// `GuStatusBadge` bunu sarar (CD-27).
///
/// 22 px yükseklik, yatay dolgu 8, tam yuvarlak, ikon 12 + boşluk 4, metin
/// `GuTypography.badge` (Inter 600 12/1; metin ölçeğiyle büyür, yükseklik
/// sabit kalır). [GuBadgeKind.board] 1 px kenarlığı kutunun içindedir
/// (`border-box`: yükseklik 22 kalır, genişlik 2 px artar). Statiktir
/// (CSS'te durum kuralı yok); dar alanda etiket tek satırda `…` ile kısalır.
class GuBadge extends StatelessWidget {
  const GuBadge({
    required this.label,
    this.kind = GuBadgeKind.neutral,
    this.icon,
    super.key,
  });

  /// Rozet metni (çağıran ARB'den verir).
  final String label;

  /// Renk türü.
  final GuBadgeKind kind;

  /// Baştaki 12 px ikon; `null` → yalnız metin.
  final GuIcons? icon;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final (:background, :foreground, :border) = kind.resolve(gu.colors);
    final leading = icon;
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(height: GuSizes.badgeHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: GuRadius.borderFull,
          border: border == null
              ? null
              : Border.all(
                  color: border,
                  // Token varsayılanla (1) aynı; bağ css:190 için açık yazılır.
                  // ignore: avoid_redundant_argument_values
                  width: GuSizes.badgeBorder,
                ),
        ),
        child: Padding(
          padding: GuInsets.sym(
            h: border == null
                ? GuSizes.badgePaddingX
                : GuSizes.badgePaddingX + GuSizes.badgeBorder,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                GuIcon(leading, size: GuSizes.badgeIcon, color: foreground),
                const SizedBox(width: GuSizes.badgeGap),
              ],
              Flexible(
                child: Text(
                  label,
                  style: gu.text.badge.copyWith(color: foreground),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
