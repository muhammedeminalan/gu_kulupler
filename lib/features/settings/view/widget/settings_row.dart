import 'package:flutter/widgets.dart';
import 'package:gu_ui/gu_ui.dart';

/// SET-01 ayar grubu — prototip `group(title, rows)` (`screens-profile.js:62`):
/// `.col.gap8` > `.t-overline.px16` başlık + `.px16` > `Card` (satırlar
/// arasında `.divider`).
///
/// Başlık büyük harfe yerel ayara göre çevrilir (`text-transform:uppercase`;
/// Türkçede `i → İ`, CD-11) ve başlık semantiği taşır.
class SettingsGroup extends StatelessWidget {
  /// [title] başlıklı, [children] satırlı grup.
  const SettingsGroup({
    required this.title,
    required this.children,
    super.key,
  });

  /// Grup başlığı (ARB; büyük harf burada uygulanır).
  final String title;

  /// Kart satırları, sırasıyla; aralarına ayırıcı çizilir.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        Padding(
          padding: GuInsets.h16,
          child: Semantics(
            header: true,
            child: Text(
              title.upperFor(locale),
              style: context.gu.text.overline,
            ),
          ),
        ),
        Padding(
          padding: GuInsets.h16,
          child: GuCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, child) in children.indexed) ...[
                  if (index > 0) const GuDivider(),
                  child,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// SET-01 satırı — prototip `row(icon, title, sub, action, onClick, opts)`
/// (`screens-profile.js:63`): kart içi `Tile` (dolgu 10/16), baştaki 20 px
/// ikon (`brand.primaryText`; yıkıcı satırda `state.danger`), başlık, isteğe
/// bağlı alt satır (seçili değer), sonda `chevron-right` (çıkış satırında
/// yok).
class SettingsRow extends StatelessWidget {
  /// [icon] ikonlu, [title] başlıklı satır.
  const SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.chevron = true,
    this.danger = false,
    super.key,
  });

  /// Baştaki ikon.
  final GuIcons icon;

  /// Başlık.
  final String title;

  /// Alt satır (seçili tema / dil); `null` → tek satır.
  final String? subtitle;

  /// Sonda `chevron-right` (prototip `noChevron` → `false`).
  final bool chevron;

  /// Yıkıcı eylem görünümü (ikon + başlık `state.danger`).
  final bool danger;

  /// Dokunma.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.gu.colors;
    return GuTile(
      title: title,
      subtitle: subtitle,
      padding: GuTilePadding.inCard,
      leading: GuIcon(
        icon,
        size: GuSizes.icon20,
        color: danger ? colors.stateDanger : colors.brandPrimaryText,
      ),
      chevron: chevron,
      danger: danger,
      onTap: onTap,
    );
  }
}
