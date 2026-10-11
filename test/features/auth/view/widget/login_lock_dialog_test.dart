// DLG-02 · Çok fazla deneme — giriş kilidi geri sayımı (`LoginLockDialog`):
// çizim, saniyelik geri sayım (`GuCountdown` + sahte saat), süre dolunca
// "Kilit kalktı" metni ve tek seferlik `onUnlocked`, düğme sonuçları
// (`DLG-02.ok`, `DLG-02.forgot`, scrim). `FeedbackService.showDialog(builder:)`
// ile açılır. Referans: design/reference-shots/dialogs/DLG-02__light.webp,
// __dark.webp; prototip dialogs.js:20.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/auth/view/widget/login_lock_dialog.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/fake_app_clock.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_l10n.dart';

Key _key(String action) => FeedbackKeys.of(DialogId.dlg02.designId, action);

/// Gerçek `AppFeedbackService` + go_router'ın kök gezgini (dialog düğmeleri
/// rotayı `context.pop` ile kapatır).
class _Harness {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GuToastController controller = GuToastController();
  late final AppFeedbackService service = AppFeedbackService(
    navigatorKey: navigatorKey,
    toastController: controller,
  );
  late final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: SizedBox.expand()),
      ),
    ],
  );

  int unlocked = 0;
  bool? result;
  bool closed = false;

  FakeAppClock get clock => GetIt.I<AppClock>() as FakeAppClock;

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('tr'),
    ThemeMode theme = ThemeMode.light,
  }) async {
    addTearDown(controller.dispose);
    addTearDown(router.dispose);
    await tester.pumpAppRouter(
      routerOf: (_) => router,
      locale: locale,
      theme: theme,
    );
  }

  /// Dialogu [lockFor] süreli kilitle açar.
  Future<void> open(
    WidgetTester tester, {
    Duration lockFor = Limits.loginLockout,
  }) async {
    final until = clock.nowUtc().add(lockFor);
    closed = false;
    result = null;
    unawaited(
      service
          .showDialog<bool>(
            DialogId.dlg02,
            builder: (_) => LoginLockDialog(
              lockedUntil: until,
              onUnlocked: () => unlocked++,
            ),
          )
          .then((value) {
            result = value;
            closed = true;
          }),
    );
    await tester.pumpAndSettle();
  }

  /// Saati ve test zamanını birlikte ilerletir.
  Future<void> advance(WidgetTester tester, Duration by) async {
    clock.advance(by);
    await tester.pump(by);
  }
}

GuDialogFrame _frame(WidgetTester tester) =>
    tester.widget<GuDialogFrame>(find.byType(GuDialogFrame));

void main() {
  group('DLG-02 · Çok fazla deneme', () {
    test('özel gövdelidir: katalog kaydı yok, kurucuyla açılır', () {
      expect(DialogCatalog.of(DialogId.dlg02), isNull);
      expect(Limits.loginLockout, const Duration(seconds: 30));
    });

    testWidgets('çizim: kilit ikonu (marka tonu), başlık, "… 30 saniye '
        'kilitledik", "Tamam" birincil + "Şifremi unuttum" metin düğmesi — '
        'açık + koyu, TR + EN', (tester) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in AppLocalizations.supportedLocales) {
          final h = _Harness();
          await h.pump(tester, locale: locale, theme: theme);
          await h.open(tester);
          final l10n = tester.l10nFor(locale);

          final frame = _frame(tester);
          expect(frame.title, l10n.dlg02Title);
          expect(frame.body, l10n.dlg02Body('30'));
          expect(frame.icon, GuIcons.lock);
          expect(frame.danger, isFalse);
          expect(frame.dismissable, isTrue);
          expect(
            tester.widget<GuIconBox>(find.byType(GuIconBox)).tone,
            GuIconBoxTone.brand,
          );
          final ok = tester.widget<GuButton>(find.byKey(_key('ok')));
          expect(ok.label, l10n.commonOk);
          expect(ok.variant, GuButtonVariant.primary);
          final forgot = tester.widget<GuButton>(find.byKey(_key('forgot')));
          expect(forgot.label, l10n.authForgot);
          expect(forgot.variant, GuButtonVariant.text);
          expect(
            tester.getRect(find.byKey(_key('ok'))).bottom,
            lessThanOrEqualTo(tester.getRect(find.byKey(_key('forgot'))).top),
          );
          expect(find.byKey(_key('scrim')), findsOneWidget);

          // Zamanlayıcı kapansın (dialog açıkken test bitmesin).
          await tester.tap(find.byKey(_key('ok')));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('geri sayım her saniye güncellenir; süre dolunca "Kilit '
        'kalktı" metni gösterilir, dialog açık kalır ve onUnlocked bir kez '
        'çağrılır', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await h.open(tester, lockFor: const Duration(seconds: 3));
      final l10n = tester.l10n;
      expect(_frame(tester).body, l10n.dlg02Body('3'));

      await h.advance(tester, const Duration(seconds: 1));
      expect(_frame(tester).body, l10n.dlg02Body('2'));
      await h.advance(tester, const Duration(seconds: 1));
      expect(_frame(tester).body, l10n.dlg02Body('1'));
      expect(h.unlocked, 0);

      await h.advance(tester, const Duration(seconds: 1));
      expect(_frame(tester).body, l10n.dlg02Unlocked);
      expect(h.unlocked, 1);
      expect(h.closed, isFalse);

      await h.advance(tester, const Duration(seconds: 5));
      expect(_frame(tester).body, l10n.dlg02Unlocked);
      expect(h.unlocked, 1);

      await tester.tap(find.byKey(_key('ok')));
      await tester.pumpAndSettle();
      expect(h.closed, isTrue);
    });

    testWidgets('kalan süre yukarı yuvarlanır (29,2 sn → "30")', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await h.open(tester, lockFor: const Duration(milliseconds: 29200));
      expect(_frame(tester).body, tester.l10n.dlg02Body('30'));

      await tester.tap(find.byKey(_key('ok')));
      await tester.pumpAndSettle();
    });

    testWidgets('kilidi çoktan açılmış hedefle açılırsa doğrudan "Kilit '
        'kalktı"; onUnlocked ilk kareden sonra bir kez', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await h.open(tester, lockFor: const Duration(seconds: -1));

      expect(_frame(tester).body, tester.l10n.dlg02Unlocked);
      expect(h.unlocked, 1);

      await tester.tap(find.byKey(_key('ok')));
      await tester.pumpAndSettle();
      expect(h.unlocked, 1);
    });

    testWidgets('sonuçlar: Tamam → false, Şifremi unuttum → true, scrim → '
        'null; kapanınca zamanlayıcı durur', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      for (final (action, expected) in [
        ('ok', false),
        ('forgot', true),
        ('scrim', null),
      ]) {
        await h.open(tester);
        await tester.tap(find.byKey(_key(action)));
        await tester.pumpAndSettle();

        expect(h.closed, isTrue, reason: action);
        expect(h.result, expected, reason: action);
        expect(find.byType(GuDialogFrame), findsNothing);
      }
      // Kapalı dialog saymaz: süre dolsa da onUnlocked çağrılmaz.
      await h.advance(tester, Limits.loginLockout);
      expect(h.unlocked, 0);
    });

    testWidgets('onUnlocked verilmese de süre dolumu hata vermez', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      final until = h.clock.nowUtc().add(const Duration(seconds: 1));
      unawaited(
        h.service.showDialog<bool>(
          DialogId.dlg02,
          builder: (_) => LoginLockDialog(lockedUntil: until),
        ),
      );
      await tester.pumpAndSettle();
      await h.advance(tester, const Duration(seconds: 1));

      expect(_frame(tester).body, tester.l10n.dlg02Unlocked);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (context) => Center(
          child: LoginLockDialog(
            lockedUntil: (GetIt.I<AppClock>() as FakeAppClock).nowUtc().add(
              Limits.loginLockout,
            ),
          ),
        ),
        safeAreas: true,
      );
      // Son çizimin zamanlayıcısını kapat.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
