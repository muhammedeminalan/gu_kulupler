// DLG-25 · Değişiklikler kaydedilmedi — `UnsavedChangesMixin`: temiz formda
// doğrudan çıkış; kirli formda sistem geri / kapat → DLG-25; keep / discard /
// save sonuçları; "Kaydet" yalnızca `onSaveRequested` varsa; AUT-05 tarzı
// özel "kaydetmeden çık"; çift istek koruması (PLAN §13.8).
// Prototip: dialogs.js:43, screens-profile.js:24, screens-auth.js:141.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_feedback_service.dart';
import '../../helpers/pump_app.dart';

const Key _homeKey = ValueKey<String>('test.home');
const Key _formKey = ValueKey<String>('test.form');
const Key _closeKey = ValueKey<String>('test.close');

Key _dialogKey(String action) =>
    FeedbackKeys.of(DialogId.dlg25.designId, action);

/// Form ekranının testten yönetilen davranışı.
class _FormConfig {
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);

  /// `null` → "Kaydet" yok; değilse kaydın sonucu.
  bool? saveResult;

  /// "Kaydet" çağrı sayısı.
  int saves = 0;

  /// Verilirse "Kaydetmeden çık" ekranı kapatmak yerine bunu çalıştırır
  /// (AUT-05: oturumu kapat).
  VoidCallback? customDiscard;
}

class _Form extends ConsumerStatefulWidget {
  const _Form(this.config);

  final _FormConfig config;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> with UnsavedChangesMixin {
  @override
  void initState() {
    super.initState();
    widget.config.dirty.addListener(_onDirtyChanged);
  }

  @override
  void dispose() {
    widget.config.dirty.removeListener(_onDirtyChanged);
    super.dispose();
  }

  void _onDirtyChanged() => setState(() {});

  @override
  bool get isDirty => widget.config.dirty.value;

  @override
  Future<bool> Function()? get onSaveRequested =>
      widget.config.saveResult == null ? null : _save;

  Future<bool> _save() async {
    widget.config.saves++;
    return widget.config.saveResult!;
  }

  @override
  Future<void> onDiscardConfirmed() async {
    final custom = widget.config.customDiscard;
    if (custom == null) return super.onDiscardConfirmed();
    custom();
  }

  @override
  Widget build(BuildContext context) => buildUnsavedGuard(
    child: Scaffold(
      key: _formKey,
      body: Center(
        child: TextButton(
          key: _closeKey,
          onPressed: confirmLeave,
          child: const SizedBox.square(dimension: 48),
        ),
      ),
    ),
  );
}

void main() {
  late _FormConfig config;
  late GlobalKey<NavigatorState> navigatorKey;
  late GoRouter router;
  late FakeFeedbackService feedback;

  /// `/` → `/form` yığınıyla açar (form geri dönülebilir bir sayfadır).
  Future<void> pump(WidgetTester tester, {bool pushForm = true}) async {
    config = _FormConfig();
    addTearDown(config.dirty.dispose);
    navigatorKey = GlobalKey<NavigatorState>();
    router = GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: pushForm ? '/' : '/form',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(key: _homeKey),
          routes: [
            if (pushForm)
              GoRoute(path: 'form', builder: (_, _) => _Form(config)),
          ],
        ),
        if (!pushForm) GoRoute(path: '/form', builder: (_, _) => _Form(config)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpAppRouter(routerOf: (_) => router);
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    if (pushForm) {
      unawaited(router.push('/form'));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(_formKey), findsOneWidget);
  }

  /// Sistem geri tuşu / geri hareketi.
  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Future<void> tapClose(WidgetTester tester) async {
    await tester.tap(find.byKey(_closeKey));
    await tester.pumpAndSettle();
  }

  void expectOnForm() {
    expect(find.byKey(_formKey), findsOneWidget);
    expect(find.byKey(_homeKey), findsNothing);
  }

  void expectLeft() {
    expect(find.byKey(_formKey), findsNothing);
    expect(find.byKey(_homeKey), findsOneWidget);
  }

  group('DLG-25 · UnsavedChangesMixin · temiz form', () {
    testWidgets('sistem geri doğrudan çıkar; dialog açılmaz', (tester) async {
      await pump(tester);

      await systemBack(tester);

      expectLeft();
      expect(feedback.dialogs, isEmpty);
    });

    testWidgets('kapat düğmesi (confirmLeave) doğrudan çıkar', (tester) async {
      await pump(tester);

      await tapClose(tester);

      expectLeft();
      expect(feedback.dialogs, isEmpty);
    });

    testWidgets('koruma `PopScope(canPop: !isDirty)` ile kurulur ve isDirty '
        'değişince güncellenir', (tester) async {
      await pump(tester);
      PopScope<Object?> scope() => tester.widget<PopScope<Object?>>(
        find.descendant(
          of: find.byType(_Form),
          matching: find.byType(PopScope<Object?>),
        ),
      );
      expect(scope().canPop, isTrue);

      config.dirty.value = true;
      await tester.pump();

      expect(scope().canPop, isFalse);
    });
  });

  group('DLG-25 · UnsavedChangesMixin · kirli form', () {
    /// Çıkış isteğinin iki yolu da ([leave]: sistem geri, kapat düğmesi) aynı
    /// akışı çalıştırır.
    void leaveTests(
      String name,
      Future<void> Function(WidgetTester tester) leave,
    ) {
      testWidgets('$name → DLG-25 özel gövdeyle açılır; "Düzenlemeye devam '
          'et" (keep) ve scrim / geri (null) ekranı açık bırakır', (
        tester,
      ) async {
        await pump(tester);
        config.dirty.value = true;
        await tester.pump();

        for (final result in [UnsavedChangesResult.keep, null]) {
          feedback.nextDialogResult = result;
          await leave(tester);
          expectOnForm();
        }

        expect(feedback.dialogs, [DialogId.dlg25, DialogId.dlg25]);
        expect(feedback.lastDialogBuilder, isNotNull);
      });

      testWidgets('$name → "Kaydetmeden çık" (discard) ekranı kapatır', (
        tester,
      ) async {
        await pump(tester);
        config.dirty.value = true;
        await tester.pump();
        feedback.nextDialogResult = UnsavedChangesResult.discard;

        await leave(tester);

        expectLeft();
        expect(feedback.dialogs, [DialogId.dlg25]);
        expect(config.saves, 0);
      });
    }

    leaveTests('sistem geri', systemBack);
    leaveTests('kapat düğmesi', tapClose);

    testWidgets('"Kaydet" (save): onSaveRequested çağrılır; true → ekran '
        'kapanır', (tester) async {
      await pump(tester);
      config
        ..saveResult = true
        ..dirty.value = true;
      await tester.pump();
      feedback.nextDialogResult = UnsavedChangesResult.save;

      await systemBack(tester);

      expect(config.saves, 1);
      expectLeft();
    });

    testWidgets('"Kaydet" başarısızsa (false) ekran açık kalır; yeniden '
        'denenebilir', (tester) async {
      await pump(tester);
      config
        ..saveResult = false
        ..dirty.value = true;
      await tester.pump();
      feedback.nextDialogResult = UnsavedChangesResult.save;

      await tapClose(tester);

      expect(config.saves, 1);
      expectOnForm();

      config.saveResult = true;
      feedback.nextDialogResult = UnsavedChangesResult.save;
      await tapClose(tester);

      expect(config.saves, 2);
      expectLeft();
    });

    testWidgets('onDiscardConfirmed ezilirse (AUT-05: oturumu kapat) ekran '
        'kapatılmaz, özel işlem çalışır', (tester) async {
      await pump(tester);
      var signedOut = 0;
      config
        ..customDiscard = (() => signedOut++)
        ..dirty.value = true;
      await tester.pump();
      feedback.nextDialogResult = UnsavedChangesResult.discard;

      await systemBack(tester);

      expect(signedOut, 1);
      expectOnForm();
    });

    testWidgets('kök ekranda (geri dönülecek sayfa yok) "Kaydetmeden çık" '
        'fırlatmaz; leaveScreen etkisizdir', (tester) async {
      await pump(tester, pushForm: false);
      config.dirty.value = true;
      await tester.pump();
      feedback.nextDialogResult = UnsavedChangesResult.discard;

      await tapClose(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(_formKey), findsOneWidget);
      expect(feedback.dialogs, [DialogId.dlg25]);
    });
  });

  group('DLG-25 · UnsavedChangesMixin · gerçek dialogla', () {
    /// Geri bildirimi router'ın kök gezginine bağlı gerçek servisle değiştirir.
    Future<void> useRealFeedback(WidgetTester tester) async {
      final controller = GuToastController();
      addTearDown(controller.dispose);
      await GetIt.I.unregister<FeedbackService>();
      GetIt.I.registerSingleton<FeedbackService>(
        AppFeedbackService(
          navigatorKey: navigatorKey,
          toastController: controller,
        ),
      );
    }

    testWidgets('onSaveRequested yokken "Kaydet" çizilmez; "Kaydetmeden çık" '
        'dokunuşu dialogu kapatır ve ekrandan çıkar', (tester) async {
      await pump(tester);
      await useRealFeedback(tester);
      config.dirty.value = true;
      await tester.pump();

      await systemBack(tester);

      expect(find.byType(GuDialogFrame), findsOneWidget);
      expect(find.byKey(_dialogKey('save')), findsNothing);
      expect(find.byKey(_dialogKey('discard')), findsOneWidget);
      expect(find.byKey(_dialogKey('keep')), findsOneWidget);

      await tester.tap(find.byKey(_dialogKey('discard')));
      await tester.pumpAndSettle();

      expect(find.byType(GuDialogFrame), findsNothing);
      expectLeft();
    });

    testWidgets('onSaveRequested varken "Kaydet" çizilir ve dokunuş kaydeder; '
        '"Düzenlemeye devam et" yalnızca dialogu kapatır', (tester) async {
      await pump(tester);
      await useRealFeedback(tester);
      config
        ..saveResult = true
        ..dirty.value = true;
      await tester.pump();

      await tapClose(tester);
      expect(find.byKey(_dialogKey('save')), findsOneWidget);
      await tester.tap(find.byKey(_dialogKey('keep')));
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsNothing);
      expectOnForm();
      expect(config.saves, 0);

      await tapClose(tester);
      await tester.tap(find.byKey(_dialogKey('save')));
      await tester.pumpAndSettle();

      expect(config.saves, 1);
      expectLeft();
    });

    testWidgets('dialog açıkken sistem geri önce dialogu kapatır (ekran '
        'kalır); ikinci kapatma isteği ikinci dialog açmaz', (tester) async {
      await pump(tester);
      await useRealFeedback(tester);
      config.dirty.value = true;
      await tester.pump();
      final state = tester.state<_FormState>(find.byType(_Form));

      unawaited(state.confirmLeave());
      unawaited(state.confirmLeave());
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsOneWidget);

      await systemBack(tester);

      expect(find.byType(GuDialogFrame), findsNothing);
      expectOnForm();

      // Koruma sıfırlandı: yeni istek yeniden sorar.
      await tapClose(tester);
      expect(find.byType(GuDialogFrame), findsOneWidget);
    });
  });
}
