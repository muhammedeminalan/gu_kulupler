// DLG-07 · İsteği iptal et? · DLG-08 · Kulüpten ayrıl? · DLG-09 · Ayrılamazsın
// · DLG-12 · Şikayetin alındı — katalog kayıtları ve gösterim: çizim (ikon,
// ikon kutusu tonu, başlık, kulüp adlı gövde, düğme türleri), anahtarlar
// (`DLG-07.confirm` / `.cancel`, `DLG-08.confirm` / `.cancel`,
// `DLG-09.transfer` / `.ok`, `DLG-12.ok` / `.block`, `.scrim`), sonuçlar,
// DLG-12'nin koşullu "… kullanıcısını da engelle" düğmesi, dar ekran + büyük
// metin taşması ve golden.
// Referans: design/reference-shots/dialogs/DLG-{07,08,09,12}__{light,dark}.webp;
// prototip dialogs.js:22, :24, :25, :28.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/test_l10n.dart';
import 'dialog_test_support.dart';

/// Referans görüntülerdeki örnek kulüp ve kullanıcı.
const String _club = 'Müzik ve Sahne Sanatları Kulübü';
const String _user = 'Yiğit Kılıç';

/// Beklenen çizim: tasarımdaki ikon, ton ve metinler.
typedef _Expected = ({
  DialogId id,
  GuIcons icon,
  bool danger,
  DialogParams params,
  String Function(AppLocalizations l10n) title,
  String Function(AppLocalizations l10n) body,
  String Function(AppLocalizations l10n) primary,
  String Function(AppLocalizations l10n) secondary,
  String primaryAction,
  String secondaryAction,
});

final List<_Expected> _dialogs = [
  (
    id: DialogId.dlg07,
    icon: GuIcons.x,
    danger: true,
    params: const {DialogParamKeys.club: _club},
    title: (l10n) => l10n.dlg07Title,
    body: (l10n) => l10n.dlg07Body(_club),
    primary: (l10n) => l10n.applicationCancel,
    secondary: (l10n) => l10n.commonGiveUp,
    primaryAction: 'confirm',
    secondaryAction: 'cancel',
  ),
  (
    id: DialogId.dlg08,
    icon: GuIcons.logOut,
    danger: true,
    params: const {DialogParamKeys.club: _club},
    title: (l10n) => l10n.dlg08Title,
    body: (l10n) => l10n.dlg08Body(_club),
    primary: (l10n) => l10n.clubLeave,
    secondary: (l10n) => l10n.commonGiveUp,
    primaryAction: 'confirm',
    secondaryAction: 'cancel',
  ),
  (
    id: DialogId.dlg09,
    icon: GuIcons.crown,
    danger: false,
    params: const {},
    title: (l10n) => l10n.dlg09Title,
    body: (l10n) => l10n.dlg09Body,
    primary: (l10n) => l10n.mgtMembersTransfer,
    secondary: (l10n) => l10n.commonOk,
    primaryAction: 'transfer',
    secondaryAction: 'ok',
  ),
  (
    id: DialogId.dlg12,
    icon: GuIcons.shieldCheck,
    danger: false,
    params: const {DialogParamKeys.name: _user},
    title: (l10n) => l10n.dlg12Title,
    body: (l10n) => l10n.dlg12Body,
    primary: (l10n) => l10n.commonOk,
    secondary: (l10n) => l10n.dlg12Block(_user),
    primaryAction: 'ok',
    secondaryAction: 'block',
  ),
];

void main() {
  group('DLG-07 / DLG-08 / DLG-09 / DLG-12 · katalog kayıtları', () {
    for (final expected in _dialogs) {
      final id = expected.id;
      test('${id.designId}: ikon, ton, metinler (TR + EN), anahtar sonekleri; '
          'kapatılabilir', () {
        final spec = DialogCatalog.of(id)!;
        expect(spec.icon, expected.icon);
        expect(spec.destructive, expected.danger);
        // Yıkıcı onayda birincil düğme de danger (dialogs.js `'danger'`).
        expect(spec.isPrimaryDanger, expected.danger);
        expect(spec.dismissible, isTrue);
        expect(spec.primaryAction, expected.primaryAction);
        expect(spec.secondaryAction, expected.secondaryAction);
        for (final locale in AppLocalizations.supportedLocales) {
          final l10n = lookupAppLocalizations(locale);
          expect(spec.title(l10n, expected.params), expected.title(l10n));
          expect(spec.body!(l10n, expected.params), expected.body(l10n));
          expect(spec.primary(l10n), expected.primary(l10n));
          expect(
            spec.secondaryLabel(l10n, expected.params),
            expected.secondary(l10n),
          );
        }
      });
    }

    test('DLG-07 / DLG-08 gövdesi kulüp adını taşır; ad verilmezse boş '
        'kalır (çökmez)', () {
      final l10n = lookupAppLocalizations(const Locale('tr'));
      for (final id in [DialogId.dlg07, DialogId.dlg08]) {
        final body = DialogCatalog.of(id)!.body!;
        expect(
          body(l10n, const {DialogParamKeys.club: _club}),
          contains(_club),
        );
        expect(body(l10n, const {}), isNot(contains('{club}')));
        expect(body(l10n, const {DialogParamKeys.club: 42}), isNotEmpty);
      }
    });

    test('DLG-12 "… kullanıcısını da engelle": yalnızca ad verildiyse; boş ad '
        've metin olmayan değer düğme çizdirmez', () {
      final spec = DialogCatalog.of(DialogId.dlg12)!;
      final l10n = lookupAppLocalizations(const Locale('tr'));
      expect(spec.secondary, isNull);
      expect(
        spec.secondaryLabel(l10n, const {DialogParamKeys.name: _user}),
        l10n.dlg12Block(_user),
      );
      expect(spec.secondaryLabel(l10n, const {}), isNull);
      expect(
        spec.secondaryLabel(l10n, const {DialogParamKeys.name: ''}),
        isNull,
      );
      expect(
        spec.secondaryLabel(l10n, const {DialogParamKeys.name: 7}),
        isNull,
      );
    });

    test('DialogSpec.secondaryLabel: secondaryFor verilmediyse sabit ikincil '
        'düğme; ikisi de yoksa null', () {
      final l10n = lookupAppLocalizations(const Locale('tr'));
      expect(
        DialogCatalog.of(DialogId.dlg07)!.secondaryLabel(l10n, const {}),
        l10n.commonGiveUp,
      );
      expect(
        DialogCatalog.of(DialogId.dlg26)!.secondaryLabel(l10n, const {}),
        isNull,
      );
    });

    test('DialogParamKeys ARB yer tutucu adlarıyla aynıdır', () {
      expect(DialogParamKeys.club, 'club');
      expect(DialogParamKeys.name, 'name');
    });
  });

  group('DLG-07 / DLG-08 / DLG-09 / DLG-12 · gösterim (FeedbackService)', () {
    for (final expected in _dialogs) {
      final id = expected.id;
      Key key(String action) => DialogHarness.keyOf(id, action);
      Future<void> open(WidgetTester tester, DialogHarness harness) =>
          harness.open<bool>(
            tester,
            (s) => s.showDialog<bool>(id, params: expected.params),
          );

      testWidgets('${id.designId} · çizim: ikon kutusu '
          '(${expected.danger ? 'danger' : 'brand'}), başlık, gövde; birincil '
          'düğme üstte, metin düğmesi altta — açık + koyu, TR + EN', (
        tester,
      ) async {
        final harness = DialogHarness();
        for (final theme in [ThemeMode.light, ThemeMode.dark]) {
          for (final locale in AppLocalizations.supportedLocales) {
            await harness.pump(tester, locale: locale, theme: theme);
            await open(tester, harness);
            final l10n = tester.l10nFor(locale);

            final frame = tester.widget<GuDialogFrame>(
              find.byType(GuDialogFrame),
            );
            expect(frame.title, expected.title(l10n));
            expect(frame.body, expected.body(l10n));
            expect(frame.icon, expected.icon);
            expect(frame.danger, expected.danger);
            expect(frame.dismissable, isTrue);
            expect(frame.actionsLayout, GuDialogActionsLayout.column);
            expect(
              tester.widget<GuIconBox>(find.byType(GuIconBox)).tone,
              expected.danger ? GuIconBoxTone.danger : GuIconBoxTone.brand,
            );
            expect(find.text(expected.title(l10n)), findsOneWidget);
            expect(find.text(expected.body(l10n)), findsOneWidget);

            final primary = tester.widget<GuButton>(
              find.byKey(key(expected.primaryAction)),
            );
            expect(primary.label, expected.primary(l10n));
            expect(
              primary.variant,
              expected.danger
                  ? GuButtonVariant.danger
                  : GuButtonVariant.primary,
            );
            final secondary = tester.widget<GuButton>(
              find.byKey(key(expected.secondaryAction)),
            );
            expect(secondary.label, expected.secondary(l10n));
            expect(secondary.variant, GuButtonVariant.text);
            expect(find.byType(GuButton), findsNWidgets(2));
            expect(
              tester.getRect(find.byKey(key(expected.primaryAction))).bottom,
              lessThanOrEqualTo(
                tester.getRect(find.byKey(key(expected.secondaryAction))).top,
              ),
            );
            expect(find.byKey(key('scrim')), findsOneWidget);
          }
        }
      });

      testWidgets(
        '${id.designId} · sonuçlar: ${expected.primaryAction} → true, '
        '${expected.secondaryAction} → false, scrim → null, geri → null',
        (tester) async {
          final harness = DialogHarness();
          await harness.pump(tester);
          for (final (action, result) in [
            (expected.primaryAction, true),
            (expected.secondaryAction, false),
            ('scrim', null),
          ]) {
            await open(tester, harness);
            expect(harness.isClosed, isFalse);

            // Scrim dialogun arkasında tam ekrandır: ortası dialogla örtülü.
            if (action == 'scrim') {
              await tester.tapAt(const Offset(8, 8));
              await tester.pumpAndSettle();
            } else {
              await harness.tap(tester, key(action));
            }

            expect(harness.isClosed, isTrue, reason: action);
            expect(harness.result, result, reason: action);
            expect(find.byType(GuDialogFrame), findsNothing);
          }

          await open(tester, harness);
          await harness.back(tester);
          expect(harness.result, isNull);
        },
      );

      testWidgets('${id.designId} · 320 dp + metin ölçeği 1.6, TR + EN: taşma '
          'yok (taşma testi düşürür), düğmeler dokunulabilir boyutta ve ekran '
          'içinde', (tester) async {
        final harness = DialogHarness();
        const size = Size(320, 568);
        for (final locale in AppLocalizations.supportedLocales) {
          await harness.pump(
            tester,
            locale: locale,
            size: size,
            textScale: 1.6,
          );
          await open(tester, harness);
          for (final action in [
            expected.primaryAction,
            expected.secondaryAction,
          ]) {
            // Dialog kısa ekranda kayar: düğme görünür alana getirilir.
            await tester.ensureVisible(find.byKey(key(action)));
            await tester.pumpAndSettle();
            final rect = tester.getRect(find.byKey(key(action)));
            expect(rect.height, greaterThanOrEqualTo(44), reason: action);
            expect(rect.left, greaterThanOrEqualTo(0), reason: action);
            expect(rect.right, lessThanOrEqualTo(size.width), reason: action);
          }
          await harness.back(tester);
        }
      });

      testWidgets('${id.designId} · golden (açık + koyu, TR)', (tester) async {
        await DialogHarness().golden<bool>(
          tester,
          id.designId,
          (s) => s.showDialog<bool>(id, params: expected.params),
        );
      });
    }

    testWidgets('DLG-12 · kullanıcıya bağlı olmayan şikayet (kulüp / '
        'etkinlik): yalnızca "Tamam"; engelle düğmesi çizilmez — TR + EN', (
      tester,
    ) async {
      final harness = DialogHarness();
      Key key(String action) => DialogHarness.keyOf(DialogId.dlg12, action);
      for (final locale in AppLocalizations.supportedLocales) {
        await harness.pump(tester, locale: locale);
        await harness.open<bool>(
          tester,
          (s) => s.showDialog<bool>(DialogId.dlg12),
        );
        final l10n = tester.l10nFor(locale);

        expect(find.byType(GuButton), findsOneWidget);
        expect(find.byKey(key('block')), findsNothing);
        expect(
          tester.widget<GuButton>(find.byKey(key('ok'))).label,
          l10n.commonOk,
        );

        await harness.tap(tester, key('ok'));
        expect(harness.result, isTrue);
      }
    });

    testWidgets('DLG-12 · golden: engelle düğmesiz (açık + koyu, TR)', (
      tester,
    ) async {
      await DialogHarness().golden<bool>(
        tester,
        'DLG-12__noblock',
        (s) => s.showDialog<bool>(DialogId.dlg12),
      );
    });
  });
}
