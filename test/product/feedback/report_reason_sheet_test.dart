// SHT-10 · Şikayet nedeni — altı neden + "Diğer" açıklaması
// (`ReportReasonSheet`). İçerik, anahtarlar (`SHT-10.reason.<neden>`,
// `.note`, `.submit`, `.close`, `.scrim`), doğrulama (neden / açıklama
// zorunlu), sonuç (`pop(ReportReasonResult)`), `onSubmit` (meşgul, açık
// kalma), kirli kapanış (DLG-25), açıklama sınırı, cihaz matrisi, açık + koyu
// golden. Referans: design/reference-shots/sheets/SHT-10__light.webp,
// __dark.webp; prototip sheets.js:49–52.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/unsaved_changes_dialog.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_feedback_service.dart';
import '../../helpers/action_inventory.dart';
import '../../helpers/design_files.dart';
import '../../helpers/device_matrix.dart';
import '../../helpers/golden_helper.dart';
import '../../helpers/overflow_detector.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_l10n.dart';
import 'sheet_test_support.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

const ReportTarget _club = (
  type: ReportTargetType.club,
  id: 'c01',
  clubId: 'c01',
);
const ReportTarget _post = (
  type: ReportTargetType.post,
  id: 'p01',
  clubId: 'c01',
);

Key _key(String action) => FeedbackKeys.of(SheetId.sht10.designId, action);

SheetHarness<ReportReasonResult> _harness({
  ReportTarget target = _club,
  Future<ReportSubmitOutcome> Function(ReportReasonResult result)? onSubmit,
}) => SheetHarness<ReportReasonResult>(
  SheetId.sht10,
  (_) => ReportReasonSheet(target: target, onSubmit: onSubmit),
);

/// `pumpApp`'in kaydettiği sahte geri bildirim servisi (DLG-25 buradan
/// sorulur).
FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

Future<void> _select(WidgetTester tester, ReportReason reason) async {
  await tester.tap(find.byKey(ReportReasonSheet.reasonKey(reason)));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.byKey(ReportReasonSheet.submitKey));
  await tester.pumpAndSettle();
}

Future<void> _enterNote(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(ReportReasonSheet.noteKey), text);
  await tester.pumpAndSettle();
}

List<GuOptionRow> _rows(WidgetTester tester) =>
    tester.widgetList<GuOptionRow>(find.byType(GuOptionRow)).toList();

ReportReason? _selected(WidgetTester tester) {
  final rows = _rows(tester);
  final index = rows.indexWhere((row) => row.selected);
  expect(rows.where((row) => row.selected).length, lessThanOrEqualTo(1));
  return index < 0 ? null : ReportReason.values[index];
}

GuButton _submitButton(WidgetTester tester) =>
    tester.widget<GuButton>(find.byKey(ReportReasonSheet.submitKey));

String _noteText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(ReportReasonSheet.noteKey))
    .controller!
    .text;

void main() {
  group('SHT-10 · Şikayet nedeni · sözleşme', () {
    test('anahtarlar prototipteki aksiyon adlarıdır', () {
      expect(
        [
          for (final reason in ReportReason.values)
            ReportReasonSheet.reasonKey(reason),
        ],
        [
          GuKey.action('SHT-10.reason.spam'),
          GuKey.action('SHT-10.reason.harassment'),
          GuKey.action('SHT-10.reason.inappropriate'),
          GuKey.action('SHT-10.reason.misinformation'),
          GuKey.action('SHT-10.reason.offtopic'),
          GuKey.action('SHT-10.reason.other'),
        ],
      );
      expect(ReportReasonSheet.noteKey, GuKey.action('SHT-10.note'));
      expect(ReportReasonSheet.submitKey, GuKey.action('SHT-10.submit'));
    });

    test('neden adları `reportReason.*` anahtarlarıdır — TR ve EN', () {
      for (final locale in [_tr, _en]) {
        final l10n = lookupAppLocalizations(locale);
        expect(
          [
            for (final reason in ReportReason.values)
              ReportReasonSheet.reasonLabel(l10n, reason),
          ],
          [
            l10n.reportReasonSpam,
            l10n.reportReasonHarassment,
            l10n.reportReasonInappropriate,
            l10n.reportReasonMisinformation,
            l10n.reportReasonOfftopic,
            l10n.reportReasonOther,
          ],
        );
      }
    });

    test('sonuç değer nesnesidir: hedef + neden + açıklama', () {
      const result = ReportReasonResult(
        target: _club,
        reason: ReportReason.spam,
      );
      expect(result.note, '');
      expect(
        result,
        const ReportReasonResult(target: _club, reason: ReportReason.spam),
      );
      expect(
        result,
        isNot(
          const ReportReasonResult(target: _post, reason: ReportReason.spam),
        ),
      );
      expect(
        result,
        isNot(
          const ReportReasonResult(target: _club, reason: ReportReason.other),
        ),
      );
      expect(
        result,
        isNot(
          const ReportReasonResult(
            target: _club,
            reason: ReportReason.spam,
            note: 'x',
          ),
        ),
      );
      expect(result.props, [_club, ReportReason.spam, '']);
    });

    test('`/// Design: SHT-10` izi ReportReasonSheet sınıfındadır', () {
      final source = readText(
        'lib/product/feedback/catalogs/sheets/report_reason_sheet.dart',
      );
      expect(
        RegExp(r'///\s*Design:\s*SHT-10').allMatches(source),
        hasLength(1),
      );
      expect(
        source,
        contains(RegExp(r'/// Design: SHT-10\s*\nclass ReportReasonSheet\b')),
      );
    });
  });

  group('SHT-10 · Şikayet nedeni · içerik', () {
    testWidgets('çerçeve, açıklama, altı seçilmemiş neden, yıkıcı "Şikayet '
        'et"; açıklama alanı ve hata yok — TR ve EN, açık + koyu', (
      tester,
    ) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in [_tr, _en]) {
          final h = _harness();
          await h.pump(tester, locale: locale, theme: theme);
          await h.open(tester);
          final l10n = tester.l10nFor(locale);
          final gu = tester.element(find.byType(GuSheetFrame)).gu;

          final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
          expect(frame.title, l10n.sht10Title);
          expect(frame.closeSemanticLabel, l10n.a11yClose);
          expect(frame.menu, isFalse);
          expect(frame.flush, isFalse);
          expect(frame.full, isFalse);
          expect(frame.footer, hasLength(1));
          expect(find.byKey(_key('close')), findsOneWidget);
          expect(find.byKey(_key('scrim')), findsOneWidget);

          final desc = tester.widget<Text>(find.text(l10n.sht10Desc));
          expect(desc.style!.fontSize, gu.text.bodyS.fontSize);
          expect(desc.style!.color, gu.colors.textSecondary);

          final rows = _rows(tester);
          expect(rows.map((row) => row.label), [
            l10n.reportReasonSpam,
            l10n.reportReasonHarassment,
            l10n.reportReasonInappropriate,
            l10n.reportReasonMisinformation,
            l10n.reportReasonOfftopic,
            l10n.reportReasonOther,
          ]);
          expect(rows.map((row) => row.selected).toSet(), {false});
          expect(rows.map((row) => row.control).toSet(), {
            GuOptionControl.radio,
          });
          expect(rows.map((row) => row.sub).toSet(), {null});

          final submit = _submitButton(tester);
          expect(submit.label, l10n.sht10Submit);
          expect(submit.variant, GuButtonVariant.danger);
          expect(submit.size, GuButtonSize.md);
          expect(submit.loading, isFalse);
          expect(submit.disabled, isFalse);

          expect(find.byType(GuInput), findsNothing);
          expect(find.text(l10n.authErrRequired), findsNothing);
        }
      }
    });

    testWidgets('aksiyon anahtarları: altı neden + gönder + kapat + scrim; '
        '"Diğer" seçilince açıklama alanı eklenir', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      const base = {
        'SHT-10.reason.spam',
        'SHT-10.reason.harassment',
        'SHT-10.reason.inappropriate',
        'SHT-10.reason.misinformation',
        'SHT-10.reason.offtopic',
        'SHT-10.reason.other',
        'SHT-10.submit',
        'SHT-10.close',
        'SHT-10.scrim',
      };
      expect(ActionInventory.found(tester), base);

      await _select(tester, ReportReason.other);
      expect(ActionInventory.found(tester), {...base, 'SHT-10.note'});
    });

    testWidgets('ölçüler: satırlar gövde dolgusunun içinde (etiket 32 dp), '
        '52 dp, aralık 8; düğme 48 dp; sayfa alta yapışık', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      final l10n = tester.l10nFor(_tr);

      final frame = tester.getRect(find.byType(GuSheetFrame));
      expect(frame.bottom, 844);
      expect(frame.width, 390);

      final desc = tester.getRect(find.text(l10n.sht10Desc));
      expect(desc.left, GuSizes.sheetBodyPaddingX);

      final rects = [
        for (final reason in ReportReason.values)
          tester.getRect(find.byKey(ReportReasonSheet.reasonKey(reason))),
      ];
      expect(rects.first.top - desc.bottom, GuSpacing.s8);
      for (final rect in rects) {
        expect(rect.height, GuSizes.optionRowMinHeight);
        expect(rect.left, GuSizes.sheetBodyPaddingX);
        expect(rect.right, 390 - GuSizes.sheetBodyPaddingX);
      }
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].top - rects[i - 1].bottom, GuSpacing.s8);
      }
      expect(
        tester.getRect(find.text(l10n.reportReasonSpam)).left,
        GuSizes.sheetBodyPaddingX + GuSizes.optionRowPaddingX,
      );

      final submit = tester.getRect(find.byKey(ReportReasonSheet.submitKey));
      expect(submit.height, GuSizes.buttonHeight);
      expect(submit.left, GuSizes.sheetFootPaddingX);
      expect(submit.right, 390 - GuSizes.sheetFootPaddingX);
      // `.pb16` + `.sheet-body` alt dolgusu 16, ardından alt alan (üst çizgi
      // + 12 dolgu).
      expect(
        submit.top - rects.last.bottom,
        GuSpacing.s16 +
            GuSizes.sheetBodyPaddingBottom +
            GuSizes.sheetFootBorder +
            GuSizes.sheetFootPaddingY,
      );
    });

    testWidgets('seçim tektir: dokunulan neden seçilir, önceki bırakılır', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      expect(_selected(tester), isNull);
      for (final reason in ReportReason.values) {
        await _select(tester, reason);
        expect(_selected(tester), reason);
      }
      // Aynı nedene yeniden dokunmak seçimi kaldırmaz.
      await _select(tester, ReportReason.other);
      expect(_selected(tester), ReportReason.other);
    });

    testWidgets('"Diğer": çok satırlı açıklama alanı — etiket, otomatik odak, '
        'sayaçlı, sınır `Limits.reportNoteMax`; başka neden seçilince gizlenir, '
        'yazılan metin korunur — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final h = _harness();
        await h.pump(tester, locale: locale);
        await h.open(tester);
        final l10n = tester.l10nFor(locale);

        await _select(tester, ReportReason.other);
        final input = tester.widget<GuInput>(find.byType(GuInput));
        expect(input.label, l10n.sht10Describe);
        expect(input.multiline, isTrue);
        expect(input.maxLength, Limits.reportNoteMax);
        expect(input.showCounter, isTrue);
        expect(input.autofocus, isTrue);
        expect(input.errorText, isNull);
        expect(
          tester
              .widget<TextField>(find.byKey(ReportReasonSheet.noteKey))
              .focusNode!
              .hasFocus,
          isTrue,
        );
        // Alan son nedenin altındadır.
        expect(
          tester.getRect(find.byType(GuInput)).top -
              tester
                  .getRect(
                    find.byKey(
                      ReportReasonSheet.reasonKey(ReportReason.other),
                    ),
                  )
                  .bottom,
          GuSpacing.s8,
        );

        await _enterNote(tester, 'Kulüp adına sahte duyuru');
        await _select(tester, ReportReason.spam);
        expect(find.byType(GuInput), findsNothing);
        await _select(tester, ReportReason.other);
        expect(_noteText(tester), 'Kulüp adına sahte duyuru');
      }
    });

    testWidgets('açıklama sınırı: fazlası kesilir (yapıştırma), sayaç sınırı '
        'geçmez; yarım emoji bırakılmaz', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      await _select(tester, ReportReason.other);

      await _enterNote(tester, 'a' * (Limits.reportNoteMax + 15));
      expect(_noteText(tester), 'a' * Limits.reportNoteMax);
      expect(
        find.text('${Limits.reportNoteMax}/${Limits.reportNoteMax}'),
        findsOneWidget,
      );

      await _enterNote(tester, 'a' * Limits.reportNoteMax);
      expect(_noteText(tester), hasLength(Limits.reportNoteMax));

      // Sınıra denk gelen vekil çift bölünmez.
      await _enterNote(tester, '${'a' * (Limits.reportNoteMax - 1)}😀b');
      expect(_noteText(tester), 'a' * (Limits.reportNoteMax - 1));
    });
  });

  group('SHT-10 · Şikayet nedeni · doğrulama', () {
    testWidgets('neden seçilmeden gönderim: "Bu alan zorunlu" (canlı bölge, '
        'uyarı ikonu, tehlike rengi); sayfa açık kalır; seçim hatayı siler '
        '— TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final h = _harness();
        await h.pump(tester, locale: locale);
        await h.open(tester);
        final l10n = tester.l10nFor(locale);

        await _submit(tester);
        expect(h.isClosed, isFalse);
        final error = find.text(l10n.authErrRequired);
        expect(error, findsOneWidget);
        final gu = tester.element(error).gu;
        expect(tester.widget<Text>(error).style!.color, gu.colors.stateDanger);
        expect(
          tester.widget<Text>(error).style!.fontSize,
          gu.text.fieldHelp.fontSize,
        );
        final icon = tester.widget<GuIcon>(
          find.descendant(
            of: find.ancestor(of: error, matching: find.byType(Row)).first,
            matching: find.byType(GuIcon),
          ),
        );
        expect(icon.icon, GuIcons.triangleAlert);
        expect(icon.size, GuSizes.fieldHelpIcon);
        expect(icon.color, gu.colors.stateDanger);
        final live = tester.widget<Semantics>(
          find.ancestor(of: error, matching: find.byType(Semantics)).first,
        );
        expect(live.properties.liveRegion, isTrue);
        // Hata satırı son nedenin altındadır (aralık 8).
        expect(
          tester.getRect(error).top -
              tester
                  .getRect(
                    find.byKey(
                      ReportReasonSheet.reasonKey(ReportReason.other),
                    ),
                  )
                  .bottom,
          GuSpacing.s8,
        );

        await _select(tester, ReportReason.harassment);
        expect(find.text(l10n.authErrRequired), findsNothing);
      }
    });

    testWidgets('"Diğer" + boş ya da yalnızca boşluk açıklama: "…kısa bir '
        'açıklama yaz"; yazınca hata silinir — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final h = _harness();
        await h.pump(tester, locale: locale);
        await h.open(tester);
        final l10n = tester.l10nFor(locale);

        await _select(tester, ReportReason.other);
        await _submit(tester);
        expect(h.isClosed, isFalse);
        expect(find.text(l10n.sht10OtherRequired), findsOneWidget);
        // Alanın kendisi hata görünümüne geçmez (prototip `error` vermez).
        expect(
          tester.widget<GuInput>(find.byType(GuInput)).errorText,
          isNull,
        );
        expect(
          tester.getRect(find.text(l10n.sht10OtherRequired)).top,
          greaterThan(tester.getRect(find.byType(GuInput)).bottom),
        );

        await _enterNote(tester, '   ');
        expect(find.text(l10n.sht10OtherRequired), findsNothing);
        await _submit(tester);
        expect(h.isClosed, isFalse);
        expect(find.text(l10n.sht10OtherRequired), findsOneWidget);

        await _enterNote(tester, 'x');
        expect(find.text(l10n.sht10OtherRequired), findsNothing);
      }
    });

    testWidgets('hata türü nedene göre değişir: "Diğer" hatası başka neden '
        'seçilince silinir', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      final l10n = tester.l10nFor(_tr);

      await _select(tester, ReportReason.other);
      await _submit(tester);
      expect(find.text(l10n.sht10OtherRequired), findsOneWidget);
      await _select(tester, ReportReason.offtopic);
      expect(find.text(l10n.sht10OtherRequired), findsNothing);
      expect(find.text(l10n.authErrRequired), findsNothing);
    });
  });

  group('SHT-10 · Şikayet nedeni · sonuç', () {
    testWidgets('geçerli seçim sayfayı sonuçla kapatır — altı neden; '
        'açıklama yalnızca "Diğer"de', (tester) async {
      final h = _harness(target: _post);
      await h.pump(tester);
      for (final reason in ReportReason.values) {
        await h.open(tester);
        await _select(tester, reason);
        if (reason == ReportReason.other) {
          await _enterNote(tester, '  Yanıltıcı bağlantı  ');
        }
        await _submit(tester);

        expect(find.byType(GuSheetFrame), findsNothing, reason: reason.name);
        expect(
          h.result,
          ReportReasonResult(
            target: _post,
            reason: reason,
            note: reason == ReportReason.other ? 'Yanıltıcı bağlantı' : '',
          ),
          reason: reason.name,
        );
      }
      // Gönderim yolunda DLG-25 sorulmaz.
      expect(_feedback().dialogs, isEmpty);
    });

    testWidgets('"Diğer"e yazılıp başka nedene geçilirse gizli açıklama '
        'gönderilmez', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      await _select(tester, ReportReason.other);
      await _enterNote(tester, 'gizli kalacak not');
      await _select(tester, ReportReason.spam);
      await _submit(tester);
      expect(
        h.result,
        const ReportReasonResult(target: _club, reason: ReportReason.spam),
      );
    });

    testWidgets('onSubmit `sent`: beklerken düğme meşgul, sayfa açık; sonra '
        'sonuçla kapanır', (tester) async {
      final gate = Completer<ReportSubmitOutcome>();
      final received = <ReportReasonResult>[];
      final h = _harness(
        onSubmit: (result) {
          received.add(result);
          return gate.future;
        },
      );
      await h.pump(tester);
      await h.open(tester);
      await _select(tester, ReportReason.misinformation);
      await tester.tap(find.byKey(ReportReasonSheet.submitKey));
      await tester.pump();

      const expected = ReportReasonResult(
        target: _club,
        reason: ReportReason.misinformation,
      );
      expect(received, [expected]);
      expect(_submitButton(tester).loading, isTrue);
      expect(h.isClosed, isFalse);

      // Meşgulken ikinci dokunma yeni gönderim başlatmaz; kapatma yolları
      // sayfayı kapatmaz ve DLG-25 sormaz.
      await tester.tap(find.byKey(ReportReasonSheet.submitKey));
      await tester.pump();
      expect(received, hasLength(1));
      await tester.tap(find.byKey(_key('close')));
      await tester.pump();
      expect(h.isClosed, isFalse);
      expect(_feedback().dialogs, isEmpty);

      gate.complete(ReportSubmitOutcome.sent);
      await tester.pumpAndSettle();
      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.result, expected);
    });

    testWidgets('onSubmit `failed`: sayfa açık kalır, meşgul görünüm kalkar, '
        'seçim korunur; yeniden gönderilebilir', (tester) async {
      var outcome = ReportSubmitOutcome.failed;
      var calls = 0;
      final h = _harness(
        onSubmit: (_) async {
          calls++;
          return outcome;
        },
      );
      await h.pump(tester);
      await h.open(tester);
      await _select(tester, ReportReason.other);
      await _enterNote(tester, 'açıklama');
      await _submit(tester);

      expect(calls, 1);
      expect(h.isClosed, isFalse);
      expect(_submitButton(tester).loading, isFalse);
      expect(_selected(tester), ReportReason.other);
      expect(_noteText(tester), 'açıklama');

      outcome = ReportSubmitOutcome.sent;
      await _submit(tester);
      expect(calls, 2);
      expect(
        h.result,
        const ReportReasonResult(
          target: _club,
          reason: ReportReason.other,
          note: 'açıklama',
        ),
      );
    });

    testWidgets('onSubmit `dailyLimit` (T-45): sayfa açık kalır, hata '
        'satırında günlük sınır metni (canlı bölge, tehlike rengi); seçim '
        'korunur, yeni seçim hatayı siler — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        var calls = 0;
        final h = _harness(
          onSubmit: (_) async {
            calls++;
            return ReportSubmitOutcome.dailyLimit;
          },
        );
        await h.pump(tester, locale: locale);
        await h.open(tester);
        final l10n = tester.l10nFor(locale);

        await _select(tester, ReportReason.spam);
        await _submit(tester);

        expect(calls, 1);
        expect(h.isClosed, isFalse);
        expect(_submitButton(tester).loading, isFalse);
        expect(_selected(tester), ReportReason.spam);
        final error = find.text(l10n.sht10DailyLimit);
        expect(error, findsOneWidget);
        final gu = tester.element(error).gu;
        expect(tester.widget<Text>(error).style!.color, gu.colors.stateDanger);
        final live = tester.widget<Semantics>(
          find.ancestor(of: error, matching: find.byType(Semantics)).first,
        );
        expect(live.properties.liveRegion, isTrue);

        await _select(tester, ReportReason.harassment);
        expect(find.text(l10n.sht10DailyLimit), findsNothing);
      }
    });

    testWidgets('doğrulama geçmeden onSubmit çağrılmaz', (tester) async {
      var calls = 0;
      final h = _harness(
        onSubmit: (_) async {
          calls++;
          return ReportSubmitOutcome.sent;
        },
      );
      await h.pump(tester);
      await h.open(tester);
      await _submit(tester);
      await _select(tester, ReportReason.other);
      await _submit(tester);
      expect(calls, 0);
      expect(h.isClosed, isFalse);
    });
  });

  group('SHT-10 · Şikayet nedeni · kapanma', () {
    testWidgets('seçim yokken kapat / scrim / geri doğrudan `null` ile '
        'kapatır (DLG-25 sorulmaz)', (tester) async {
      final h = _harness();
      await h.pump(tester);
      for (final action in ['close', 'scrim']) {
        await h.open(tester);
        await tester.tap(find.byKey(_key(action)), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(GuSheetFrame), findsNothing, reason: action);
        expect(h.result, isNull, reason: action);
      }
      await h.open(tester);
      await h.back(tester);
      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.result, isNull);
      expect(_feedback().dialogs, isEmpty);
    });

    testWidgets('neden seçiliyken kapatma DLG-25 sorar ("Kaydet" yok): '
        '"Düzenlemeye devam" ve scrim (null) → açık kalır, seçim durur', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      await _select(tester, ReportReason.inappropriate);
      final feedback = _feedback();

      for (final answer in [UnsavedChangesResult.keep, null]) {
        feedback.nextDialogResult = answer;
        await tester.tap(find.byKey(_key('close')));
        await tester.pumpAndSettle();
        expect(h.isClosed, isFalse, reason: '$answer');
        expect(find.byType(GuSheetFrame), findsOneWidget);
        expect(_selected(tester), ReportReason.inappropriate);
      }
      expect(feedback.dialogs, [DialogId.dlg25, DialogId.dlg25]);
      // Kirli sheet'te "Kaydet" eylemi çizilmez.
      final dialog =
          feedback.lastDialogBuilder!(tester.element(find.byType(GuSheetFrame)))
              as UnsavedChangesDialog;
      expect(dialog.hasSave, isFalse);
    });

    testWidgets('"Kaydetmeden çık" → sayfa `null` ile kapanır — kapat, scrim '
        've geri tuşu', (tester) async {
      final h = _harness();
      await h.pump(tester);
      final feedback = _feedback();

      Future<void> openDirty() async {
        await h.open(tester);
        await _select(tester, ReportReason.spam);
        feedback.nextDialogResult = UnsavedChangesResult.discard;
      }

      for (final action in ['close', 'scrim']) {
        await openDirty();
        await tester.tap(find.byKey(_key(action)), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(GuSheetFrame), findsNothing, reason: action);
        expect(h.result, isNull, reason: action);
      }

      await openDirty();
      await navigatorBack(tester, h);
      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.result, isNull);
      expect(feedback.dialogs, hasLength(3));
      expect(feedback.dialogs.toSet(), {DialogId.dlg25});
    });
  });

  group('SHT-10 · Şikayet nedeni · yerleşim', () {
    testWidgets('cihaz matrisi: taşma yok (varsayılan görünüm; klavye ve '
        'güvenli alan varyantları)', (tester) async {
      await DeviceMatrix.run(
        tester,
        (context) => const Align(
          alignment: Alignment.bottomCenter,
          child: ReportReasonSheet(target: _club),
        ),
        keyboard: true,
        safeAreas: true,
      );
    });

    testWidgets('cihaz matrisi: "Diğer" + açıklama + hata satırı taşmaz', (
      tester,
    ) async {
      OverflowDetector.install();
      addTearDown(() {
        OverflowDetector.uninstall();
        OverflowDetector.reset();
      });
      final cases = [
        ...DeviceMatrix.cases(),
        ...DeviceMatrix.variantCases(keyboard: true),
      ];
      for (final c in cases) {
        OverflowDetector.reset();
        await tester.pumpApp(
          const Align(
            alignment: Alignment.bottomCenter,
            child: ReportReasonSheet(target: _club),
          ),
          locale: c.locale,
          theme: c.theme,
          textScale: c.textScale,
          size: c.size.size,
          viewPadding: c.viewPadding,
          keyboardInset: c.keyboardInset,
        );
        final other = find.byKey(
          ReportReasonSheet.reasonKey(ReportReason.other),
        );
        await tester.ensureVisible(other);
        await tester.pump();
        await tester.tap(other);
        await tester.pump();
        await tester.tap(find.byKey(ReportReasonSheet.submitKey));
        await tester.pump(GuMotion.base);
        expect(
          find.text(tester.l10nFor(c.locale).sht10OtherRequired),
          findsOneWidget,
          reason: c.name,
        );
        OverflowDetector.assertNone(c.name);
        expect(tester.takeException(), isNull, reason: c.name);
      }
    });

    testWidgets('golden: açık sayfa (scrim dahil) — açık + koyu (TR)', (
      tester,
    ) async {
      await _harness().golden(tester, 'SHT-10');
    });

    testWidgets('golden: "Diğer" seçili, açıklama alanı ve hata satırı — '
        'açık + koyu (TR)', (tester) async {
      for (final theme in kGoldenThemes) {
        final h = _harness();
        await h.pump(tester, theme: theme);
        await h.open(tester);
        await _select(tester, ReportReason.other);
        await _submit(tester);
        // Odak kenarlığı ve imleç golden'a girmesin (kenarlık geçişi de
        // bitsin).
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(kPumpAppBoundaryKey),
          matchesGoldenFile(
            goldenUri(goldenPath('SHT-10__other', theme, _tr)),
          ),
        );
      }
    });
  });
}

/// Geri tuşu: kirli sayfada gezgin önce kapanma kapısına sorar (`maybePop`
/// `false` da dönebilir — kapıdaki soru eşzamansızdır).
Future<void> navigatorBack(
  WidgetTester tester,
  SheetHarness<ReportReasonResult> harness,
) async {
  await harness.navigatorKey.currentState!.maybePop();
  await tester.pumpAndSettle();
}
