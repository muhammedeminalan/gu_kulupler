// T-13 · GuLinkText (widget-catalog ek-8): cümle içi bağlantılar — AUT-01
// yasal cümle (`screens-auth.js:78`), AUT-02 onay cümlesi (`:101`), SHT-05
// (`sheets.js:32`). Stil, dokunma (görsel kutu, 48 dp hedef, alt alta düşen
// bağlantılar), metin ölçeği, semantik.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

final Key _first = GuKey.action('AUT-02.legal');
final Key _second = GuKey.action('AUT-02.legalPrivacy');

const String _firstLabel = 'KVKK Aydınlatma Metni';
const String _secondLabel = 'Gizlilik Politikası';

void main() {
  late List<String> taps;

  setUp(() => taps = <String>[]);

  Widget sentence({
    double? width,
    EdgeInsets padding = EdgeInsets.zero,
    TextAlign textAlign = TextAlign.start,
  }) => Builder(
    builder: (context) => Center(
      child: SizedBox(
        width: width,
        child: GuLinkText(
          style: context.gu.text.bodyS.copyWith(
            color: context.gu.colors.textSecondary,
          ),
          textAlign: textAlign,
          padding: padding,
          spans: [
            GuLinkSpan.link(
              _firstLabel,
              actionKey: _first,
              onTap: () => taps.add('first'),
            ),
            const GuLinkSpan.text(' ve '),
            GuLinkSpan.link(
              _secondLabel,
              actionKey: _second,
              onTap: () => taps.add('second'),
            ),
            const GuLinkSpan.text(' metinlerini okudum, kabul ediyorum.'),
          ],
        ),
      ),
    ),
  );

  group('T-13 · GuLinkText', () {
    testWidgets('stil: cümle verilen stilde, bağlantılar aynı stilin '
        'brand.primaryText renkli hâli; hizalama ve dolgu uygulanır', (
      tester,
    ) async {
      await tester.pumpApp(
        sentence(padding: const EdgeInsets.all(8), textAlign: TextAlign.center),
      );
      final text = GuTypography.resolve(GuColors.light);
      final paragraph = tester.widget<Text>(
        find.descendant(
          of: find.byType(GuLinkText),
          matching: find.byWidgetPredicate(
            (w) => w is Text && w.textSpan != null,
          ),
        ),
      );
      expect(
        paragraph.style,
        text.bodyS.copyWith(color: GuColors.light.textSecondary),
      );
      expect(paragraph.textAlign, TextAlign.center);
      for (final label in [_firstLabel, _secondLabel]) {
        final link = tester.widget<Text>(find.text(label));
        expect(
          link.style,
          text.bodyS.copyWith(color: GuColors.light.brandPrimaryText),
        );
        expect(link.textScaler, TextScaler.noScaling);
      }
      final block = tester.getRect(find.byType(GuLinkText));
      final inner = tester.getRect(
        find.descendant(
          of: find.byType(GuLinkText),
          matching: find.byType(Padding),
        ),
      );
      expect(inner, block);
      expect(
        tester
            .widget<Padding>(
              find.descendant(
                of: find.byType(GuLinkText),
                matching: find.byType(Padding),
              ),
            )
            .padding,
        const EdgeInsets.all(8),
      );
    });

    testWidgets('bağlantıya dokunma kendi eylemini çağırır; düz metne dokunma '
        'etkisizdir', (tester) async {
      await tester.pumpApp(sentence(width: 360));
      await tester.tap(find.byKey(_first));
      await tester.tap(find.byKey(_second));
      expect(taps, ['first', 'second']);

      // Cümlenin sonu (bağlantılardan uzak): hiçbir eylem çağrılmaz.
      taps.clear();
      final block = tester.getRect(find.byType(GuLinkText));
      await tester.tapAt(block.bottomRight - const Offset(4, 4));
      expect(taps, isEmpty);
    });

    testWidgets('dokunma hedefi görsel kutudan büyüktür (K-03): kutunun hemen '
        'dışı — dolgu dahil — bağlantıyı açar', (tester) async {
      await tester.pumpApp(
        sentence(width: 360, padding: const EdgeInsets.symmetric(vertical: 24)),
      );
      final first = tester.getRect(find.byKey(_first));
      expect(first.height, lessThan(GuSizes.tapTargetAndroid));
      final reach = (GuSizes.tapTargetAndroid - first.height) / 2;
      await tester.tapAt(first.topCenter - Offset(0, reach - 1));
      await tester.tapAt(first.bottomCenter + Offset(0, reach - 1));
      expect(taps, ['first', 'first']);

      // Hedefin dışı (blok içinde, kutudan `reach`'ten uzak) etkisizdir.
      taps.clear();
      await tester.tapAt(first.topCenter - Offset(0, reach + 1));
      expect(taps, isEmpty);
    });

    testWidgets('alt alta düşen bağlantılar birbirinin dokunuşunu çalmaz: '
        'dokunuş en yakın bağlantıya gider (dar ekran)', (tester) async {
      // Dar sütunda ikinci bağlantı alt satıra, birincinin altına düşer.
      await tester.pumpApp(sentence(width: 200));
      final first = tester.getRect(find.byKey(_first));
      final second = tester.getRect(find.byKey(_second));
      expect(second.top, greaterThanOrEqualTo(first.bottom - 0.5));
      expect(second.left, lessThan(first.right));

      await tester.tapAt(second.center);
      await tester.tapAt(first.center);
      // İki kutunun arasında, ikinciye daha yakın nokta.
      await tester.tapAt(Offset(second.left + 4, second.top + 1));
      expect(taps, ['second', 'first', 'second']);
    });

    testWidgets('metin ölçeği: bağlantı çevresindeki metinle aynı boyda '
        '(çift ölçek yok) ve ölçekli kutusundan dokunulur', (tester) async {
      await tester.pumpApp(sentence(width: 360));
      final base = tester.getRect(find.byKey(_first));

      await tester.pumpApp(sentence(width: 360), textScale: 1.6);
      final scaled = tester.getRect(find.byKey(_first));
      expect(scaled.height, moreOrLessEquals(base.height * 1.6, epsilon: 0.5));
      expect(scaled.width, moreOrLessEquals(base.width * 1.6, epsilon: 1));

      await tester.tapAt(scaled.centerRight - const Offset(2, 0));
      expect(taps, ['first']);
    });

    testWidgets('iOS: en küçük hedef 44 pt', (tester) async {
      await tester.pumpApp(
        sentence(width: 360, padding: const EdgeInsets.symmetric(vertical: 24)),
        platform: TargetPlatform.iOS,
      );
      final first = tester.getRect(find.byKey(_first));
      final reach = (GuSizes.tapTargetIos - first.height) / 2;
      await tester.tapAt(first.bottomCenter + Offset(0, reach - 1));
      expect(taps, ['first']);
      await tester.tapAt(first.bottomCenter + Offset(0, reach + 1));
      expect(taps, ['first']);
    });

    testWidgets('semantik: her bağlantı `link` + dokunma eylemi; eylem '
        'semantikten de çağrılır', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(sentence(width: 360));
      for (final (key, label) in [
        (_first, _firstLabel),
        (_second, _secondLabel),
      ]) {
        expect(
          tester.getSemantics(find.byKey(key)),
          matchesSemantics(label: label, isLink: true, hasTapAction: true),
        );
      }
      tester.semantics.tap(find.semantics.byLabel(_secondLabel));
      expect(taps, ['second']);
      handle.dispose();
    });

    testWidgets('parça listesi değişince (dil değişimi) yeni bağlantılar '
        'çalışır', (tester) async {
      Widget host(List<GuLinkSpan> spans) => Builder(
        builder: (context) => Center(
          child: GuLinkText(style: context.gu.text.caption, spans: spans),
        ),
      );
      await tester.pumpApp(
        host([
          const GuLinkSpan.text('Devam ederek '),
          GuLinkSpan.link(
            'Koşullar',
            actionKey: _first,
            onTap: () => taps.add('tr'),
          ),
        ]),
      );
      await tester.tap(find.byKey(_first));
      await tester.pumpApp(
        host([
          GuLinkSpan.link(
            'Terms',
            actionKey: _first,
            onTap: () => taps.add('en'),
          ),
          const GuLinkSpan.text(' apply.'),
        ]),
      );
      await tester.tap(find.byKey(_first));
      expect(taps, ['tr', 'en']);
    });

    test('GuLinkSpan: düz metin bağlantı değildir', () {
      const text = GuLinkSpan.text('ve');
      final link = GuLinkSpan.link('KVKK', actionKey: _first, onTap: () {});
      expect(text.isLink, isFalse);
      expect(text.actionKey, isNull);
      expect(link.isLink, isTrue);
      expect(link.actionKey, _first);
    });
  });
}
