// DLG-01 · Hesabın askıya alındı — katalog kaydı + `SuspendedAccountMixin`:
// çizim (ikon `danger`, birincil düğme olağan), anahtarlar (`DLG-01.support`,
// `DLG-01.ok`, `DLG-01.scrim`), sonuçlar ve "Destekle iletişime geç" →
// destek e-postası (`UrlLauncherService`). Referans:
// design/reference-shots/dialogs/DLG-01__light.webp, __dark.webp; prototip
// dialogs.js:18.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/mixin/suspended_account_mixin.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_base.dart';
import '../../fakes/fake_feedback_service.dart';
import '../../fakes/fake_url_launcher_service.dart';
import '../../fakes/register_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_l10n.dart';

/// Askıyı fark eden bir ViewModel'in en küçük hali.
final class _Notifier with ProjectDependencyMixin, SuspendedAccountMixin {}

final Uri _supportMail = Uri(
  scheme: 'mailto',
  path: AppConstants.supportEmail,
);

Key _key(String action) => FeedbackKeys.of(DialogId.dlg01.designId, action);

void main() {
  group('DLG-01 · Hesabın askıya alındı · katalog kaydı', () {
    test('ikon `ban` + danger; birincil düğme olağan (danger değil); '
        'anahtar sonekleri support / ok; kapatılabilir', () {
      final spec = DialogCatalog.of(DialogId.dlg01)!;
      expect(spec.icon, GuIcons.ban);
      expect(spec.destructive, isTrue);
      expect(spec.primaryDanger, isFalse);
      expect(spec.isPrimaryDanger, isFalse);
      expect(spec.dismissible, isTrue);
      expect(spec.primaryAction, 'support');
      expect(spec.secondaryAction, 'ok');
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        expect(spec.title(l10n, const {}), l10n.dlg01Title);
        expect(spec.body!(l10n, const {}), l10n.dlg01Body);
        expect(spec.primary(l10n), l10n.dlg01Support);
        expect(spec.secondary!(l10n), l10n.commonOk);
      }
    });

    test('DialogSpec.isPrimaryDanger: verilmezse destructive ile aynı', () {
      DialogSpec spec({required bool destructive, bool? primaryDanger}) =>
          DialogSpec(
            title: (l10n, _) => l10n.dlg01Title,
            primary: (l10n) => l10n.commonOk,
            destructive: destructive,
            primaryDanger: primaryDanger,
          );
      expect(spec(destructive: false).isPrimaryDanger, isFalse);
      expect(spec(destructive: true).isPrimaryDanger, isTrue);
      expect(
        spec(destructive: true, primaryDanger: false).isPrimaryDanger,
        isFalse,
      );
      expect(
        spec(destructive: false, primaryDanger: true).isPrimaryDanger,
        isTrue,
      );
    });

    test('destek bağlantısı AppConstants.supportEmail adresine mailto', () {
      expect(AppConstants.supportMailUri, _supportMail);
      expect(
        AppConstants.supportMailUri.toString(),
        'mailto:${AppConstants.supportEmail}',
      );
    });
  });

  group('DLG-01 · Hesabın askıya alındı · gösterim (FeedbackService)', () {
    late GlobalKey<NavigatorState> navigatorKey;
    late GuToastController controller;
    late AppFeedbackService service;

    Future<void> pump(
      WidgetTester tester, {
      Locale locale = const Locale('tr'),
      ThemeMode theme = ThemeMode.light,
    }) async {
      navigatorKey = GlobalKey<NavigatorState>();
      controller = GuToastController();
      addTearDown(controller.dispose);
      service = AppFeedbackService(
        navigatorKey: navigatorKey,
        toastController: controller,
      );
      await tester.pumpApp(
        Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: SizedBox.expand()),
          ),
        ),
        locale: locale,
        theme: theme,
      );
    }

    testWidgets('çizim: danger ikon kutusu, başlık, gövde; "Destekle iletişime '
        'geç" birincil, "Tamam" metin düğmesi — açık + koyu, TR + EN', (
      tester,
    ) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in AppLocalizations.supportedLocales) {
          await pump(tester, locale: locale, theme: theme);
          unawaited(service.showDialog<bool>(DialogId.dlg01));
          await tester.pumpAndSettle();
          final l10n = tester.l10nFor(locale);

          final frame = tester.widget<GuDialogFrame>(
            find.byType(GuDialogFrame),
          );
          expect(frame.title, l10n.dlg01Title);
          expect(frame.body, l10n.dlg01Body);
          expect(frame.icon, GuIcons.ban);
          expect(frame.danger, isTrue);
          expect(frame.dismissable, isTrue);
          expect(frame.actionsLayout, GuDialogActionsLayout.column);
          expect(
            tester.widget<GuIconBox>(find.byType(GuIconBox)).tone,
            GuIconBoxTone.danger,
          );

          final support = tester.widget<GuButton>(find.byKey(_key('support')));
          expect(support.label, l10n.dlg01Support);
          expect(support.variant, GuButtonVariant.primary);
          final ok = tester.widget<GuButton>(find.byKey(_key('ok')));
          expect(ok.label, l10n.commonOk);
          expect(ok.variant, GuButtonVariant.text);
          // Birincil üstte, metin düğmesi altta (css:284).
          expect(
            tester.getRect(find.byKey(_key('support'))).bottom,
            lessThanOrEqualTo(tester.getRect(find.byKey(_key('ok'))).top),
          );
          expect(find.byKey(_key('scrim')), findsOneWidget);
        }
      }
    });

    testWidgets('sonuçlar: destek → true, Tamam → false, scrim → null', (
      tester,
    ) async {
      await pump(tester);
      for (final (action, expected) in [
        ('support', true),
        ('ok', false),
        ('scrim', null),
      ]) {
        bool? result;
        var done = false;
        unawaited(
          service.showDialog<bool>(DialogId.dlg01).then((value) {
            result = value;
            done = true;
          }),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_key(action)));
        await tester.pumpAndSettle();

        expect(done, isTrue, reason: action);
        expect(result, expected, reason: action);
        expect(find.byType(GuDialogFrame), findsNothing);
      }
    });

    testWidgets('uçtan uca: mixin dialogu açar; "Destekle iletişime geç" '
        'destek e-postasını açar ve dialog kapanır', (tester) async {
      await pump(tester);
      // `pumpApp` fake'leri kaydetti: geri bildirimi gerçek servisle değiştir.
      await GetIt.I.unregister<FeedbackService>();
      GetIt.I.registerSingleton<FeedbackService>(service);
      final launcher = GetIt.I<UrlLauncherService>() as FakeUrlLauncherService;

      bool? opened;
      unawaited(
        _Notifier().showSuspendedAccountDialog().then((v) => opened = v),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsOneWidget);
      expect(launcher.opened, isEmpty);

      await tester.tap(find.byKey(_key('support')));
      await tester.pumpAndSettle();

      expect(find.byType(GuDialogFrame), findsNothing);
      expect(launcher.opened, [_supportMail]);
      expect(opened, isTrue);
    });
  });

  group('DLG-01 · SuspendedAccountMixin', () {
    late FakeFeedbackService feedback;
    late FakeUrlLauncherService launcher;

    setUp(() async {
      await GetIt.I.reset();
      registerDefaultFakes();
      addTearDown(GetIt.I.reset);
      feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
      launcher = GetIt.I<UrlLauncherService>() as FakeUrlLauncherService;
    });

    test('dialogu katalog kipinde açar (özel gövde yok)', () async {
      await _Notifier().showSuspendedAccountDialog();

      expect(feedback.dialogs, [DialogId.dlg01]);
      expect(feedback.lastDialogBuilder, isNull);
      expect(feedback.dialogParams.single, isEmpty);
    });

    test('destek seçilirse (true) destek e-postası açılır', () async {
      feedback.nextDialogResult = true;

      expect(await _Notifier().showSuspendedAccountDialog(), isTrue);

      expect(launcher.opened, [_supportMail]);
      expect(launcher.calls, [
        FakeCall('open', [_supportMail]),
      ]);
    });

    test('Tamam (false) ve scrim / geri (null) bağlantı açmaz', () async {
      for (final result in [false, null]) {
        feedback.nextDialogResult = result;

        expect(await _Notifier().showSuspendedAccountDialog(), isFalse);
      }
      expect(feedback.dialogs, [DialogId.dlg01, DialogId.dlg01]);
      expect(launcher.opened, isEmpty);
    });

    test('cihazda e-posta uygulaması yoksa false döner (fırlatmaz)', () async {
      feedback.nextDialogResult = true;
      launcher.canOpen = false;

      expect(await _Notifier().showSuspendedAccountDialog(), isFalse);
      expect(launcher.opened, [_supportMail]);
    });
  });
}
