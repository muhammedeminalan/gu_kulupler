// T-06 · gezinme / düzen grubu galeri golden'ı
// (`gu_gallery_nav__default__*.png`): GuBottomNav, GuAppBar, GuPageDots,
// GuStickyCta.
// Referans: `ds_nav.webp` (4 / 5 sekme + "9+", büyük başlık + arama, geri +
// başlık + alt başlık + menü, arama satırı), `screens/MGT-05` (kapat + adım
// çubuğu, alt eylem çubuğu), `screens/ONB-01` (noktalar).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/golden_helper.dart';

void _noop() {}

void _noopIndex(int _) {}

const List<GuBottomNavItem> _tabs = [
  GuBottomNavItem(icon: GuIcons.usersRound, label: 'Kulüpler'),
  GuBottomNavItem(icon: GuIcons.calendar, label: 'Etkinlikler'),
  GuBottomNavItem(icon: GuIcons.bell, label: 'Bildirimler', badge: '9+'),
  GuBottomNavItem(icon: GuIcons.shieldCheck, label: 'Admin'),
  GuBottomNavItem(icon: GuIcons.user, label: 'Profil'),
];

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s12,
      children: [
        // ds_nav: 4 sekme (admin yok), Kulüpler seçili, "9+".
        GuBottomNav(
          items: [..._tabs.sublist(0, 3), _tabs[4]],
          currentIndex: 0,
          onTap: _noopIndex,
          semanticLabel: 'Ana gezinme',
        ),
        // ds_nav: 5 sekme (süper admin).
        const GuBottomNav(
          items: _tabs,
          currentIndex: 0,
          onTap: _noopIndex,
          semanticLabel: 'Ana gezinme',
        ),
        // ds_nav / CLB-01: büyük başlık + arama.
        const GuAppBar(
          title: 'Kulüpler',
          large: true,
          actions: [
            GuIconButton(
              icon: GuIcons.search,
              semanticLabel: 'Ara',
              onPressed: _noop,
            ),
          ],
        ),
        // ds_nav / CLB-06: geri + başlık + alt başlık + menü.
        const GuAppBar(
          title: 'Kulüp',
          subtitle: 'Doğa Sporları ve Dağcılık Kulübü',
          onBack: _noop,
          backSemanticLabel: 'Geri',
          actions: [
            GuIconButton(
              icon: GuIcons.moreVertical,
              semanticLabel: 'Menü',
              onPressed: _noop,
            ),
          ],
        ),
        // ds_nav / CLB-02: arama satırı + "İptal".
        const GuAppBar(
          titleWidget: GuSearchField(value: 'hackathon', compact: true),
          actions: [
            GuButton(
              label: 'İptal',
              variant: GuButtonVariant.text,
              onPressed: _noop,
            ),
          ],
        ),
        // MGT-05: kapat + özel başlık (caption + adım çubuğu).
        GuAppBar(
          closeIcon: true,
          onBack: _noop,
          backSemanticLabel: 'Kapat',
          titleWidget: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: GuSpacing.s6,
            children: [
              Text('Etkinlik oluştur · 1/3', style: gu.text.caption),
              const GuStepbar(step: 1, total: 3, semanticLabel: '1/3'),
            ],
          ),
        ),
        // css:128 `.is-surface` (prototipte kullanılmıyor).
        const GuAppBar(
          title: 'Yüzey çubuğu',
          surface: true,
          onBack: _noop,
          backSemanticLabel: 'Geri',
        ),
        // ONB-01: 1. slayt etkin.
        const GuPageDots(count: 3, index: 0),
        // MGT-05 1. adım: tek tam düğme.
        const GuStickyCta(
          children: [GuButton(label: 'Devam', onPressed: _noop)],
        ),
        // MGT-05 2. adım: geri + devam.
        const GuStickyCta(
          children: [
            GuButton(
              label: 'Geri',
              variant: GuButtonVariant.outline,
              onPressed: _noop,
            ),
            GuButton(label: 'Devam', onPressed: _noop),
          ],
        ),
      ],
    );
  }
}

void main() {
  testWidgets('T-06 · gezinme / düzen grubu · galeri golden (açık + koyu)', (
    tester,
  ) async {
    await goldenForWidget(tester, 'gu_gallery_nav', {
      'default': const _Gallery(),
    });
  });
}
