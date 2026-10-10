// T-05 · gezinme / seçici grubu galeri golden'ı
// (`gu_gallery_navsel__default__*.png`): GuSegmented, GuTabs, GuStepbar,
// GuWheelPicker.
// Referans: `ds_selection.webp` (ikonlu 2'li segment), `ds_nav.webp` (3 sekme
// + sayaç, adım çubuğu 2/3), `screens/CLB-03` (4 sekme), `sheets/SHT-29`
// (saat / dakika tekerleği + seçim bandı).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/golden_helper.dart';

void _noop(String _) {}

String _pad2(int value) => value.toString().padLeft(2, '0');

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s16,
      children: [
        // ds_selection: ikonlu 2'li (EVT-01 liste / takvim).
        const GuSegmented(
          options: [
            GuSegmentOption(id: 'a', label: 'Liste', icon: GuIcons.list),
            GuSegmentOption(
              id: 'b',
              label: 'Takvim',
              icon: GuIcons.calendarDays,
            ),
          ],
          value: 'a',
          onChanged: _noop,
        ),
        // SET-01: 3'lü yazı ölçeği.
        const GuSegmented(
          options: [
            GuSegmentOption(id: '100', label: '%100'),
            GuSegmentOption(id: '130', label: '%130'),
            GuSegmentOption(id: '160', label: '%160'),
          ],
          value: '130',
          onChanged: _noop,
        ),
        // ADM-01: 4'lü AdminNav (dar bölmede üç nokta).
        const GuSegmented(
          options: [
            GuSegmentOption(id: 'home', label: 'Panel'),
            GuSegmentOption(id: 'clubs', label: 'Kulüpler'),
            GuSegmentOption(id: 'reports', label: 'Şikayetler'),
            GuSegmentOption(id: 'users', label: 'Kullanıcılar ve roller'),
          ],
          value: 'users',
          onChanged: _noop,
        ),
        // ds_nav: Hakkında / Etkinlikler / Gönderiler 3.
        const GuTabs(
          tabs: [
            GuTabItem(id: 'a', label: 'Hakkında'),
            GuTabItem(id: 'b', label: 'Etkinlikler'),
            GuTabItem(id: 'c', label: 'Gönderiler', count: 3),
          ],
          value: 'a',
          onChanged: _noop,
        ),
        // CLB-03: 4 eşit sekme, ikinci seçili.
        const GuTabs(
          tabs: [
            GuTabItem(id: 'about', label: 'Hakkında'),
            GuTabItem(id: 'events', label: 'Etkinlikler'),
            GuTabItem(id: 'posts', label: 'Gönderiler'),
            GuTabItem(id: 'members', label: 'Üyeler'),
          ],
          value: 'events',
          onChanged: _noop,
        ),
        // K-37 (2): eşit paya sığmayan etiket → içerik genişliği.
        const GuTabs(
          tabs: [
            GuTabItem(id: 'active', label: 'Aktif üyeliklerim', count: 12),
            GuTabItem(id: 'pending', label: 'Bekleyen'),
            GuTabItem(id: 'history', label: 'Geçmiş'),
          ],
          value: 'active',
          onChanged: _noop,
        ),
        // K-05 / K-37 (3): toplam taşar → kaydırılabilir, dolgu 16.
        const GuTabs(
          tabs: [
            GuTabItem(id: 'active', label: 'Active memberships'),
            GuTabItem(id: 'pending', label: 'Pending applications', count: 2),
            GuTabItem(id: 'history', label: 'Membership history'),
          ],
          value: 'active',
          onChanged: _noop,
        ),
        // ds_nav: adım çubuğu 2/3 (+ 1/3).
        const GuStepbar(step: 2, total: 3, semanticLabel: '2/3'),
        const GuStepbar(step: 1, total: 3, semanticLabel: '1/3'),
        // SHT-29: saat 18, dakika 00; seçim bandı sheet'e aittir.
        Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Center(
                child: Container(
                  height: GuSizes.wheelItemHeight,
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: gu.colors.borderDefault),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              spacing: GuSpacing.s8,
              children: [
                Expanded(
                  child: GuWheelPicker(
                    values: [for (var h = 0; h < 24; h++) _pad2(h)],
                    value: '18',
                    onChanged: _noop,
                    semanticLabel: 'Saat',
                  ),
                ),
                Text(':', style: gu.text.titleM),
                Expanded(
                  child: GuWheelPicker(
                    values: [for (var m = 0; m < 60; m += 5) _pad2(m)],
                    value: '00',
                    onChanged: _noop,
                    semanticLabel: 'Dakika',
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

void main() {
  testWidgets('T-05 · gezinme / seçici grubu · galeri golden (açık + koyu)', (
    tester,
  ) async {
    await goldenForWidget(tester, 'gu_gallery_navsel', {
      'default': const _Gallery(),
    });
  });
}
