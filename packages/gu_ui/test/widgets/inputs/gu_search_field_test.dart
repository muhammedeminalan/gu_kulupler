// T-05 · GuSearchField (widget-catalog ek-1; G13; K-03, CD-111).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('T-05 · GuSearchField', () {
    testWidgets('T-05 · GuSearchField · GuInput sarmalayıcısı (ikon search, '
        'eylem search, kompakt 44); yazma → onChanged, Enter → onSubmitted; '
        'temizle → alan boşalır + onChanged + onClear; dış değer eşitlenir; '
        'Semantics; dokunma hedefi', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      final query = ValueNotifier<String>('');
      addTearDown(query.dispose);
      final inputKey = GuKey.action('CLB-02.input');
      final clearKey = GuKey.action('CLB-02.clear');
      final plainKey = GuKey.action('ADM-02.search');

      await tester.pumpApp(
        Padding(
          padding: GuInsets.all16,
          child: Column(
            spacing: GuSpacing.s16,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: query,
                builder: (context, value, _) => GuSearchField(
                  value: value,
                  compact: true,
                  placeholder: 'Kulüp veya etkinlik ara',
                  semanticLabel: 'Ara',
                  clearSemanticLabel: 'Temizle',
                  onChanged: (v) {
                    log.add('changed:$v');
                    query.value = v;
                  },
                  onClear: () => log.add('clear'),
                  onSubmitted: () => log.add('submit'),
                  actionKey: inputKey,
                  clearKey: clearKey,
                ),
              ),
              // `Input icon="search"` (ADM-02): temizle düğmesi yok.
              GuSearchField(
                value: 'robotik',
                semanticLabel: 'Ara',
                actionKey: plainKey,
              ),
            ],
          ),
        ),
      );

      // Sarmalayıcı: ikon search 20 text.muted, eylem search, 44 / 48 px.
      final inputs = tester.widgetList<GuInput>(find.byType(GuInput)).toList();
      expect(inputs.map((i) => (i.icon, i.textInputAction, i.compact)), [
        (GuIcons.search, TextInputAction.search, true),
        (GuIcons.search, TextInputAction.search, false),
      ]);
      final boxes = find.byType(AnimatedContainer);
      expect(tester.getSize(boxes.at(0)).height, 44);
      expect(tester.getSize(boxes.at(1)).height, 48);
      expect(
        tester.getSemantics(find.byKey(inputKey)),
        // Boşken yer tutucu etikete eklenir (Flutter `hintText` davranışı).
        isSemantics(
          label: 'Ara\nKulüp veya etkinlik ara',
          isTextField: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(plainKey)),
        isSemantics(label: 'Ara', value: 'robotik', isTextField: true),
      );
      // Boşken ve onClear yokken temizle düğmesi yok.
      expect(find.byType(GuIconButton), findsNothing);

      // Yazma → onChanged; düğme görünür (x, sm 40) ve hedefi ≥ 48 dp.
      await tester.enterText(find.byKey(inputKey), 'hackathon');
      await tester.pump();
      expect(log, ['changed:hackathon']);
      final clear = tester.widget<GuIconButton>(find.byKey(clearKey));
      expect(
        (clear.icon, clear.size, clear.semanticLabel),
        (
          GuIcons.x,
          GuIconButtonSize.sm,
          'Temizle',
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      // Enter → onSubmitted.
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(log.last, 'submit');
      log.clear();

      // Temizle: alan boşalır, onChanged('') + onClear; düğme kaybolur.
      await tester.tap(find.byKey(clearKey));
      await tester.pump();
      expect(log, ['changed:', 'clear']);
      expect(
        tester.widget<TextField>(find.byKey(inputKey)).controller!.text,
        isEmpty,
      );
      expect(find.byKey(clearKey), findsNothing);

      // Dış değer değişince alan eşitlenir (imleç sonda).
      query.value = 'satranç';
      await tester.pump();
      final controller = tester
          .widget<TextField>(find.byKey(inputKey))
          .controller!;
      expect(
        (controller.text, controller.selection.baseOffset),
        (
          'satranç',
          7,
        ),
      );
      expect(find.byKey(clearKey), findsOneWidget);
      handle.dispose();
    });

    testWidgets('T-05 · GuSearchField · 320 dp × 1.6 ölçek + uzun metin → '
        'taşma yok', (tester) async {
      const long =
          'Gümüşhane Üniversitesi Doğa Sporları ve Dağcılık Kulübü etkinlikleri';
      await tester.pumpApp(
        Padding(
          padding: GuInsets.all16,
          child: Column(
            spacing: GuSpacing.s16,
            children: [
              GuSearchField(
                value: long,
                compact: true,
                clearSemanticLabel: 'Temizle',
                onClear: () {},
              ),
              const GuSearchField(value: '', placeholder: long),
            ],
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(GuIconButton), findsOneWidget);
    });
  });
}
