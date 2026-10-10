// T-06 · GuBottomNav (widget-catalog #43; A.2 #43; css:133–137; shell.js:11;
// K-07, CD-29, CD-81, CD-82, CD-111).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const List<GuBottomNavItem> _five = [
  GuBottomNavItem(icon: GuIcons.usersRound, label: 'Kulüpler'),
  GuBottomNavItem(icon: GuIcons.calendar, label: 'Etkinlikler'),
  GuBottomNavItem(icon: GuIcons.bell, label: 'Bildirimler', badge: '9+'),
  GuBottomNavItem(icon: GuIcons.shieldCheck, label: 'Admin'),
  GuBottomNavItem(icon: GuIcons.user, label: 'Profil'),
];

Key _key(int index) => ValueKey<String>('nav.$index');

Widget _host(Widget child) =>
    Align(alignment: Alignment.bottomCenter, child: child);

final Finder _indicator = find.byWidgetPredicate(
  (widget) =>
      widget is DecoratedBox &&
      (widget.decoration as BoxDecoration).borderRadius ==
          GuRadius.navIndicator,
);

void main() {
  group('T-06 · GuBottomNav', () {
    testWidgets('T-06 · GuBottomNav · çubuk, seçili / varsayılan sekme, '
        'gösterge 28×3, rozet açık + koyu token değerleriyle; alt güvenli '
        'alan', (tester) async {
      for (final (mode, colors) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        final text = GuTypography.resolve(colors);
        await tester.pumpApp(
          _host(
            GuBottomNav(
              items: _five,
              currentIndex: 2,
              onTap: (_) {},
              semanticLabel: 'Ana gezinme',
              tabKeyBuilder: _key,
            ),
          ),
          theme: mode,
        );
        final bar = tester.getRect(find.byType(GuBottomNav));
        // 56 (1 px üst kenarlık dahil); tam genişlik (CD-29).
        expect(bar, const Rect.fromLTWH(0, 844 - 56, 390, 56));
        final box =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byType(GuBottomNav),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(box.color, colors.bgSurface, reason: '$mode');
        expect(box.border, Border(top: BorderSide(color: colors.borderSoft)));

        // Eşit genişlik: 390 / 5; sekme kenarlığın altında başlar.
        for (var index = 0; index < 5; index++) {
          expect(
            tester.getRect(find.byKey(_key(index))),
            Rect.fromLTWH(78.0 * index, bar.top + 1, 78, 55),
          );
        }

        // Etiket Inter 600 11: seçili brand.primaryText, diğerleri text.muted.
        expect(
          tester.widget<Text>(find.text('Bildirimler')).style,
          text.navLabel.copyWith(color: colors.brandPrimaryText),
        );
        expect(tester.widget<Text>(find.text('Profil')).style, text.navLabel);
        expect(text.navLabel.color, colors.textMuted);

        // İkon 24, etiketten 3 px önce.
        final selected = find.byKey(_key(2));
        final icon = find.descendant(
          of: selected,
          matching: find.byType(GuIcon),
        );
        expect(tester.getSize(icon), const Size.square(24));
        expect(tester.widget<GuIcon>(icon).color, colors.brandPrimaryText);
        expect(
          tester.getTopLeft(find.text('Bildirimler')).dy -
              tester.getBottomLeft(icon).dy,
          3,
        );

        // Gösterge: yalnızca seçili sekmede, üstte ortalı 28×3.
        expect(_indicator, findsOneWidget);
        final tab = tester.getRect(selected);
        expect(
          tester.getRect(_indicator),
          Rect.fromLTWH(tab.center.dx - 14, tab.top, 28, 3),
        );
        expect(
          (tester.widget<DecoratedBox>(_indicator).decoration as BoxDecoration)
              .color,
          colors.brandPrimary,
        );

        // Rozet: GuCountBadge(sm, ring) üst 6, sol %50 + 4 (css:137).
        final badge = find.byType(GuCountBadge);
        expect(badge, findsOneWidget);
        expect(tester.widget<GuCountBadge>(badge).label, '9+');
        expect(tester.widget<GuCountBadge>(badge).ring, isTrue);
        expect(tester.widget<GuCountBadge>(badge).size, GuCountBadgeSize.sm);
        expect(
          tester.getTopLeft(badge),
          Offset(tab.center.dx + 4, tab.top + 6),
        );
      }

      // K-07: gerçek alt inset eklenir (56 + 34).
      await tester.pumpApp(
        _host(
          GuBottomNav(
            items: _five.sublist(0, 4),
            currentIndex: 0,
            onTap: (_) {},
            semanticLabel: 'Ana gezinme',
            tabKeyBuilder: _key,
          ),
        ),
        viewPadding: const EdgeInsets.only(bottom: 34),
      );
      expect(
        tester.getRect(find.byType(GuBottomNav)),
        const Rect.fromLTWH(0, 844 - 90, 390, 90),
      );
      expect(tester.getSize(find.byKey(_key(3))), const Size(97.5, 55));
    });

    testWidgets('T-06 · GuBottomNav · dokunma → onTap(index) (seçili sekme '
        'dahil), renk geçişi; Semantics navigation + düğme + selected; '
        'dokunma hedefi', (tester) async {
      final handle = tester.ensureSemantics();
      const colors = GuColors.light;
      final log = <int>[];
      var current = 0;
      await tester.pumpApp(
        _host(
          StatefulBuilder(
            builder: (context, setState) => GuBottomNav(
              items: _five,
              currentIndex: current,
              onTap: (index) {
                log.add(index);
                setState(() => current = index);
              },
              semanticLabel: 'Ana gezinme',
              tabKeyBuilder: _key,
            ),
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      final nav = tester.getSemantics(find.byType(GuBottomNav));
      expect(nav.label, 'Ana gezinme');
      expect(nav.getSemanticsData().role, SemanticsRole.navigation);
      expect(
        tester.getSemantics(find.byKey(_key(0))),
        isSemantics(
          label: 'Kulüpler',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      // Rozet sekme düğümüne birleşir.
      expect(
        tester.getSemantics(find.byKey(_key(2))),
        isSemantics(
          label: 'Bildirimler\n9+',
          isButton: true,
          hasSelectedState: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.byKey(_key(2)));
      await tester.pump();
      expect(log, [2]);
      await tester.pump(GuMotion.fast);
      expect(
        tester.widget<Text>(find.text('Bildirimler')).style!.color,
        colors.brandPrimaryText,
      );
      expect(
        tester.widget<Text>(find.text('Kulüpler')).style!.color,
        colors.textMuted,
      );
      expect(
        tester.getRect(_indicator).center.dx,
        tester.getRect(find.byKey(_key(2))).center.dx,
      );
      expect(
        tester.getSemantics(find.byKey(_key(2))),
        isSemantics(isSelected: true),
      );
      // Seçili sekmeye tekrar dokunma da bildirilir (köke dön, kabuk).
      await tester.tap(find.byKey(_key(2)));
      expect(log, [2, 2]);
      handle.dispose();
    });

    testWidgets('T-06 · GuBottomNav · 320 × 1.6, 5 sekme uzun etiket taşmaz '
        '(üç nokta); rozet ölçeklenmez', (tester) async {
      await tester.pumpApp(
        _host(
          GuBottomNav(
            items: const [
              GuBottomNavItem(icon: GuIcons.usersRound, label: 'Communities'),
              GuBottomNavItem(icon: GuIcons.calendar, label: 'Etkinlikler'),
              GuBottomNavItem(
                icon: GuIcons.bell,
                label: 'Notifications',
                badge: '9+',
              ),
              GuBottomNavItem(icon: GuIcons.shieldCheck, label: 'Admin'),
              GuBottomNavItem(icon: GuIcons.user, label: 'Profil'),
            ],
            currentIndex: 4,
            onTap: (_) {},
            semanticLabel: 'Ana gezinme',
            tabKeyBuilder: _key,
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.getSize(find.byType(GuBottomNav)).width, 320);
      expect(tester.getSize(find.byKey(_key(0))).width, 64);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Notifications'))
            .didExceedMaxLines,
        isTrue,
      );
      // 24 + 3 + 11 × 1.6 × 1.2 < 55: yükseklik değişmez.
      expect(tester.getSize(find.byType(GuBottomNav)).height, 56);
      // K-57: rozet 18 + 2 × 2 halka.
      expect(tester.getSize(find.byType(GuCountBadge)).height, 22);
    });
  });
}
