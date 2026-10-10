// T-06 · GuAppBar (widget-catalog #18; A.2 #18; css:127–131; ui.js:79;
// K-07, CD-29, CD-111).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const Key _backKey = ValueKey<String>('appbar.back');
const Key _menuKey = ValueKey<String>('appbar.menu');
const Key _bodyKey = ValueKey<String>('appbar.body');

Widget _host(Widget child) =>
    Align(alignment: Alignment.topCenter, child: child);

Widget _menu({Key? key = _menuKey}) => GuIconButton(
  key: key,
  icon: GuIcons.moreVertical,
  semanticLabel: 'Menü',
  onPressed: () {},
);

BoxDecoration _decoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(GuAppBar),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  group('T-06 · GuAppBar', () {
    testWidgets('T-06 · GuAppBar · normal / large / surface / closeIcon açık + '
        'koyu token değerleriyle', (tester) async {
      for (final (mode, colors) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        final text = GuTypography.resolve(colors);
        final bar = find.byType(GuAppBar);

        // Normal: min 56, dolgu 4 / 8, aralık 4, başlık dolgusu 8.
        await tester.pumpApp(
          _host(
            GuAppBar(
              title: 'Kulüp',
              subtitle: 'Doğa Sporları ve Dağcılık Kulübü',
              onBack: () {},
              backSemanticLabel: 'Geri',
              backActionKey: _backKey,
              actions: [_menu()],
            ),
          ),
          theme: mode,
        );
        expect(tester.getSize(bar), const Size(390, 56));
        expect(_decoration(tester).color, colors.bgCanvas, reason: '$mode');
        expect(_decoration(tester).border, isNull);
        expect(
          tester.getRect(find.byKey(_backKey)),
          const Rect.fromLTWH(8, 4, 48, 48),
        );
        expect(
          tester.widget<GuIconButton>(find.byKey(_backKey)).icon,
          GuIcons.arrowLeft,
        );
        expect(tester.getTopLeft(find.text('Kulüp')).dx, 8 + 48 + 4 + 8);
        expect(tester.widget<Text>(find.text('Kulüp')).style, text.titleS);
        expect(text.titleS.color, colors.textHeading);
        final subtitle = find.text('Doğa Sporları ve Dağcılık Kulübü');
        expect(tester.widget<Text>(subtitle).style, text.caption);
        expect(text.caption.color, colors.textMuted);
        expect(
          tester.getTopLeft(subtitle).dy,
          tester.getBottomLeft(find.text('Kulüp')).dy,
        );
        expect(
          tester.getRect(find.byKey(_menuKey)),
          const Rect.fromLTWH(390 - 8 - 48, 4, 48, 48),
        );
        // Başlık bloğu eylemden 4 + 8 önce biter.
        expect(tester.getTopRight(subtitle).dx, lessThanOrEqualTo(322));

        // Large: dolgu 8 / 16 / 12, titleL; eylemle 68, eylemsiz 56.
        await tester.pumpApp(
          _host(GuAppBar(title: 'Kulüpler', large: true, actions: [_menu()])),
          theme: mode,
        );
        expect(tester.getSize(bar), const Size(390, 68));
        expect(tester.getTopLeft(find.text('Kulüpler')).dx, 16);
        expect(tester.widget<Text>(find.text('Kulüpler')).style, text.titleL);
        expect(
          tester.getRect(find.byKey(_menuKey)),
          const Rect.fromLTWH(390 - 16 - 48, 8, 48, 48),
        );
        await tester.pumpApp(
          _host(const GuAppBar(title: 'Kulüpler', large: true)),
          theme: mode,
        );
        expect(tester.getSize(bar), const Size(390, 56));
        expect(find.byType(GuIconButton), findsNothing);

        // Surface: bg.surface + alt 1 px border.soft; kenarlık kutunun
        // içinde (css:78): 48'lik düğmeyle 4 + 48 + 4 + 1; closeIcon → x.
        await tester.pumpApp(
          _host(
            GuAppBar(
              title: 'Etkinlik oluştur',
              surface: true,
              closeIcon: true,
              onBack: () {},
              backSemanticLabel: 'Kapat',
              backActionKey: _backKey,
            ),
          ),
          theme: mode,
        );
        expect(tester.getSize(bar), const Size(390, 57));
        expect(_decoration(tester).color, colors.bgSurface);
        expect(
          _decoration(tester).border,
          Border(bottom: BorderSide(color: colors.borderSoft)),
        );
        expect(
          tester.widget<GuIconButton>(find.byKey(_backKey)).icon,
          GuIcons.x,
        );
        expect(tester.getRect(find.byKey(_backKey)).top, 4);
      }
    });

    testWidgets('T-06 · GuAppBar · geri → onBack; Semantics başlık + düğme; '
        'dokunma hedefi; Scaffold.appBar: üst güvenli alan, gövde çubuğun '
        'altında', (tester) async {
      final handle = tester.ensureSemantics();
      var backs = 0;
      await tester.pumpApp(
        Scaffold(
          appBar: GuAppBar(
            title: 'Kulüp',
            onBack: () => backs++,
            backSemanticLabel: 'Geri',
            backActionKey: _backKey,
            actions: [_menu()],
          ),
          body: const SizedBox.expand(key: _bodyKey),
        ),
        viewPadding: const EdgeInsets.only(top: 47),
      );
      // K-07: gerçek üst inset çubuğun içinde; tam genişlik (CD-29).
      expect(
        tester.getRect(find.byType(GuAppBar)),
        const Rect.fromLTWH(0, 0, 390, 47 + 56),
      );
      expect(tester.getRect(find.byKey(_backKey)).top, 47 + 4);
      expect(tester.getRect(find.byKey(_bodyKey)).top, 47 + 56);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      expect(
        tester.getSemantics(find.byKey(_backKey)),
        isSemantics(
          label: 'Geri',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Kulüp')),
        isSemantics(label: 'Kulüp', isHeader: true),
      );

      await tester.tap(find.byKey(_backKey));
      expect(backs, 1);
      handle.dispose();
    });

    testWidgets('T-06 · GuAppBar · 320 × 1.6 uzun başlık + alt başlık taşmaz '
        '(üç nokta), çubuk büyür; titleWidget başlığın yerine geçer', (
      tester,
    ) async {
      const title = 'Doğa Sporları ve Dağcılık Kulübü yönetim paneli';
      const subtitle = 'Bekleyen başvurular ve üyelik geçmişi kayıtları';
      await tester.pumpApp(
        Scaffold(
          appBar: GuAppBar(
            title: title,
            subtitle: subtitle,
            onBack: () {},
            backSemanticLabel: 'Geri',
            actions: [_menu(), _menu(key: null)],
          ),
          body: const SizedBox.expand(key: _bodyKey),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      for (final label in [title, subtitle]) {
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(label))
              .didExceedMaxLines,
          isTrue,
          reason: label,
        );
      }
      // 16 × 1.6 × 1.375 + 12 × 1.6 × 1.333 + 8 > 56: Scaffold kırpmaz.
      final bar = tester.getRect(find.byType(GuAppBar));
      expect(bar.width, 320);
      expect(bar.height, greaterThan(GuSizes.appBarMinHeight));
      expect(tester.getRect(find.byKey(_bodyKey)).top, bar.bottom);

      await tester.pumpApp(
        _host(
          const GuAppBar(
            title: 'Büyük başlık kırpılır mı diye çok uzun bir sekme adı',
            large: true,
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.getSize(find.byType(GuAppBar)).width, 320);

      await tester.pumpApp(
        _host(
          const GuAppBar(title: 'Gizli', titleWidget: Text('Adım 1 / 3')),
        ),
      );
      expect(find.text('Adım 1 / 3'), findsOneWidget);
      expect(find.text('Gizli'), findsNothing);
      expect(tester.getTopLeft(find.text('Adım 1 / 3')).dx, 8 + 8);
    });
  });
}
