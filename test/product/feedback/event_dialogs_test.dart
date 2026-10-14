// DLG-14 · Katılımdan vazgeç? · DLG-15 · Kontenjan doldu · DLG-16 · Etkinlik
// iptal edildi — katalog kayıtları (ikon, ton, metinler, değişkenler) ve
// gerçek `FeedbackService` üzerinden gösterim (anahtarlar, sonuçlar).
// Referans: design/reference-shots/dialogs/DLG-1{4,5,6}__{light,dark}.webp;
// prototip dialogs.js:30–32.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_ui/gu_ui.dart';

import 'dialog_test_support.dart';

/// Referans görüntülerdeki iptal edilmiş etkinlik.
const String _event = 'Açık Hava Sinema Gecesi';

void main() {
  final l10n = lookupAppLocalizations(const Locale('tr'));

  group('DLG-14 / DLG-15 / DLG-16 · katalog', () {
    test('DLG-14: ikon + birincil düğme danger; gövde bekleme listesinde '
        'ayrı', () {
      final spec = DialogCatalog.of(DialogId.dlg14)!;
      expect(spec.icon, GuIcons.calendarX);
      expect(spec.isPrimaryDanger, isTrue);
      expect(spec.title(l10n, const {}), l10n.dlg14Title);
      expect(spec.body!(l10n, const {}), l10n.dlg14Body);
      expect(
        spec.body!(l10n, const {DialogParamKeys.waitlist: true}),
        l10n.dlg14BodyWaitlist,
      );
      expect(spec.primary(l10n), l10n.commonGiveUp);
      expect(spec.secondaryLabel(l10n, const {}), l10n.dlg14Stay);
    });

    test('DLG-15: kum saati; gövde bekleyen sayısını taşır', () {
      final spec = DialogCatalog.of(DialogId.dlg15)!;
      expect(spec.icon, GuIcons.hourglass);
      expect(spec.destructive, isFalse);
      expect(
        spec.body!(l10n, const {DialogParamKeys.n: 4}),
        l10n.dlg15Body(4),
      );
      expect(spec.primary(l10n), l10n.eventCtaWaitlist);
      expect(spec.secondaryLabel(l10n, const {}), l10n.commonGiveUp);
    });

    test('DLG-16: ikon danger, birincil olağan; gövde başlık + neden adı', () {
      final spec = DialogCatalog.of(DialogId.dlg16)!;
      expect(spec.icon, GuIcons.calendarX);
      expect(spec.destructive, isTrue);
      expect(spec.isPrimaryDanger, isFalse);
      expect(
        spec.body!(l10n, const {
          DialogParamKeys.event: _event,
          DialogParamKeys.reason: 'weather',
        }),
        l10n.dlg16Body(_event, l10n.cancelReasonWeather),
      );
      expect(spec.primary(l10n), l10n.commonOk);
      expect(spec.secondaryLabel(l10n, const {}), l10n.dlg16Similar);
      expect((spec.primaryAction, spec.secondaryAction), ('ok', 'similar'));
    });
  });

  group('DLG-14 / DLG-16 · gösterim (FeedbackService)', () {
    testWidgets('DLG-14 "Vazgeç" → true, "Kalmaya devam et" → false', (
      tester,
    ) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      await harness.open<bool>(
        tester,
        (s) => s.showDialog<bool>(DialogId.dlg14),
      );
      expect(find.text(l10n.dlg14Body), findsOneWidget);
      await harness.tap(tester, DialogHarness.keyOf(DialogId.dlg14, 'confirm'));
      expect(harness.result, isTrue);

      await harness.open<bool>(
        tester,
        (s) => s.showDialog<bool>(
          DialogId.dlg14,
          params: const {DialogParamKeys.waitlist: true},
        ),
      );
      expect(find.text(l10n.dlg14BodyWaitlist), findsOneWidget);
      await harness.tap(tester, DialogHarness.keyOf(DialogId.dlg14, 'cancel'));
      expect(harness.result, isFalse);
    });

    testWidgets('DLG-16 "Benzer etkinlikleri gör" → false', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      await harness.open<bool>(
        tester,
        (s) => s.showDialog<bool>(
          DialogId.dlg16,
          params: const {
            DialogParamKeys.event: _event,
            DialogParamKeys.reason: 'weather',
          },
        ),
      );
      expect(
        find.text(l10n.dlg16Body(_event, l10n.cancelReasonWeather)),
        findsOneWidget,
      );
      await harness.tap(
        tester,
        DialogHarness.keyOf(DialogId.dlg16, 'similar'),
      );
      expect(harness.result, isFalse);
    });
  });
}
