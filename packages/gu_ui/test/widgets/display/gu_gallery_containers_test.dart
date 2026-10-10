// T-04 · kap/satır grubu galeri golden'ı
// (`gu_gallery_containers__default__*.png`): GuSectionTitle, GuGroupHeader,
// GuCard, GuTile, GuHorizontalList, GuKpi, GuQuickAction.
// Referans: `ds_cards.webp` (KPI), `ds_special.webp` (hızlı işlem),
// `screens/SET-01` (kart içi satırlar), `screens/MGT-01` (KPI + hızlı işlem),
// `screens/PRF-01` (compact KPI), `screens/CLB-02` (bölüm başlığı),
// `screens/EVT-01` (grup başlığı).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/golden_helper.dart';

Widget _grid(List<Widget> children) => IntrinsicHeight(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: GuSpacing.s12,
    children: [for (final child in children) Expanded(child: child)],
  ),
);

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final colors = context.gu.colors;
    final text = context.gu.text;
    Widget icon(GuIcons icon, {Color? color}) => GuIcon(
      icon,
      size: GuSizes.icon22,
      color: color ?? colors.brandPrimaryText,
    );
    return SizedBox(
      width: 358,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s12,
        children: [
          GuSectionTitle(
            title: 'Son aramalar',
            subtitle: 'Bu cihazda',
            actionLabel: 'Temizle',
            onAction: () {},
            topMargin: GuSectionTitleMargin.first,
          ),
          const GuGroupHeader(title: 'BU HAFTA', trailingText: '6'),
          // Kart içi satırlar (SET-01): ikon + alt satır + chevron, trailing
          // metin, danger, disabled + sub2.
          GuCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GuTile(
                  padding: GuTilePadding.inCard,
                  leading: icon(GuIcons.sun),
                  title: 'Tema',
                  subtitle: 'Açık',
                  chevron: true,
                  onTap: () {},
                ),
                const GuDivider(),
                GuTile(
                  padding: GuTilePadding.inCard,
                  leading: icon(GuIcons.fileText),
                  title: 'Yazı boyutu',
                  trailing: const Text('Aa'),
                ),
                const GuDivider(),
                GuTile(
                  padding: GuTilePadding.inCard,
                  leading: icon(GuIcons.trash2, color: colors.stateDanger),
                  title: 'Hesabı sil',
                  danger: true,
                  onTap: () {},
                ),
                const GuDivider(),
                GuTile(
                  padding: GuTilePadding.inCard,
                  leading: icon(GuIcons.userPlus, color: colors.textHeading),
                  title: 'Yeniden başvur',
                  subtitle: 'Doğa Sporları ve Dağcılık Kulübü',
                  sub2: '3 gün sonra açılır',
                  disabled: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
          // muted + borderColor (SET-03 uyarı kartı).
          _grid([
            GuCard(
              muted: true,
              padding: GuCard.bodyPadding,
              child: Text('Sessiz kart', style: text.bodyS),
            ),
            GuCard(
              borderColor: colors.stateWarning,
              padding: GuCard.bodyPadding,
              child: Text(
                'Önce başkanlığı devret',
                style: text.labelL.copyWith(color: colors.stateWarning),
              ),
            ),
          ]),
          // Yatay şerit: dokunulabilir mini kartlar (CLB-01 "Kulüplerim").
          GuHorizontalList(
            padding: GuHorizontalListPadding.bottom,
            children: [
              for (final name in [
                'Yazılım ve Yapay Zekâ Topluluğu',
                'Fotoğraf ve Sinema Kulübü',
                'Doğa Sporları',
                'Tiyatro',
              ])
                GuCard(
                  onTap: () {},
                  padding: GuInsets.all12,
                  child: SizedBox(
                    width: 108,
                    child: Text(name, style: text.labelM, maxLines: 2),
                  ),
                ),
            ],
          ),
          // KPI: standard (accent) + compact (PRF-01).
          _grid([
            GuKpi(
              label: 'Toplam üye',
              value: '231',
              subtitle: '+12 bu ay',
              icon: GuIcons.users,
              onTap: () {},
            ),
            GuKpi(
              label: 'Bekleyen başvuru',
              value: '9',
              icon: GuIcons.userPlus,
              accent: true,
              onTap: () {},
            ),
          ]),
          _grid([
            for (final (value, label) in [
              ('2', 'Kulüp'),
              ('1', 'Katıldığım etkinlik'),
              ('1', 'Bekleyen başvuru'),
            ])
              GuKpi(
                label: label,
                value: value,
                layout: GuKpiLayout.compact,
                onTap: () {},
              ),
          ]),
          // Hızlı işlem: default × 2 + disabled.
          _grid([
            GuQuickAction(
              icon: GuIcons.pencil,
              label: 'Gönderi yaz',
              onTap: () {},
            ),
            GuQuickAction(
              icon: GuIcons.megaphone,
              label: 'Duyuru yap',
              onTap: () {},
            ),
            GuQuickAction(
              icon: GuIcons.scanLine,
              label: 'Yoklama al',
              onTap: () {},
              disabled: true,
            ),
          ]),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('T-04 · kap/satır grubu · galeri golden (açık + koyu)', (
    tester,
  ) async {
    await goldenForWidget(
      tester,
      'gu_gallery_containers',
      {'default': const _Gallery()},
      size: const Size(390, 1100),
    );
  });
}
