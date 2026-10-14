// T-31 · MgtKpiGrid — MGT-01 gösterge ızgarası (prototip `.grid2`,
// `screens-manage.js:24`): iki sütun, aralık 12, aynı satırdaki kartlar eşit
// boy; tek sayıda kartta son hücre boş; kartların anahtarları ve dokunmaları
// çağırandan; uzun etiket 320 dp × 1.6'da taşmaz.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/management/view/widget/mgt_kpi_grid.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/pump_app.dart';

const List<String> _ids = ['members', 'pending', 'events', 'announcements'];

Key _key(String id) => GuKey.action('MGT-01.kpi.$id');

/// MGT-01'in dört kartı; [tapped] dokunulan kimlikleri toplar.
List<Widget> _cards(BuildContext context, List<String> tapped) {
  final l10n = context.l10n;
  return [
    GuKpi(
      key: _key('members'),
      label: l10n.mgtKpiMembers,
      value: '231',
      subtitle: l10n.mgtKpiNewThisMonth(4),
      icon: GuIcons.users,
      onTap: () => tapped.add('members'),
    ),
    GuKpi(
      key: _key('pending'),
      label: l10n.mgtKpiPending,
      value: '9',
      accent: true,
      icon: GuIcons.userPlus,
      onTap: () => tapped.add('pending'),
    ),
    GuKpi(
      key: _key('events'),
      label: l10n.mgtKpiEvents,
      value: '2',
      icon: GuIcons.calendar,
      onTap: () => tapped.add('events'),
    ),
    GuKpi(
      key: _key('announcements'),
      label: l10n.mgtKpiAnnouncements,
      value: '1',
      icon: GuIcons.megaphone,
      onTap: () => tapped.add('announcements'),
    ),
  ];
}

Widget _screen(BuildContext context, {List<String>? tapped, int count = 4}) =>
    Scaffold(
      body: SingleChildScrollView(
        padding: GuInsets.all16,
        child: MgtKpiGrid(
          children: _cards(context, tapped ?? []).take(count).toList(),
        ),
      ),
    );

void main() {
  group('T-31 · MgtKpiGrid', () {
    testWidgets('2 × 2: sütun aralığı 12, satır aralığı 12, aynı satırda eşit '
        'boy; anahtar → dokunma', (tester) async {
      final tapped = <String>[];
      await tester.pumpApp(
        Builder(builder: (context) => _screen(context, tapped: tapped)),
      );
      final members = tester.getRect(find.byKey(_key('members')));
      final pending = tester.getRect(find.byKey(_key('pending')));
      final events = tester.getRect(find.byKey(_key('events')));
      expect(pending.left - members.right, GuSpacing.s12);
      expect(events.top - members.bottom, GuSpacing.s12);
      expect(members.width, pending.width);
      // Alt satırlı kart (members) ile alt satırsız (pending) aynı boy.
      expect(members.height, pending.height);
      for (final id in _ids) {
        await tester.tap(find.byKey(_key(id)));
      }
      expect(tapped, _ids);
    });

    testWidgets('tek sayıda kart: son satırın ikinci hücresi boş, kart yarım '
        'genişlik', (tester) async {
      await tester.pumpApp(
        Builder(builder: (context) => _screen(context, count: 3)),
      );
      expect(find.byType(GuKpi), findsNWidgets(3));
      expect(
        tester.getSize(find.byKey(_key('events'))).width,
        tester.getSize(find.byKey(_key('members'))).width,
      );
    });

    testWidgets('cihaz matrisi: taşma yok (320 dp, ölçek 1.6, TR / EN)', (
      tester,
    ) async {
      await DeviceMatrix.run(tester, _screen);
    });
  });
}
