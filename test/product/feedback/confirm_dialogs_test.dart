// DLG-03 · Bildirimleri açalım mı? · DLG-04 · Kamera erişimi · DLG-05 ·
// Fotoğraflarına erişim · DLG-06 · Çıkış yapılsın mı? — katalog kayıtları ve
// gösterim: çizim (ikon, başlık, gövde, düğme türleri), anahtarlar
// (`DLG-0n.allow` / `.notNow`, `DLG-06.logout` / `.cancel`, `.scrim`),
// sonuçlar, dar ekran + büyük metin taşması ve golden.
// Referans: design/reference-shots/dialogs/DLG-0{3,4,5,6}__{light,dark}.webp;
// prototip dialogs.js:10–17, :21.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/design_files.dart';
import '../../helpers/test_l10n.dart';
import 'dialog_test_support.dart';

/// Beklenen çizim: tasarımdaki ikon ve metinler.
typedef _Expected = ({
  DialogId id,
  GuIcons icon,
  String Function(AppLocalizations l10n) title,
  String Function(AppLocalizations l10n) body,
  String Function(AppLocalizations l10n) primary,
  String Function(AppLocalizations l10n) secondary,
  String primaryAction,
  String secondaryAction,
});

final List<_Expected> _dialogs = [
  (
    id: DialogId.dlg03,
    icon: GuIcons.bellRing,
    title: (l10n) => l10n.dlg03Title,
    body: (l10n) => l10n.dlg03Body,
    primary: (l10n) => l10n.dlgPermissionAllow,
    secondary: (l10n) => l10n.dlgPermissionNotNow,
    primaryAction: 'allow',
    secondaryAction: 'notNow',
  ),
  (
    id: DialogId.dlg04,
    icon: GuIcons.camera,
    title: (l10n) => l10n.dlg04Title,
    body: (l10n) => l10n.dlg04Body,
    primary: (l10n) => l10n.dlgPermissionAllow,
    secondary: (l10n) => l10n.dlgPermissionNotNow,
    primaryAction: 'allow',
    secondaryAction: 'notNow',
  ),
  (
    id: DialogId.dlg05,
    icon: GuIcons.images,
    title: (l10n) => l10n.dlg05Title,
    body: (l10n) => l10n.dlg05Body,
    primary: (l10n) => l10n.dlgPermissionAllow,
    secondary: (l10n) => l10n.dlgPermissionNotNow,
    primaryAction: 'allow',
    secondaryAction: 'notNow',
  ),
  (
    id: DialogId.dlg06,
    icon: GuIcons.logOut,
    title: (l10n) => l10n.dlg06Title,
    body: (l10n) => l10n.dlg06Body,
    primary: (l10n) => l10n.authLogout,
    secondary: (l10n) => l10n.commonGiveUp,
    primaryAction: 'logout',
    secondaryAction: 'cancel',
  ),
];

void main() {
  group('DLG-03 / DLG-04 / DLG-05 / DLG-06 · katalog kayıtları', () {
    for (final expected in _dialogs) {
      final id = expected.id;
      test('${id.designId}: ikon, metinler (TR + EN), anahtar sonekleri; '
          'yıkıcı değil, kapatılabilir', () {
        final spec = DialogCatalog.of(id)!;
        expect(spec.icon, expected.icon);
        expect(spec.destructive, isFalse);
        expect(spec.isPrimaryDanger, isFalse);
        expect(spec.dismissible, isTrue);
        expect(spec.primaryAction, expected.primaryAction);
        expect(spec.secondaryAction, expected.secondaryAction);
        for (final locale in AppLocalizations.supportedLocales) {
          final l10n = lookupAppLocalizations(locale);
          expect(spec.title(l10n, const {}), expected.title(l10n));
          expect(spec.body!(l10n, const {}), expected.body(l10n));
          expect(spec.primary(l10n), expected.primary(l10n));
          expect(spec.secondary!(l10n), expected.secondary(l10n));
        }
      });
    }

    test('anahtarlar tasarım envanteriyle birebir (screens-actions.json '
        'DLG-04.allow / .notNow / .scrim)', () {
      final inventory = readJsonMap('design/extracted/screens-actions.json');
      final keys = {
        for (final screen in inventory.values)
          for (final action
              in ((screen as Map<String, dynamic>)['actions'] as List<dynamic>))
            if ((action as String).startsWith('DLG-')) action,
      };
      expect(keys, {'DLG-04.allow', 'DLG-04.notNow', 'DLG-04.scrim'});
      final spec = DialogCatalog.of(DialogId.dlg04)!;
      expect(keys, {
        'DLG-04.${spec.primaryAction}',
        'DLG-04.${spec.secondaryAction}',
        'DLG-04.scrim',
      });
    });

    test('OS izin maketi (PermissionSim) metinleri kullanılmaz (K-02)', () {
      final source = [
        readText('lib/product/feedback/catalogs/dialogs/dialog_spec.dart'),
        readText('lib/product/mixin/permission_prompt_mixin.dart'),
      ].join();
      for (final mock in const [
        'dlgSystemAllow',
        'dlgSystemDeny',
        'dlgSystemPermissionBody',
      ]) {
        expect(source, isNot(contains(mock)), reason: mock);
      }
    });
  });

  group('DLG-03 / DLG-04 / DLG-05 / DLG-06 · gösterim (FeedbackService)', () {
    for (final expected in _dialogs) {
      final id = expected.id;
      Key key(String action) => DialogHarness.keyOf(id, action);

      testWidgets('${id.designId} · çizim: ikon kutusu (brand), başlık, gövde; '
          'birincil düğme üstte, metin düğmesi altta — açık + koyu, TR + EN', (
        tester,
      ) async {
        final harness = DialogHarness();
        for (final theme in [ThemeMode.light, ThemeMode.dark]) {
          for (final locale in AppLocalizations.supportedLocales) {
            await harness.pump(tester, locale: locale, theme: theme);
            await harness.open<bool>(tester, (s) => s.showDialog<bool>(id));
            final l10n = tester.l10nFor(locale);

            final frame = tester.widget<GuDialogFrame>(
              find.byType(GuDialogFrame),
            );
            expect(frame.title, expected.title(l10n));
            expect(frame.body, expected.body(l10n));
            expect(frame.icon, expected.icon);
            expect(frame.danger, isFalse);
            expect(frame.dismissable, isTrue);
            expect(frame.actionsLayout, GuDialogActionsLayout.column);
            expect(
              tester.widget<GuIconBox>(find.byType(GuIconBox)).tone,
              GuIconBoxTone.brand,
            );
            expect(find.text(expected.title(l10n)), findsOneWidget);
            expect(find.text(expected.body(l10n)), findsOneWidget);

            final primary = tester.widget<GuButton>(
              find.byKey(key(expected.primaryAction)),
            );
            expect(primary.label, expected.primary(l10n));
            expect(primary.variant, GuButtonVariant.primary);
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
        (
          tester,
        ) async {
          final harness = DialogHarness();
          await harness.pump(tester);
          for (final (action, result) in [
            (expected.primaryAction, true),
            (expected.secondaryAction, false),
            ('scrim', null),
          ]) {
            await harness.open<bool>(tester, (s) => s.showDialog<bool>(id));
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

          await harness.open<bool>(tester, (s) => s.showDialog<bool>(id));
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
          await harness.open<bool>(tester, (s) => s.showDialog<bool>(id));
          for (final action in [
            expected.primaryAction,
            expected.secondaryAction,
          ]) {
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
          (s) => s.showDialog<bool>(id),
        );
      });
    }
  });
}
