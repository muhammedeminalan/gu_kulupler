// T-06 · GuStickyCta (widget-catalog #29; A.2 #29; css:296–299; ui.js:124;
// K-07, CD-85).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const Key _backKey = ValueKey<String>('cta.back');
const Key _nextKey = ValueKey<String>('cta.next');

Widget _host(Widget child) => Material(
  type: MaterialType.transparency,
  child: Align(alignment: Alignment.bottomCenter, child: child),
);

Finder get _surface => find
    .descendant(
      of: find.byType(GuStickyCta),
      matching: find.byType(DecoratedBox),
    )
    .first;

void main() {
  group('T-06 · GuStickyCta', () {
    testWidgets('T-06 · GuStickyCta · zemin / üst çizgi / ctaBar gölgesi açık '
        '+ koyu; dolgu 12 / 16, aralık 12; GuButton eşit paylaşır, diğer '
        'çocuk olduğu gibi; dokunma → callback', (tester) async {
      var taps = 0;
      for (final (mode, colors, shadows) in [
        (ThemeMode.light, GuColors.light, GuShadows.light),
        (ThemeMode.dark, GuColors.dark, GuShadows.dark),
      ]) {
        await tester.pumpApp(
          _host(
            GuStickyCta(
              children: [
                GuButton(
                  key: _backKey,
                  label: 'Geri',
                  variant: GuButtonVariant.outline,
                  onPressed: () {},
                ),
                GuButton(
                  key: _nextKey,
                  label: 'Devam',
                  onPressed: () => taps++,
                ),
              ],
            ),
          ),
          theme: mode,
        );
        // 1 (kenarlık) + 12 + 48 + 12.
        expect(
          tester.getRect(find.byType(GuStickyCta)),
          const Rect.fromLTWH(0, 844 - 73, 390, 73),
        );
        final box =
            tester.widget<DecoratedBox>(_surface).decoration as BoxDecoration;
        expect(box.color, colors.bgSurface, reason: '$mode');
        expect(box.border, Border(top: BorderSide(color: colors.borderSoft)));
        // css:296 `0 -4px 16px`; koyu temada gölge yok (css:299).
        expect(box.boxShadow, shadows.ctaBar);
        expect(shadows.ctaBar.isEmpty, mode == ThemeMode.dark);

        // css:298 `.ctabar .btn{flex:1}`: (390 − 32 − 12) / 2.
        expect(
          tester.getRect(find.byKey(_backKey)),
          const Rect.fromLTWH(16, 844 - 73 + 13, 173, 48),
        );
        expect(
          tester.getRect(find.byKey(_nextKey)),
          const Rect.fromLTWH(16 + 173 + 12, 844 - 73 + 13, 173, 48),
        );
      }
      await tester.tap(find.byKey(_nextKey));
      expect(taps, 1);

      // Düğme olmayan çocuk genişlemez; hizalama parametresi satıra geçer.
      await tester.pumpApp(
        _host(
          GuStickyCta(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Sırada 3. kişisin'),
              GuButton(key: _nextKey, label: 'Listeden çık', onPressed: () {}),
            ],
          ),
        ),
      );
      final note = tester.getRect(find.text('Sırada 3. kişisin'));
      final button = tester.getRect(find.byKey(_nextKey));
      expect(note.left, 16);
      expect(button.left, note.right + 12);
      expect(button.right, 390 - 16);
      expect(note.bottom, button.bottom);
    });

    testWidgets('T-06 · GuStickyCta · alt güvenli alan dolguya eklenir; klavye '
        'açıkken çubuk üstünde kalır; 320 × 1.6 uzun etiketler taşmaz', (
      tester,
    ) async {
      Widget bar() => _host(
        GuStickyCta(
          children: [
            GuButton(
              key: _backKey,
              label: 'Taslak olarak kaydet ve çık',
              variant: GuButtonVariant.outline,
              onPressed: () {},
            ),
            GuButton(
              key: _nextKey,
              label: 'Etkinliği şimdi yayınla',
              onPressed: () {},
            ),
          ],
        ),
      );

      // K-07: 73 + 34; düğme üstten 13.
      await tester.pumpApp(
        bar(),
        viewPadding: const EdgeInsets.only(bottom: 34),
      );
      expect(tester.getRect(_surface), const Rect.fromLTWH(0, 737, 390, 107));
      expect(tester.getRect(find.byKey(_nextKey)).top, 737 + 13);

      // Klavye 320: çubuk klavyenin üstünde, güvenli alan payı düşer.
      await tester.pumpApp(
        bar(),
        viewPadding: const EdgeInsets.only(bottom: 34),
        keyboardInset: 320,
      );
      expect(
        tester.getRect(_surface),
        const Rect.fromLTWH(0, 844 - 320 - 73, 390, 73),
      );

      await tester.pumpApp(bar(), size: const Size(320, 640), textScale: 1.6);
      expect(tester.getSize(find.byType(GuStickyCta)).width, 320);
      expect(tester.getSize(find.byKey(_backKey)).width, (320 - 32 - 12) / 2);
      expect(tester.getRect(find.byKey(_nextKey)).right, 320 - 16);
    });
  });
}
