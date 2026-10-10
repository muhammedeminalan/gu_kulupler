// T-05 · GuTabs (widget-catalog #12; A.2 #12; css:224–229; K-05, K-37,
// K-57, CD-81, CD-82, CD-111).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const List<GuTabItem> _tabs = [
  GuTabItem(id: 'about', label: 'Hakkında'),
  GuTabItem(id: 'events', label: 'Etkinlikler'),
  GuTabItem(id: 'posts', label: 'Gönderiler', count: 3),
];

const List<GuTabItem> _longTabs = [
  GuTabItem(id: 'active', label: 'Active memberships'),
  GuTabItem(id: 'pending', label: 'Pending applications', count: 12),
  GuTabItem(id: 'history', label: 'Membership history', icon: GuIcons.history),
];

Key _key(int index) => ValueKey<String>('tab.$index');

final Finder _indicator = find.byWidgetPredicate(
  (widget) =>
      widget is DecoratedBox &&
      (widget.decoration as BoxDecoration).borderRadius ==
          GuRadius.tabIndicator,
);

bool _clipped(WidgetTester tester, String label) =>
    tester.renderObject<RenderParagraph>(find.text(label)).didExceedMaxLines;

Widget _host(Widget child) =>
    Align(alignment: Alignment.topCenter, child: child);

void main() {
  group('T-05 · GuTabs', () {
    testWidgets('T-05 · GuTabs · çubuk + varsayılan / seçili açık + koyu token '
        'değerleriyle; eşit bölüşüm, gösterge, sayaç', (tester) async {
      for (final (mode, colors) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        final text = GuTypography.resolve(colors);
        await tester.pumpApp(
          _host(
            GuTabs(
              tabs: _tabs,
              value: 'about',
              onChanged: (_) {},
              tabKeyBuilder: _key,
            ),
          ),
          theme: mode,
        );
        final bar = find.byType(GuTabs);
        // 48 + 1 px alt kenarlık; zemin bg.canvas, kenarlık border.soft.
        expect(tester.getSize(bar), const Size(390, 49));
        final box =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: bar,
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(box.color, colors.bgCanvas, reason: '$mode');
        expect(
          box.border,
          Border(bottom: BorderSide(color: colors.borderSoft)),
        );

        // Sığıyor → eşit bölüşüm (css:226 `flex:1`), kaydırma yok.
        expect(find.byType(SingleChildScrollView), findsNothing);
        for (var index = 0; index < 3; index++) {
          expect(tester.getSize(find.byKey(_key(index))), const Size(130, 48));
        }

        // Metin 600 14: seçili brand.primaryText, diğerleri text.muted.
        expect(
          tester.widget<Text>(find.text('Hakkında')).style,
          text.tab.copyWith(color: colors.brandPrimaryText),
        );
        expect(tester.widget<Text>(find.text('Etkinlikler')).style, text.tab);
        expect(text.tab.color, colors.textMuted);

        // Gösterge: yalnızca seçili sekmede, sol / sağ 16, 2 px, kenarlığın
        // üstüne biner (alt kenarı çubuğun alt kenarı).
        expect(_indicator, findsOneWidget);
        final tab = tester.getRect(find.byKey(_key(0)));
        final line = tester.getRect(_indicator);
        expect(line.left, tab.left + 16);
        expect(line.right, tab.right - 16);
        expect(line.height, 2);
        expect(line.bottom, tester.getRect(bar).bottom);
        expect(
          (tester.widget<DecoratedBox>(_indicator).decoration as BoxDecoration)
              .color,
          colors.brandPrimary,
        );

        // Sayaç: GuCountBadge(md) 20 px, metinden 6 px sonra.
        final badge = find.byType(GuCountBadge);
        expect(tester.widget<GuCountBadge>(badge).label, '3');
        expect(tester.widget<GuCountBadge>(badge).size, GuCountBadgeSize.md);
        expect(tester.getSize(badge), const Size(20, 20));
        expect(
          tester.getTopLeft(badge).dx -
              tester.getTopRight(find.text('Gönderiler')).dx,
          6,
        );
      }
    });

    testWidgets('T-05 · GuTabs · dokunma → onChanged(id), gösterge taşınır; '
        'Semantics tabBar / tab + selected; dokunma hedefi; sticky sliver '
        'üstte kalır', (tester) async {
      final handle = tester.ensureSemantics();
      const colors = GuColors.light;
      final log = <String>[];
      var value = 'about';
      await tester.pumpApp(
        StatefulBuilder(
          builder: (context, setState) => CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
              GuTabs(
                tabs: _tabs,
                value: value,
                sticky: true,
                onChanged: (id) {
                  log.add(id);
                  setState(() => value = id);
                },
                tabKeyBuilder: _key,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 2000)),
            ],
          ),
        ),
      );
      final first = find.byKey(_key(0));
      final third = find.byKey(_key(2));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      final node = tester.getSemantics(first);
      expect(
        node,
        isSemantics(
          label: 'Hakkında',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(node.getSemanticsData().role, SemanticsRole.tab);
      expect(node.parent!.getSemanticsData().role, SemanticsRole.tabBar);
      // Sayaç sekme düğümüne birleşir.
      expect(
        tester.getSemantics(third),
        isSemantics(
          label: 'Gönderiler\n3',
          hasSelectedState: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );

      await tester.tap(third);
      await tester.pump();
      expect(log, ['posts']);
      await tester.pump(GuMotion.fast);
      expect(_indicator, findsOneWidget);
      expect(
        tester.getRect(_indicator).left,
        tester.getRect(third).left + 16,
      );
      expect(
        tester.widget<Text>(find.text('Gönderiler')).style!.color,
        colors.brandPrimaryText,
      );
      expect(
        tester.widget<Text>(find.text('Hakkında')).style!.color,
        colors.textMuted,
      );
      expect(tester.getSemantics(third), isSemantics(isSelected: true));
      // Seçili olana dokunma da bildirilir (ui.js:62).
      await tester.tap(third);
      expect(log, ['posts', 'posts']);

      // css:225 `position:sticky; top:0`.
      expect(find.byType(PinnedHeaderSliver), findsOneWidget);
      final bar = find
          .descendant(
            of: find.byType(GuTabs),
            matching: find.byType(DecoratedBox),
          )
          .first;
      expect(tester.getTopLeft(bar).dy, 120);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      expect(tester.getTopLeft(bar).dy, 0);
      expect(tester.getSize(bar), const Size(390, 49));
      handle.dispose();
    });

    testWidgets('T-05 · GuTabs · K-05 / K-37: 320 dp × 1.6 EN uzun etiketler '
        'kaydırılabilir ve taşmaz; seçilen sekme görünür alana gelir; ara '
        'durumda içerik genişliği', (tester) async {
      var value = 'active';
      late StateSetter update;
      await tester.pumpApp(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return GuTabs(
                tabs: _longTabs,
                value: value,
                onChanged: (_) {},
                tabKeyBuilder: _key,
              );
            },
          ),
        ),
        locale: const Locale('en'),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      // Toplam taşar → kaydırılabilir, içerik genişliği, yatay dolgu 16.
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final bar = tester.getSize(find.byType(GuTabs));
      expect(bar.width, 320);
      expect(bar.height, greaterThanOrEqualTo(49));
      expect(
        tester.getTopLeft(find.text('Active memberships')).dx -
            tester.getTopLeft(find.byKey(_key(0))).dx,
        16,
      );
      for (final tab in _longTabs) {
        expect(_clipped(tester, tab.label), isFalse, reason: tab.label);
      }
      // Sayaç ölçeklenmez (K-57); ikon 16.
      expect(tester.getSize(find.byType(GuCountBadge)).height, 20);
      expect(tester.getSize(find.byType(GuIcon)), const Size(16, 16));
      // Son sekme başta görünür alanın dışında.
      expect(tester.getRect(find.byKey(_key(2))).left, greaterThan(320));

      // Seçim değişir → sekme görünür alana kayar (`GuMotion.fast`).
      update(() => value = 'history');
      await tester.pumpAndSettle();
      final revealed = tester.getRect(find.byKey(_key(2)));
      expect(revealed.left, greaterThanOrEqualTo(0));
      expect(revealed.right, lessThanOrEqualTo(320));
      expect(tester.getRect(_indicator).left, revealed.left + 16);

      // İlk karede seçili sekme dışarıdaysa animasyonsuz gösterilir.
      await tester.pumpApp(
        _host(
          GuTabs(
            tabs: _longTabs,
            value: 'history',
            onChanged: (_) {},
            tabKeyBuilder: _key,
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      await tester.pump();
      expect(
        tester.getRect(find.byKey(_key(2))).right,
        lessThanOrEqualTo(320),
      );

      // Tek etiket görünür alandan uzun → sekme çubuk genişliğinde kesilir.
      await tester.pumpApp(
        _host(
          GuTabs(
            tabs: [
              GuTabItem(id: 'a', label: 'Doğa Sporları ve Dağcılık ' * 4),
              const GuTabItem(id: 'b', label: 'Etkinlikler'),
            ],
            value: 'a',
            onChanged: (_) {},
            tabKeyBuilder: _key,
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(_key(0))).width, 320);
      expect(_clipped(tester, 'Doğa Sporları ve Dağcılık ' * 4), isTrue);

      // K-37 (2): eşit paya sığmayan etiket ama toplam sığıyor → kaydırma
      // yok, içerik genişliği + artan boşluğun eşit payı, kesme yok.
      const mixed = [
        GuTabItem(id: 'active', label: 'Aktif üyeliklerim', count: 12),
        GuTabItem(id: 'pending', label: 'Bekleyen'),
        GuTabItem(id: 'history', label: 'Geçmiş'),
      ];
      await tester.pumpApp(
        _host(
          GuTabs(
            tabs: mixed,
            value: 'active',
            onChanged: (_) {},
            tabKeyBuilder: _key,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsNothing);
      final widths = [
        for (var index = 0; index < 3; index++)
          tester.getSize(find.byKey(_key(index))).width,
      ];
      expect(widths[0], greaterThan(130));
      expect(widths[1], lessThan(130));
      expect(widths.reduce((a, b) => a + b), closeTo(390, 0.001));
      for (final tab in mixed) {
        expect(_clipped(tester, tab.label), isFalse, reason: tab.label);
      }

      // Sınırsız genişlik → içerik genişliği (hata yok).
      await tester.pumpApp(
        Row(
          children: [
            GuTabs(tabs: _tabs, value: 'about', onChanged: (_) {}),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuTabs)).width, lessThan(390));
    });
  });
}
