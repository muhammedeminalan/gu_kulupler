// T-05 · GuPickerField (widget-catalog #5; A.2 #5; K-03, K-38, CD-82,
// CD-106d, CD-111).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const Key _filled = ValueKey<String>('filled');
const Key _empty = ValueKey<String>('empty');
const Key _off = ValueKey<String>('off');

Finder _in(Key key, Type type) =>
    find.descendant(of: find.byKey(key), matching: find.byType(type));

BoxDecoration _decoration(WidgetTester tester, Key key) =>
    tester.widget<Container>(_in(key, Container)).decoration! as BoxDecoration;

void main() {
  group('T-05 · GuPickerField', () {
    testWidgets('T-05 · GuPickerField · default / yer tutucu / hata / devre '
        'dışı token değerleriyle; dokunma → onTap, devre dışı → çağrılmaz; '
        'Semantics; dokunma hedefi ≥ 48 dp', (tester) async {
      final handle = tester.ensureSemantics();
      const c = GuColors.light;
      final text = GuTypography.resolve(c);
      final log = <String>[];
      final departmentKey = GuKey.action('PRF-02.department');
      final yearKey = GuKey.action('PRF-02.year');
      final categoryKey = GuKey.action('MGT-09.category');

      await tester.pumpApp(
        Padding(
          padding: GuInsets.all16,
          child: Column(
            spacing: GuSpacing.s16,
            children: [
              GuPickerField(
                key: _filled,
                label: 'Bölüm',
                icon: GuIcons.graduationCap,
                value: 'Bilgisayar Mühendisliği',
                help: 'Profilinde görünür',
                semanticHint: 'Seçim listesini açar',
                onTap: () => log.add('department'),
                actionKey: departmentKey,
              ),
              GuPickerField(
                key: _empty,
                label: 'Sınıf',
                placeholder: 'Seç',
                help: 'Görünmez',
                errorText: 'Bu alan zorunlu',
                semanticLabel: 'Sınıf seç',
                onTap: () => log.add('year'),
                actionKey: yearKey,
              ),
              GuPickerField(
                key: _off,
                label: 'Kategori',
                value: 'Spor',
                disabled: true,
                onTap: () => log.add('category'),
                actionKey: categoryKey,
              ),
            ],
          ),
        ),
      );

      // Default (css:173): 48 px, radius sm, bg.surfaceMuted, saydam
      // kenarlık; ikon 20 + chevron-down 20 text.muted; değer `input` stili.
      expect(tester.getSize(_in(_filled, Container)).height, 48);
      final box = _decoration(tester, _filled);
      expect(
        (box.color, box.borderRadius, (box.border! as Border).top),
        (
          c.bgSurfaceMuted,
          GuRadius.borderSm,
          const BorderSide(color: Colors.transparent),
        ),
      );
      expect(
        tester
            .widgetList<GuIcon>(_in(_filled, GuIcon))
            .map((i) => (i.icon, i.size, i.color)),
        [
          (GuIcons.graduationCap, 20, c.textMuted),
          (GuIcons.chevronDown, 20, c.textMuted),
        ],
      );
      final value = tester.widget<Text>(find.text('Bilgisayar Mühendisliği'));
      expect(
        (value.style, value.maxLines, value.overflow),
        (
          text.input,
          1,
          TextOverflow.ellipsis,
        ),
      );
      expect(tester.widget<Text>(find.text('Bölüm')).style, text.fieldLabel);
      expect(
        tester.widget<Text>(find.text('Profilinde görünür')).style,
        text.fieldHelp,
      );

      // Yer tutucu text.muted (css:174 `.ph`); hata kenarlığı + hata satırı.
      expect(
        tester.widget<Text>(find.text('Seç')).style,
        text.input.copyWith(color: c.textMuted),
      );
      expect(
        (_decoration(tester, _empty).border! as Border).top.color,
        c.stateDanger,
      );
      expect(find.text('Görünmez'), findsNothing);
      expect(
        tester.widget<Text>(find.text('Bu alan zorunlu')).style,
        text.fieldHelp.copyWith(color: c.stateDanger),
      );
      expect(
        tester.widget<GuIcon>(_in(_empty, GuIcon).last).icon,
        GuIcons.triangleAlert,
      );

      // Devre dışı (K-38): opaklık .6; etkin olanlarda 1.
      expect(
        [
          _filled,
          _empty,
          _off,
        ].map((k) => tester.widget<Opacity>(_in(k, Opacity)).opacity),
        [1, 1, GuOpacity.inputDisabled],
      );

      // Dokunma → onTap; devre dışı → çağrılmaz.
      await tester.tap(find.byKey(departmentKey));
      await tester.tap(find.byKey(yearKey));
      await tester.tap(find.byKey(categoryKey));
      expect(log, ['department', 'year']);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(
        tester.getSemantics(find.byKey(departmentKey)),
        isSemantics(
          label: 'Bölüm',
          value: 'Bilgisayar Mühendisliği',
          hint: 'Seçim listesini açar',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(yearKey)),
        isSemantics(label: 'Sınıf seç', value: 'Seç', isButton: true),
      );
      expect(
        tester.getSemantics(find.byKey(categoryKey)),
        isSemantics(
          label: 'Kategori',
          value: 'Spor',
          isButton: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('T-05 · GuPickerField · 320 dp × 1.6 ölçek + uzun metin → '
        'taşma yok, değer tek satır', (tester) async {
      const long =
          'Gümüşhane Üniversitesi Mühendislik ve Doğa Bilimleri Fakültesi '
          'Bilgisayar Mühendisliği Bölümü';
      await tester.pumpApp(
        SingleChildScrollView(
          padding: GuInsets.all16,
          child: Column(
            spacing: GuSpacing.s16,
            children: [
              GuPickerField(
                key: _filled,
                label: long,
                icon: GuIcons.graduationCap,
                value: long,
                help: long,
                onTap: () {},
              ),
              GuPickerField(
                label: long,
                placeholder: long,
                errorText: long,
                onTap: () {},
              ),
            ],
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      // css:173: kutu `max(48, satır + kenarlık)`; 15 × 1.6 × 1.47 + 2 < 48.
      expect(tester.getSize(_in(_filled, Container)).height, 48);
    });
  });
}
