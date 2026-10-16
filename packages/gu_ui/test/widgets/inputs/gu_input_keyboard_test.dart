// K-93 · GuInput klavye davranışı ve büyüyen çok satırlı alan (gerçek cihaz
// turu, kullanıcı kararı — madde 3 + 4).
//
// * Odaktaki alanın dışına dokunmak odağı bırakır, klavye kapanır (Flutter
//   mobil varsayılanı kapatmaz); kutu ve sondaki düğme `TextFieldTapRegion`
//   içindedir; çağıranın `TextFieldTapRegion` ile sardığı eş düğme klavyeyi
//   kapatmaz; çağıran `onTapOutside` verebilir.
// * `maxRows` → alan `rows` satırla başlar, `maxRows` satıra dek büyür, sonra
//   içinde kayar; `maxRows` yokken yükseklik değişmez (4 satır, min 88).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const Key _name = ValueKey<String>('name');
const Key _password = ValueKey<String>('password');
const Key _eye = ValueKey<String>('eye');
const Key _outside = ValueKey<String>('outside');
const Key _paired = ValueKey<String>('paired');
const Key _unpaired = ValueKey<String>('unpaired');
const Key _search = ValueKey<String>('search');
const Key _clear = ValueKey<String>('clear');
const Key _grow = ValueKey<String>('grow');
const Key _fixed = ValueKey<String>('fixed');

/// Metin alanının odak düğümü ([key] = `GuInput.actionKey`).
FocusNode _focusOf(WidgetTester tester, Key key) => tester
    .widget<EditableText>(
      find.descendant(of: find.byKey(key), matching: find.byType(EditableText)),
    )
    .focusNode;

/// [key] alanının `GuInput` kutusu (`.input`, ilk `AnimatedContainer`).
Finder _boxOf(Key key) => find
    .descendant(
      of: find.ancestor(of: find.byKey(key), matching: find.byType(GuInput)),
      matching: find.byType(AnimatedContainer),
    )
    .first;

/// Alanlar + altta boş zemin ([_outside]: metin alanı olmayan sayfa yüzeyi).
Widget _host(List<Widget> children) => Padding(
  padding: GuInsets.all16,
  child: Column(
    spacing: GuSpacing.s16,
    children: [
      ...children,
      const Expanded(
        child: ColoredBox(
          key: _outside,
          color: Colors.transparent,
          child: SizedBox.expand(),
        ),
      ),
    ],
  ),
);

void main() {
  group('K-93 · GuInput · klavye', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('${platform.name}: dışarı dokunma odağı bırakır; başka '
          'alana dokunma odağı taşır; göz düğmesi ve kutu dolgusu odağı '
          'korur', (tester) async {
        final log = <String>[];
        await tester.pumpApp(
          _host([
            const GuInput(
              label: 'Ad Soyad',
              icon: GuIcons.user,
              actionKey: _name,
            ),
            GuInput(
              label: 'Şifre',
              obscure: true,
              trailing: GuIconButton(
                key: _eye,
                icon: GuIcons.eye,
                size: GuIconButtonSize.sm,
                semanticLabel: 'Şifreyi göster',
                onPressed: () => log.add('eye'),
              ),
              actionKey: _password,
            ),
          ]),
          platform: platform,
        );

        await tester.tap(find.byKey(_name));
        await tester.pump();
        expect(_focusOf(tester, _name).hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);

        // Metin alanı olmayan yüzey → odak kalkar, klavye kapanır.
        await tester.tap(find.byKey(_outside));
        await tester.pump();
        expect(_focusOf(tester, _name).hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);

        // Başka bir alana geçiş: odak taşınır, klavye açık kalır.
        await tester.tap(find.byKey(_name));
        await tester.pump();
        await tester.tap(find.byKey(_password));
        await tester.pump();
        expect(_focusOf(tester, _name).hasFocus, isFalse);
        expect(_focusOf(tester, _password).hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);

        // Sondaki düğme alanın parçası: çalışır, odak kalır.
        await tester.tap(find.byKey(_eye));
        await tester.pump();
        expect(log, ['eye']);
        expect(_focusOf(tester, _password).hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);

        // Kutunun ikon / dolgu bandı (K-03) da alanın parçası.
        await tester.tap(find.byKey(_name));
        await tester.pump();
        final box = tester.getRect(_boxOf(_name));
        await tester.tapAt(box.centerLeft + const Offset(GuSpacing.s4, 0));
        await tester.pump();
        expect(_focusOf(tester, _name).hasFocus, isTrue);

        await tester.tap(find.byKey(_outside));
        await tester.pump();
        expect(_focusOf(tester, _name).hasFocus, isFalse);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('TextFieldTapRegion ile sarılan eş düğme odağı korur, '
        'sarılmayan düğme bırakır', (tester) async {
      final log = <String>[];
      await tester.pumpApp(
        _host([
          Row(
            spacing: GuSpacing.s8,
            children: [
              const Expanded(
                child: GuInput(multiline: true, rows: 1, actionKey: _name),
              ),
              TextFieldTapRegion(
                child: GuIconButton(
                  key: _paired,
                  icon: GuIcons.send,
                  semanticLabel: 'Gönder',
                  onPressed: () => log.add('send'),
                ),
              ),
              GuIconButton(
                key: _unpaired,
                icon: GuIcons.x,
                semanticLabel: 'Kapat',
                onPressed: () => log.add('close'),
              ),
            ],
          ),
        ]),
      );

      await tester.tap(find.byKey(_name));
      await tester.pump();
      await tester.tap(find.byKey(_paired));
      await tester.pump();
      expect(log, ['send']);
      expect(_focusOf(tester, _name).hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.byKey(_unpaired));
      await tester.pump();
      expect(log, ['send', 'close']);
      expect(_focusOf(tester, _name).hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('onTapOutside verilirse varsayılan yerine o çağrılır', (
      tester,
    ) async {
      var outside = 0;
      await tester.pumpApp(
        _host([GuInput(actionKey: _name, onTapOutside: (_) => outside++)]),
      );
      await tester.tap(find.byKey(_name));
      await tester.pump();
      await tester.tap(find.byKey(_outside));
      await tester.pump();
      expect(outside, 1);
      expect(_focusOf(tester, _name).hasFocus, isTrue);
    });

    testWidgets('GuSearchField: temizle düğmesi odağı korur', (tester) async {
      final query = ValueNotifier<String>('');
      addTearDown(query.dispose);
      await tester.pumpApp(
        _host([
          ValueListenableBuilder<String>(
            valueListenable: query,
            builder: (context, value, _) => GuSearchField(
              value: value,
              semanticLabel: 'Ara',
              clearSemanticLabel: 'Temizle',
              onChanged: (v) => query.value = v,
              onClear: () {},
              actionKey: _search,
              clearKey: _clear,
            ),
          ),
        ]),
      );
      await tester.enterText(find.byKey(_search), 'robotik');
      await tester.pump();
      expect(_focusOf(tester, _search).hasFocus, isTrue);

      await tester.tap(find.byKey(_clear));
      await tester.pump();
      expect(query.value, isEmpty);
      expect(_focusOf(tester, _search).hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.byKey(_outside));
      await tester.pump();
      expect(_focusOf(tester, _search).hasFocus, isFalse);
    });
  });

  group('K-93 · GuInput · büyüyen çok satır (maxRows)', () {
    for (final scale in [1.0, 1.6]) {
      testWidgets('ölçek $scale: 1 satırla başlar, 5 satıra dek büyür, sonra '
          'kayar; maxRows yokken yükseklik sabit', (tester) async {
        final grow = TextEditingController();
        final fixed = TextEditingController();
        addTearDown(grow.dispose);
        addTearDown(fixed.dispose);
        await tester.pumpApp(
          _host([
            GuInput(
              controller: grow,
              placeholder: 'Yorum yaz…',
              multiline: true,
              rows: 1,
              maxRows: GuSizes.commentMaxRows,
              actionKey: _grow,
            ),
            GuInput(
              controller: fixed,
              multiline: true,
              rows: 1,
              actionKey: _fixed,
            ),
          ]),
          textScale: scale,
        );
        final context = tester.element(find.byKey(_grow));
        // Alanın gerçek satır yüksekliği (yardımcıdan bağımsız).
        final line = tester
            .state<EditableTextState>(
              find.descendant(
                of: find.byKey(_grow),
                matching: find.byType(EditableText),
              ),
            )
            .renderEditable
            .preferredLineHeight;
        const chrome =
            (GuSizes.inputMultilinePaddingY + GuSizes.inputBorder) * 2;
        double height(Key key) => tester.getSize(_boxOf(key)).height;

        final field = tester.widget<TextField>(find.byKey(_grow));
        expect(field.minLines, 1);
        expect(field.maxLines, GuSizes.commentMaxRows);

        // Boş: tek satırlık kutu (min 48), yer tutucu tek satır.
        final single = GuInput.growingLineBoxHeight(context);
        expect(height(_grow), moreOrLessEquals(single, epsilon: 0.01));
        expect(
          single,
          moreOrLessEquals(
            line + chrome < GuSizes.inputHeight
                ? GuSizes.inputHeight
                : line + chrome,
            epsilon: 0.01,
          ),
        );
        final fixedEmpty = height(_fixed);
        expect(fixedEmpty, greaterThan(GuSizes.textareaMinHeight));

        Future<double> typeLines(int count) async {
          grow.text = List<String>.generate(count, (i) => 'satır $i').join(
            '\n',
          );
          fixed.text = grow.text;
          await tester.pump();
          return height(_grow);
        }

        expect(
          await typeLines(3),
          moreOrLessEquals(line * 3 + chrome, epsilon: 0.01),
        );
        final five = await typeLines(GuSizes.commentMaxRows);
        expect(five, moreOrLessEquals(line * 5 + chrome, epsilon: 0.01));
        // 6+ satır: yükseklik 5 satırda kalır, alan içinde kayar.
        expect(await typeLines(8), moreOrLessEquals(five, epsilon: 0.01));
        final scrollable = tester.state<ScrollableState>(
          find.descendant(
            of: find.byKey(_grow),
            matching: find.byType(Scrollable),
          ),
        );
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        // Sabit alan (FED-03 vb.) davranışı değişmedi: 4 satır, büyümez.
        expect(height(_fixed), moreOrLessEquals(fixedEmpty, epsilon: 0.01));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('K-93 · sheet footer / dialog eylemleri klavyeyi kapatmaz', () {
    const open = ValueKey<String>('open');
    const note = ValueKey<String>('note');
    const submit = ValueKey<String>('submit');
    const body = ValueKey<String>('body');

    Widget host(void Function(BuildContext) show) => Builder(
      builder: (context) => Center(
        child: GuButton(key: open, label: 'Aç', onPressed: () => show(context)),
      ),
    );

    Widget fields(VoidCallback onSubmit) => const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GuInput(label: 'Not', multiline: true, actionKey: note),
        Text('Açıklama', key: body),
      ],
    );

    Future<void> expectFooterKeepsFocus(
      WidgetTester tester,
      void Function(BuildContext, VoidCallback) show,
    ) async {
      var taps = 0;
      await tester.pumpApp(host((context) => show(context, () => taps++)));
      await tester.tap(find.byKey(open));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(note));
      await tester.pump();
      expect(_focusOf(tester, note).hasFocus, isTrue);

      // Gönder: dokunuş çalışır, alan odakta, klavye açık (SHT-05 hata).
      await tester.tap(find.byKey(submit));
      await tester.pump();
      expect(taps, 1);
      expect(_focusOf(tester, note).hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      // Gövdenin başka yerine dokunma odağı bırakır.
      await tester.tap(find.byKey(body));
      await tester.pump();
      expect(_focusOf(tester, note).hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
    }

    testWidgets('GuSheetFrame footer', (tester) async {
      await expectFooterKeepsFocus(
        tester,
        (context, onSubmit) => unawaited(
          showGuSheet<void>(
            context,
            builder: (_) => GuSheetFrame(
              title: 'Başvuru',
              closeSemanticLabel: 'Kapat',
              footer: [
                GuButton(key: submit, label: 'Gönder', onPressed: onSubmit),
              ],
              body: fields(onSubmit),
            ),
          ),
        ),
      );
    });

    testWidgets('GuDialogFrame eylemleri', (tester) async {
      await expectFooterKeepsFocus(
        tester,
        (context, onSubmit) => unawaited(
          showGuDialog<void>(
            context,
            builder: (_) => GuDialogFrame(
              title: 'Askıya al',
              actions: [
                GuButton(key: submit, label: 'Askıya al', onPressed: onSubmit),
              ],
              child: fields(onSubmit),
            ),
          ),
        ),
      );
    });
  });
}
