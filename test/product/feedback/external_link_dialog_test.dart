// DLG-32 · Uygulamadan ayrılıyorsun — `ExternalLinkDialog`: çizim (ikon,
// başlık, "Şu adrese gidilecek:" + adres kutusu, "Bu adrese güveniyor
// musun?"), adres kutusunun biçimi (CSS `.code`), anahtarlar (`DLG-32.open`
// / `.cancel` / `.scrim`), sonuçlar, uzun adres + dar ekran + büyük metin
// taşması ve golden.
// Referans: design/reference-shots/dialogs/DLG-32__{light,dark}.webp; prototip
// dialogs.js:52, css:343.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/external_link_dialog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_feedback_service.dart';
import '../../helpers/test_l10n.dart';
import 'dialog_test_support.dart';

/// Referans görüntüdeki örnek adres.
final Uri _uri = Uri.parse('https://gumushane.edu.tr');

/// Tek satıra sığmayan, bölünecek boşluğu olmayan adres.
final Uri _longUri = Uri.parse(
  'https://kulupler.gumushane.edu.tr/etkinlikler/2026/bahar-senligi/'
  'kayit-formu?kaynak=uygulama&kampanya=hosgeldin-haftasi-duyurusu',
);

Key _key(String action) => DialogHarness.keyOf(DialogId.dlg32, action);

Future<void> _open(WidgetTester tester, DialogHarness harness, Uri uri) =>
    harness.open<bool>(tester, (s) => showExternalLinkDialog(s, uri));

void main() {
  group('DLG-32 · Uygulamadan ayrılıyorsun · açılış', () {
    test('katalog kaydı yoktur (özel gövde): kurucuyla açılır', () {
      expect(DialogCatalog.of(DialogId.dlg32), isNull);
      expect(DialogCatalog.ids, isNot(contains(DialogId.dlg32)));
    });

    test('showExternalLinkDialog: DLG-32 kimliğiyle, özel gövdeyle açar ve '
        'sonucu döndürür', () async {
      final feedback = FakeFeedbackService()..nextDialogResult = true;

      expect(await showExternalLinkDialog(feedback, _uri), isTrue);

      expect(feedback.dialogs, [DialogId.dlg32]);
      expect(feedback.lastDialogBuilder, isNotNull);
      expect(await showExternalLinkDialog(feedback, _uri), isNull);
    });
  });

  group('DLG-32 · Uygulamadan ayrılıyorsun · gösterim', () {
    testWidgets('çizim: bağlantı ikonu (brand kutu), başlık; gövde iki '
        'paragraf + adresin tamamı; "Aç" birincil, "Vazgeç" metin — açık + '
        'koyu, TR + EN', (tester) async {
      final harness = DialogHarness();
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in AppLocalizations.supportedLocales) {
          await harness.pump(tester, locale: locale, theme: theme);
          await _open(tester, harness, _uri);
          final l10n = tester.l10nFor(locale);

          final frame = tester.widget<GuDialogFrame>(
            find.byType(GuDialogFrame),
          );
          expect(frame.title, l10n.dlg32Title);
          expect(frame.body, isNull);
          expect(frame.icon, GuIcons.externalLink);
          expect(frame.danger, isFalse);
          expect(frame.dismissable, isTrue);
          expect(frame.actionsLayout, GuDialogActionsLayout.column);
          expect(
            tester.widget<GuIconBox>(find.byType(GuIconBox)).tone,
            GuIconBoxTone.brand,
          );
          expect(find.text(l10n.dlg32Body1), findsOneWidget);
          expect(find.text(l10n.dlg32Body2), findsOneWidget);
          expect(find.text('https://gumushane.edu.tr'), findsOneWidget);

          final open = tester.widget<GuButton>(find.byKey(_key('open')));
          expect(open.label, l10n.commonOpen);
          expect(open.variant, GuButtonVariant.primary);
          final cancel = tester.widget<GuButton>(find.byKey(_key('cancel')));
          expect(cancel.label, l10n.commonGiveUp);
          expect(cancel.variant, GuButtonVariant.text);
          expect(find.byType(GuButton), findsNWidgets(2));
          expect(
            tester.getRect(find.byKey(_key('open'))).bottom,
            lessThanOrEqualTo(tester.getRect(find.byKey(_key('cancel'))).top),
          );
          expect(find.byKey(_key('scrim')), findsOneWidget);
        }
      }
    });

    testWidgets('adres kutusu (css:343 `.code`): bg.surfaceMuted zemin, '
        'yarıçap 6, dolgu 2 / 6; yazı Inter 500 / 12 tabular, text.heading, '
        'metin ölçeğiyle büyümez; paragraflar bodyS + text.secondary — açık + '
        'koyu', (tester) async {
      final harness = DialogHarness();
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        await harness.pump(tester, theme: theme, textScale: 1.6);
        await _open(tester, harness, _uri);
        final context = tester.element(find.byType(ExternalLinkDialog));
        final gu = context.gu;
        final l10n = tester.l10nFor(const Locale('tr'));

        final url = tester.widget<Text>(find.text('https://gumushane.edu.tr'));
        expect(
          url.style,
          gu.text.mapPlaceholder.copyWith(color: gu.colors.textHeading),
        );
        expect(url.style!.fontSize, 12);
        expect(url.style!.fontWeight, FontWeight.w500);
        expect(url.textScaler, TextScaler.noScaling);

        final box = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.text('https://gumushane.edu.tr'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = box.decoration as BoxDecoration;
        expect(decoration.color, gu.colors.bgSurfaceMuted);
        expect(
          decoration.borderRadius,
          const BorderRadius.all(Radius.circular(6)),
        );
        final padding = tester.widget<Padding>(
          find
              .ancestor(
                of: find.text('https://gumushane.edu.tr'),
                matching: find.byType(Padding),
              )
              .first,
        );
        expect(
          padding.padding,
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        );

        for (final text in [l10n.dlg32Body1, l10n.dlg32Body2]) {
          expect(
            tester.widget<Text>(find.text(text)).style,
            gu.text.bodyS.copyWith(color: gu.colors.textSecondary),
            reason: text,
          );
        }
        await harness.back(tester);
      }
    });

    testWidgets('yerleşim (390 dp, TR): adres etiketin altına iner ve sola '
        'hizalıdır; ikinci paragraf 12 dp aşağıda (referans görüntü)', (
      tester,
    ) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      await _open(tester, harness, _uri);
      final l10n = tester.l10nFor(const Locale('tr'));

      final label = tester.getRect(find.text(l10n.dlg32Body1));
      final chip = tester.getRect(
        find
            .ancestor(
              of: find.text('https://gumushane.edu.tr'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final question = tester.getRect(find.text(l10n.dlg32Body2));

      expect(chip.top, greaterThanOrEqualTo(label.bottom));
      expect(chip.left, label.left);
      expect(question.top - chip.bottom, GuSizes.dialogGap);
      expect(question.left, label.left);
    });

    testWidgets('mailto adresi olduğu gibi gösterilir (DLG-01 destek '
        'bağlantısı)', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      await _open(
        tester,
        harness,
        Uri(scheme: 'mailto', path: 'kulup@gumushane.edu.tr'),
      );

      expect(find.text('mailto:kulup@gumushane.edu.tr'), findsOneWidget);
    });

    testWidgets('sonuçlar: Aç → true, Vazgeç → false, scrim → null, geri → '
        'null', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      for (final (action, result) in [
        ('open', true),
        ('cancel', false),
        ('scrim', null),
      ]) {
        await _open(tester, harness, _uri);
        expect(harness.isClosed, isFalse);

        if (action == 'scrim') {
          await tester.tapAt(const Offset(8, 8));
          await tester.pumpAndSettle();
        } else {
          await harness.tap(tester, _key(action));
        }

        expect(harness.isClosed, isTrue, reason: action);
        expect(harness.result, result, reason: action);
        expect(find.byType(GuDialogFrame), findsNothing);
      }

      await _open(tester, harness, _uri);
      await harness.back(tester);
      expect(harness.result, isNull);
    });

    testWidgets('uzun adres, 320 dp + metin ölçeği 1.6, TR + EN: adres satır '
        'kırar, yatay taşma yok (taşma testi düşürür); adresin tamamı '
        'görünür, düğmeler ekran içinde', (tester) async {
      final harness = DialogHarness();
      const size = Size(320, 568);
      for (final locale in AppLocalizations.supportedLocales) {
        await harness.pump(tester, locale: locale, size: size, textScale: 1.6);
        await _open(tester, harness, _longUri);

        final url = find.text(_longUri.toString());
        expect(url, findsOneWidget);
        final rect = tester.getRect(url);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        // Tek satır 12 px yazı ~15 dp'dir: adres birden çok satıra yayılır.
        expect(rect.height, greaterThan(30));

        for (final action in ['open', 'cancel']) {
          await tester.ensureVisible(find.byKey(_key(action)));
          await tester.pumpAndSettle();
          final button = tester.getRect(find.byKey(_key(action)));
          expect(button.height, greaterThanOrEqualTo(44), reason: action);
          expect(button.left, greaterThanOrEqualTo(0), reason: action);
          expect(button.right, lessThanOrEqualTo(size.width), reason: action);
        }
        await harness.back(tester);
      }
    });

    testWidgets('golden (açık + koyu, TR)', (tester) async {
      await DialogHarness().golden<bool>(
        tester,
        'DLG-32',
        (s) => showExternalLinkDialog(s, _uri),
      );
    });

    testWidgets('golden: uzun adres (açık + koyu, TR)', (tester) async {
      await DialogHarness().golden<bool>(
        tester,
        'DLG-32__long',
        (s) => showExternalLinkDialog(s, _longUri),
      );
    });
  });
}
