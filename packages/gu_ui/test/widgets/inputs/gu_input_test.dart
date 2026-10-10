// T-05 · GuInput + GuField (widget-catalog #4; A.2 #4; K-03, CD-111,
// CD-118, CD-121(7)).
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const Key _plain = ValueKey<String>('plain');
const Key _error = ValueKey<String>('error');
const Key _locked = ValueKey<String>('locked');
const Key _disabled = ValueKey<String>('disabled');
const Key _multi = ValueKey<String>('multi');
const Key _compact = ValueKey<String>('compact');

Finder _in(Key key, Type type) =>
    find.descendant(of: find.byKey(key), matching: find.byType(type));

/// `.input` kutusu (ilk `AnimatedContainer`; sondaki düğmeninki sonra gelir).
Finder _boxOf(Key key) => _in(key, AnimatedContainer).first;

BoxDecoration _decoration(WidgetTester tester, Key key) =>
    tester.widget<AnimatedContainer>(_boxOf(key)).decoration! as BoxDecoration;

(Color?, Color) _paint(WidgetTester tester, Key key) {
  final decoration = _decoration(tester, key);
  return (decoration.color, (decoration.border! as Border).top.color);
}

TextField _field(WidgetTester tester, Key key) =>
    tester.widget<TextField>(_in(key, TextField));

Widget _host(List<Widget> children) => SingleChildScrollView(
  padding: GuInsets.all16,
  child: Column(spacing: GuSpacing.s16, children: children),
);

void main() {
  group('T-05 · GuInput', () {
    testWidgets('T-05 · GuInput · default / odak / hata / salt-okunur / '
        'devre dışı / çok satır / kompakt token değerleriyle; sayaç eşiği', (
      tester,
    ) async {
      const c = GuColors.light;
      final text = GuTypography.resolve(c);
      final counter = TextEditingController(text: '1234567');
      addTearDown(counter.dispose);

      await tester.pumpApp(
        _host([
          const GuInput(
            key: _plain,
            label: 'E-posta',
            icon: GuIcons.mail,
            placeholder: 'ad.soyad@ogr.gumushane.edu.tr',
            help: 'Okul e-posta adresinle kayıt ol',
          ),
          const GuInput(
            key: _error,
            label: 'E-posta',
            help: 'Görünmez',
            errorText: 'Yalnızca üniversite e-postası kullanılabilir',
          ),
          const GuInput(key: _locked, locked: true),
          const GuInput(key: _disabled, disabled: true),
          GuInput(
            key: _multi,
            label: 'Not',
            controller: counter,
            multiline: true,
            rows: 1,
            maxLength: 10,
            showCounter: true,
          ),
          const GuInput(key: _compact, compact: true),
        ]),
      );

      // Default (css:163): 48 px, radius sm, bg.surfaceMuted, saydam kenarlık.
      expect(tester.getSize(_boxOf(_plain)).height, 48);
      expect(_decoration(tester, _plain).borderRadius, GuRadius.borderSm);
      expect((_decoration(tester, _plain).border! as Border).top.width, 1);
      expect(_paint(tester, _plain), (c.bgSurfaceMuted, Colors.transparent));
      final icon = tester.widget<GuIcon>(_in(_plain, GuIcon));
      expect(
        (icon.icon, icon.size, icon.color),
        (
          GuIcons.mail,
          20,
          c.textMuted,
        ),
      );
      // Alan çerçevesi: etiket → kutu 6 px, etiket / yardım stilleri.
      expect(
        tester.widget<Text>(find.text('E-posta').first).style,
        text.fieldLabel,
      );
      expect(
        tester.getTopLeft(_boxOf(_plain)).dy -
            tester.getBottomLeft(find.text('E-posta').first).dy,
        moreOrLessEquals(6),
      );
      expect(
        tester.widget<Text>(find.text('Okul e-posta adresinle kayıt ol')).style,
        text.fieldHelp,
      );
      // Metin `input` stili, yer tutucu text.muted, imleç temadan (CD-121).
      final plain = _field(tester, _plain);
      expect(plain.style, text.input);
      expect(
        plain.decoration!.hintStyle,
        text.input.copyWith(color: c.textMuted),
      );
      expect(plain.cursorColor, isNull);
      expect(
        tester.widget<EditableText>(_in(_plain, EditableText)).cursorColor,
        c.textPrimary,
      );

      // Odak (css:164): kenarlık brand.primaryText + zemin bg.surface;
      // ikona dokunmak da odağı verir (K-03).
      await tester.tap(_in(_plain, GuIcon));
      await tester.pumpAndSettle();
      expect(_paint(tester, _plain), (c.bgSurface, c.brandPrimaryText));
      expect(tester.testTextInput.isVisible, isTrue);

      // Hata (css:165, ui.js:33): kenarlık state.danger; yardım yerine hata
      // satırı (triangle-alert 14 + state.danger).
      expect(_paint(tester, _error).$2, c.stateDanger);
      expect(find.text('Görünmez'), findsNothing);
      final alert = tester.widget<GuIcon>(_in(_error, GuIcon));
      expect(
        (alert.icon, alert.size, alert.color),
        (
          GuIcons.triangleAlert,
          14,
          c.stateDanger,
        ),
      );
      expect(
        tester
            .widget<Text>(
              find.text('Yalnızca üniversite e-postası kullanılabilir'),
            )
            .style,
        text.fieldHelp.copyWith(color: c.stateDanger),
      );
      // Hata, odak kenarlığını ezer; zemin odaktan gelir.
      await tester.tap(_in(_error, TextField));
      await tester.pumpAndSettle();
      expect(_paint(tester, _error), (c.bgSurface, c.stateDanger));

      // Kilitli (css:165, ui.js:30): saydam zemin + border.default, kilit 18,
      // odak görünümü değiştirmez.
      final lock = tester.widget<GuIcon>(_in(_locked, GuIcon));
      expect(
        (lock.icon, lock.size, lock.color),
        (
          GuIcons.lock,
          18,
          c.textMuted,
        ),
      );
      expect(_field(tester, _locked).readOnly, isTrue);
      await tester.tap(_in(_locked, TextField));
      await tester.pumpAndSettle();
      expect(_paint(tester, _locked), (null, c.borderDefault));

      // Devre dışı (css:165): opaklık .6.
      expect(_field(tester, _disabled).enabled, isFalse);
      expect(
        tester.widget<Opacity>(_in(_disabled, Opacity)).opacity,
        GuOpacity.inputDisabled,
      );

      // Çok satır (css:169): dolgu 12 + en az 4 satır (rows 1 de 88 px'e
      // tamamlanır) + kenarlık; kompakt 44.
      expect(
        tester.getSize(_boxOf(_multi)).height,
        moreOrLessEquals(88 + 2 * 12 + 2, epsilon: 0.25),
      );
      expect(_field(tester, _multi).maxLines, 4);
      expect(tester.getSize(_boxOf(_compact)).height, 44);

      // Sayaç (ui.js:23, css:172): floor(10 × 0.8) = 8'den önce yok; 8'de
      // text.muted + tabular; sınır aşılınca state.danger; yazma 10 + 20'de
      // durur.
      expect(find.text('7/10'), findsNothing);
      await tester.enterText(_in(_multi, TextField), '12345678');
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('8/10')).style,
        text.fieldHelp.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
      await tester.enterText(_in(_multi, TextField), 'x' * 40);
      await tester.pump();
      expect(counter.text.length, 30);
      expect(
        tester.widget<Text>(find.text('30/10')).style!.color,
        c.stateDanger,
      );
    });

    testWidgets('T-05 · GuInput · yazma → onChanged, Enter → onSubmitted; '
        'devre dışı / salt-okunur → çağrılmaz; denetleyici ve odak düğümü '
        'değişimi; Semantics; dokunma hedefi ≥ 48 dp', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      final controller = TextEditingController(text: 'Demo1234!');
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      final emailKey = GuKey.action('AUT-01.email');
      final passwordKey = GuKey.action('AUT-01.password');
      final noteKey = GuKey.action('CLB-05.note');
      final lockedKey = GuKey.action('PRF-02.email');
      final offKey = GuKey.action('MGT-09.name');

      final external = ValueNotifier<bool>(true);
      addTearDown(external.dispose);

      Widget build({required bool external}) => _host([
        GuInput(
          label: 'E-posta',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onChanged: (v) => log.add('email:$v'),
          onSubmitted: () => log.add('email:enter'),
          actionKey: emailKey,
        ),
        GuInput(
          label: 'Şifre',
          controller: external ? controller : null,
          focusNode: external ? focusNode : null,
          obscure: true,
          errorText: 'Şifre hatalı',
          trailing: GuIconButton(
            icon: GuIcons.eye,
            size: GuIconButtonSize.sm,
            semanticLabel: 'Şifreyi göster',
            onPressed: () => log.add('eye'),
          ),
          actionKey: passwordKey,
        ),
        GuInput(
          semanticLabel: 'Başvuru notu',
          multiline: true,
          onSubmitted: () => log.add('note:enter'),
          actionKey: noteKey,
        ),
        GuInput(
          label: 'Kilitli',
          locked: true,
          onChanged: (v) => log.add('locked:$v'),
          actionKey: lockedKey,
        ),
        GuInput(
          label: 'Kulüp adı',
          disabled: true,
          onChanged: (v) => log.add('off:$v'),
          actionKey: offKey,
        ),
        const GuField(label: 'Kontenjan', child: SizedBox.shrink()),
      ]);

      await tester.pumpApp(
        ValueListenableBuilder<bool>(
          valueListenable: external,
          builder: (context, value, _) => build(external: value),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      // Semantics: metin alanı + etiket; görünür etiket ikinci kez okunmaz;
      // şifre gizli + geçersiz; kilitli salt-okunur; devre dışı.
      expect(
        tester.getSemantics(find.byKey(emailKey)),
        isSemantics(
          label: 'E-posta',
          isTextField: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel('E-posta'), findsOneWidget);
      final password = tester.getSemantics(find.byKey(passwordKey));
      expect(
        password,
        isSemantics(label: 'Şifre', isTextField: true, isObscured: true),
      );
      expect(
        password.getSemanticsData().validationResult,
        SemanticsValidationResult.invalid,
      );
      expect(
        tester.getSemantics(find.byKey(noteKey)),
        isSemantics(
          label: 'Başvuru notu',
          isTextField: true,
          isMultiline: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(lockedKey)),
        isSemantics(label: 'Kilitli', isTextField: true, isReadOnly: true),
      );
      expect(
        tester.getSemantics(find.byKey(offKey)),
        isSemantics(label: 'Kulüp adı', isTextField: true, isEnabled: false),
      );
      // `GuField` tek başına: etiket semantikte kalır.
      expect(find.bySemanticsLabel('Kontenjan'), findsOneWidget);

      // Yazma ve Enter.
      await tester.enterText(find.byKey(emailKey), 'ayse@gmail.com');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(log, ['email:ayse@gmail.com', 'email:enter']);
      log.clear();
      // `next` odağı sıradaki alana (dış odak düğümü, CD-118) taşır.
      expect(focusNode.hasFocus, isTrue);
      focusNode.unfocus();
      await tester.pump();

      // Sondaki düğme alanla çakışmaz: kutunun odak dokunuşunu tetiklemez.
      await tester.tap(find.bySemanticsLabel('Şifreyi göster'));
      await tester.pump();
      expect(log, ['eye']);
      expect(focusNode.hasFocus, isFalse);
      await tester.tap(find.byKey(passwordKey));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
      expect(
        tester.widget<TextField>(find.byKey(passwordKey)).controller,
        controller,
      );
      log.clear();

      // Çok satırda Enter gönderim değildir; kilitli ve devre dışı alan
      // yazılamaz, dokunma odağı / klavyeyi açmaz.
      await tester.showKeyboard(find.byKey(noteKey));
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.tap(find.byKey(offKey), warnIfMissed: false);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byKey(offKey)).focusNode!.hasFocus,
        isFalse,
      );
      expect(log, isEmpty);

      // Denetleyici / odak düğümü yerinde içtekine geçer; alan çalışmayı
      // sürdürür ve odak görünümü yeni düğümü izler.
      external.value = false;
      await tester.pump();
      final swapped = tester.widget<TextField>(find.byKey(passwordKey));
      expect(swapped.controller, isNot(controller));
      expect(swapped.controller!.text, isEmpty);
      await tester.tap(find.byKey(passwordKey));
      await tester.pumpAndSettle();
      expect(swapped.focusNode!.hasFocus, isTrue);
      expect(
        (tester
                    .widget<AnimatedContainer>(
                      find
                          .ancestor(
                            of: find.byKey(passwordKey),
                            matching: find.byType(AnimatedContainer),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration)
            .color,
        GuColors.light.bgSurface,
      );
      handle.dispose();
    });

    testWidgets('T-05 · GuInput · 320 dp × 1.6 ölçek + uzun metin + klavye '
        'açık → taşma yok', (tester) async {
      const long =
          'Gümüşhane Üniversitesi Doğa Sporları ve Dağcılık Kulübü başvuru '
          'formu açıklama alanı';
      final controller = TextEditingController(text: long);
      final note = TextEditingController(text: '$long $long');
      addTearDown(controller.dispose);
      addTearDown(note.dispose);
      await tester.pumpApp(
        _host([
          GuInput(
            key: _plain,
            label: long,
            icon: GuIcons.mail,
            controller: controller,
            help: long,
            trailing: const GuIconButton(
              icon: GuIcons.eye,
              size: GuIconButtonSize.sm,
              semanticLabel: 'Şifreyi göster',
            ),
          ),
          const GuInput(
            label: long,
            placeholder: long,
            errorText: long,
            locked: true,
          ),
          GuInput(
            label: long,
            controller: note,
            multiline: true,
            maxLength: 20,
            showCounter: true,
            errorText: long,
          ),
        ]),
        size: const Size(320, 640),
        textScale: 1.6,
        keyboardInset: 320,
      );
      expect(tester.takeException(), isNull);
      // css:163: kutu `max(48, satır + kenarlık)`; 15 × 1.6 × 1.47 + 2 < 48.
      expect(tester.getSize(_boxOf(_plain)).height, 48);
      expect(find.text('${note.text.length}/20'), findsOneWidget);
    });
  });
}
