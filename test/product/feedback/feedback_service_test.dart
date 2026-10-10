// T-07 · AppFeedbackService (CLAUDE.md §7, CD-113): sheet / dialog / menü /
// toast tek girişi. Kimlikler enum'dan seçilir; literal tasarım kimliği
// yazılmaz (TEST01 kanıtı sayılmasın).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/spec_dialog.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/menu_id.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_l10n.dart';

const Key _menuScrimKey = ValueKey<String>('host.menu.scrim');
const Key _bodyKey = ValueKey<String>('host.body');
const Key _pickKey = ValueKey<String>('host.pick');

ToastId _toastWhere(bool Function(ToastSpec spec) test) =>
    ToastId.values.firstWhere((id) => test(ToastCatalog.of(id)));

/// Eylemsiz, başarı türünde, değişkensiz toast.
final ToastId _plain = _toastWhere(
  (s) => s.actionLabel == null && s.kind == GuToastKind.success,
);

/// Eylemsiz, hata türünde toast.
final ToastId _error = _toastWhere(
  (s) => s.actionLabel == null && s.kind == GuToastKind.error,
);

/// "Geri al" eylemli toast.
final ToastId _undo = _toastWhere((s) => s.undoAction);

/// "Geri al" dışı eylemli toast ("Görüntüle" …).
final ToastId _action = _toastWhere(
  (s) => s.actionLabel != null && !s.undoAction,
);

final SheetId _sheet = SheetId.values.first;
final DialogId _dialog = DialogId.values.first;

/// Servis + `GuToastHost` + servisin gezgini.
class _Harness {
  _Harness({this.dialogSpecs = const {}});

  /// Katalog kipi için test kayıtları (gerçek `DialogCatalog` T-07'de boş).
  final Map<DialogId, DialogSpec> dialogSpecs;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GuToastController controller = GuToastController();
  late final AppFeedbackService service = dialogSpecs.isEmpty
      ? AppFeedbackService(
          navigatorKey: navigatorKey,
          toastController: controller,
        )
      : AppFeedbackService(
          navigatorKey: navigatorKey,
          toastController: controller,
          dialogSpecOf: (id) => dialogSpecs[id],
        );

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('tr'),
  }) async {
    addTearDown(controller.dispose);
    await tester.pumpApp(
      GuToastHost(
        controller: controller,
        child: Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
      locale: locale,
    );
  }
}

/// `Future` sonucunu yakalar.
class _Result<T> {
  T? value;
  bool done = false;

  void watch(Future<T?> future) => unawaited(
    future.then((v) {
      value = v;
      done = true;
    }),
  );
}

Key _key(String designId, String action) => FeedbackKeys.of(designId, action);

void main() {
  group('T-07 · AppFeedbackService · toast', () {
    testWidgets('metin ve tür katalogdan; eylemsiz toast 4 sn sonra kapanır', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      h.service.showToast(_plain);
      await tester.pumpAndSettle();

      final spec = ToastCatalog.of(_plain);
      expect(
        find.text(spec.text(tester.l10n, const ToastParams())),
        findsOneWidget,
      );
      final toast = tester.widget<GuToast>(find.byType(GuToast));
      expect(toast.kind, GuToastKind.success);
      expect(toast.actionLabel, isNull);
      expect(toast.closeSemanticLabel, tester.l10n.a11yClose);
      expect(find.byKey(ValueKey<ToastId>(_plain)), findsOneWidget);
      expect(h.controller.current!.effectiveDuration, GuMotion.toastDefault);

      await tester.pump(GuMotion.toastDefault - GuMotion.slow - GuMotion.base);
      expect(h.controller.isVisible, isTrue);
      await tester.pump(GuMotion.slow + GuMotion.base);
      expect(h.controller.isVisible, isFalse);
      await tester.pumpAndSettle();
      expect(find.byType(GuToast), findsNothing);
    });

    testWidgets('hata türü ve EN metni', (tester) async {
      final h = _Harness();
      await h.pump(tester, locale: const Locale('en'));
      h.service.showToast(_error);
      await tester.pumpAndSettle();
      final english = await loadL10n(const Locale('en'));
      expect(
        find.text(ToastCatalog.of(_error).text(english, const ToastParams())),
        findsOneWidget,
      );
      expect(
        tester.widget<GuToast>(find.byType(GuToast)).kind,
        GuToastKind.error,
      );
      expect(
        tester.widget<GuToast>(find.byType(GuToast)).closeSemanticLabel,
        english.a11yClose,
      );
    });

    testWidgets('geri al eylemli toast: değişkenli metin, <ID>.undo, 6 sn', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      var undone = 0;
      const params = ToastParams(name: 'Ayşe', what: 'Gönderi');
      h.service.showToast(_undo, params: params, onAction: () => undone++);
      await tester.pumpAndSettle();

      expect(
        find.text(ToastCatalog.of(_undo).text(tester.l10n, params)),
        findsOneWidget,
      );
      expect(find.text(tester.l10n.commonUndo), findsOneWidget);
      expect(find.byKey(_key(_undo.designId, 'undo')), findsOneWidget);
      expect(h.controller.current!.effectiveDuration, GuMotion.toastUndo);

      // 4 sn'de hâlâ açık, 6 sn'de kapanır.
      await tester.pump(GuMotion.toastDefault);
      expect(h.controller.isVisible, isTrue);
      await tester.pump(GuMotion.toastUndo - GuMotion.toastDefault);
      expect(h.controller.isVisible, isFalse);
      await tester.pumpAndSettle();
      expect(undone, 0);
    });

    testWidgets('eylem dokunuşu toastı kapatır, sonra onAction çağrılır', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      final order = <String>[];
      h.service.showToast(
        _undo,
        onAction: () => order.add('eylem:${h.controller.isVisible}'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_key(_undo.designId, 'undo')));
      await tester.pumpAndSettle();
      expect(order, ['eylem:false']);
      expect(find.byType(GuToast), findsNothing);
    });

    testWidgets('geri al dışı eylem: etiket katalogdan, anahtar <ID>.action', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      var opened = 0;
      h.service.showToast(_action, onAction: () => opened++);
      await tester.pumpAndSettle();
      final label = ToastCatalog.of(_action).actionLabel!(tester.l10n);
      expect(find.text(label), findsOneWidget);
      expect(find.byKey(_key(_action.designId, 'undo')), findsNothing);
      expect(h.controller.current!.effectiveDuration, GuMotion.toastUndo);
      await tester.tap(find.byKey(_key(_action.designId, 'action')));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('onAction verilmezse eylem düğmesi çizilmez ve süre 4 sn', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      h.service.showToast(_undo);
      await tester.pumpAndSettle();
      expect(find.text(tester.l10n.commonUndo), findsNothing);
      expect(find.byKey(_key(_undo.designId, 'undo')), findsNothing);
      expect(h.controller.current!.effectiveDuration, GuMotion.toastDefault);
      h.service.closeToast();
      await tester.pumpAndSettle();
    });

    testWidgets('eylemsiz kayda onAction vermek assert ile durur', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      expect(
        () => h.service.showToast(_plain, onAction: () {}),
        throwsAssertionError,
      );
      expect(h.controller.isVisible, isFalse);
    });

    testWidgets('ikinci toast birincinin yerini alır; süre baştan sayılır', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      final l10n = tester.l10n;
      final first = ToastCatalog.of(_plain).text(l10n, const ToastParams());
      final second = ToastCatalog.of(_error).text(l10n, const ToastParams());
      h.service.showToast(_plain);
      await tester.pumpAndSettle();
      await tester.pump(GuMotion.toastDefault - GuMotion.slow * 2);
      h.service.showToast(_error);
      await tester.pumpAndSettle();
      expect(find.byType(GuToast), findsOneWidget);
      expect(find.text(first), findsNothing);
      expect(find.text(second), findsOneWidget);
      // İlk toastın süresi dolduğu anda ikinci hâlâ açık.
      await tester.pump(GuMotion.slow * 2);
      expect(h.controller.isVisible, isTrue);
      await tester.pump(GuMotion.toastDefault);
      expect(h.controller.isVisible, isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('kapat düğmesi (<ID>.close) ve closeToast toastı kaldırır', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      h.service.showToast(_plain);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_key(_plain.designId, 'close')));
      await tester.pumpAndSettle();
      expect(find.byType(GuToast), findsNothing);

      h.service.showToast(_plain);
      await tester.pumpAndSettle();
      expect(find.byType(GuToast), findsOneWidget);
      h.service.closeToast();
      await tester.pumpAndSettle();
      expect(find.byType(GuToast), findsNothing);
      h.service.closeToast(); // toast yokken etkisiz
    });

    testWidgets('toast açık alt sayfanın üstünde çizilir', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      final result = _Result<void>()
        ..watch(
          h.service.showSheet<void>(
            _sheet,
            builder: (context) => GuSheetFrame(
              title: tester.l10n.commonOk,
              closeSemanticLabel: tester.l10n.a11yClose,
              body: const SizedBox(key: _bodyKey, height: 200),
            ),
          ),
        );
      await tester.pumpAndSettle();
      h.service.showToast(_plain);
      await tester.pumpAndSettle();
      expect(find.byType(GuSheetFrame), findsOneWidget);
      // Kapat düğmesi sheet scrim'inin altında kalmaz: dokunuş toastı kapatır.
      await tester.tap(find.byKey(_key(_plain.designId, 'close')));
      await tester.pumpAndSettle();
      expect(find.byType(GuToast), findsNothing);
      expect(find.byType(GuSheetFrame), findsOneWidget);
      expect(result.done, isFalse);
    });
  });

  group('T-07 · AppFeedbackService · sheet', () {
    testWidgets('içerik çizilir; pop değeri sonuç olur', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      final l10n = tester.l10n;
      final result = _Result<String>()
        ..watch(
          h.service.showSheet<String>(
            _sheet,
            builder: (context) => GuSheetFrame(
              title: l10n.commonOk,
              closeSemanticLabel: l10n.a11yClose,
              body: GuButton(
                key: _pickKey,
                label: l10n.commonOk,
                onPressed: () => Navigator.of(context).pop('seçildi'),
              ),
            ),
          ),
        );
      await tester.pumpAndSettle();
      expect(find.byType(GuSheetFrame), findsOneWidget);
      expect(result.done, isFalse);
      await tester.tap(find.byKey(_pickKey));
      await tester.pumpAndSettle();
      expect(result.done, isTrue);
      expect(result.value, 'seçildi');
      expect(find.byType(GuSheetFrame), findsNothing);
    });

    testWidgets('scrim (<ID>.scrim) null ile kapatır; etiket a11yClose', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      final result = _Result<String>()
        ..watch(
          h.service.showSheet<String>(
            _sheet,
            builder: (context) => GuSheetFrame(
              title: tester.l10n.commonOk,
              closeSemanticLabel: tester.l10n.a11yClose,
              body: const SizedBox(key: _bodyKey, height: 200),
            ),
          ),
        );
      await tester.pumpAndSettle();
      final barrier = tester.widget<ModalBarrier>(
        find.byType(ModalBarrier).last,
      );
      expect(barrier.semanticsLabel, tester.l10n.a11yClose);
      await tester.tap(find.byKey(_key(_sheet.designId, 'scrim')));
      await tester.pumpAndSettle();
      expect(result.done, isTrue);
      expect(result.value, isNull);
      expect(find.byType(GuSheetFrame), findsNothing);
    });

    testWidgets('isDismissible: false → scrim kapatmaz', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      final result = _Result<String>()
        ..watch(
          h.service.showSheet<String>(
            _sheet,
            isDismissible: false,
            builder: (context) => GuSheetFrame(
              title: tester.l10n.commonOk,
              closeSemanticLabel: tester.l10n.a11yClose,
              body: const SizedBox(key: _bodyKey, height: 200),
            ),
          ),
        );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_key(_sheet.designId, 'scrim')));
      await tester.pumpAndSettle();
      expect(result.done, isFalse);
      expect(find.byType(GuSheetFrame), findsOneWidget);
    });
  });

  group('T-07 · AppFeedbackService · dialog', () {
    testWidgets('builder kipi: içerik çizilir; pop değeri sonuç olur', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      final l10n = tester.l10n;
      final result = _Result<String>()
        ..watch(
          h.service.showDialog<String>(
            _dialog,
            builder: (context) => GuDialogFrame(
              title: l10n.commonOk,
              actions: [
                GuButton(
                  key: _pickKey,
                  label: l10n.commonOk,
                  onPressed: () => Navigator.of(context).pop('tamam'),
                ),
              ],
            ),
          ),
        );
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsOneWidget);
      await tester.tap(find.byKey(_pickKey));
      await tester.pumpAndSettle();
      expect(result.value, 'tamam');
      expect(find.byType(GuDialogFrame), findsNothing);
    });

    testWidgets('scrim (<ID>.scrim) null ile kapatır; '
        'barrierDismissible: false kapatmaz', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      Widget frame(BuildContext context) => GuDialogFrame(
        title: tester.l10n.commonOk,
        actions: [GuButton(label: tester.l10n.commonOk, onPressed: () {})],
      );
      final open = _Result<bool>()
        ..watch(h.service.showDialog<bool>(_dialog, builder: frame));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_key(_dialog.designId, 'scrim')));
      await tester.pumpAndSettle();
      expect(open.done, isTrue);
      expect(open.value, isNull);

      final locked = _Result<bool>()
        ..watch(
          h.service.showDialog<bool>(
            _dialog,
            builder: frame,
            barrierDismissible: false,
          ),
        );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_key(_dialog.designId, 'scrim')));
      await tester.pumpAndSettle();
      expect(locked.done, isFalse);
      expect(find.byType(GuDialogFrame), findsOneWidget);
    });

    testWidgets('katalog kipi: kaydı olmayan kimlik StateError', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      expect(DialogCatalog.of(_dialog), isNull);
      expect(
        () => h.service.showDialog<bool>(_dialog),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(_dialog.designId),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(GuDialogFrame), findsNothing);
    });

    testWidgets('katalog kipi: kayıt params ile çizilir; birincil true', (
      tester,
    ) async {
      final h = _Harness(
        dialogSpecs: {
          _dialog: DialogSpec(
            title: (l, p) => l.tst05('${p['name']}'),
            primary: (l) => l.commonOk,
            secondary: (l) => l.commonGiveUp,
          ),
        },
      );
      await h.pump(tester);
      final result = _Result<bool>()
        ..watch(
          h.service.showDialog<bool>(_dialog, params: const {'name': 'Ayşe'}),
        );
      await tester.pumpAndSettle();
      expect(find.byType(SpecDialog), findsOneWidget);
      expect(find.text(tester.l10n.tst05('Ayşe')), findsOneWidget);
      await tester.tap(find.byKey(_key(_dialog.designId, 'confirm')));
      await tester.pumpAndSettle();
      expect(result.value, isTrue);

      // Scrim kapatır → null.
      final dismissed = _Result<bool>()
        ..watch(h.service.showDialog<bool>(_dialog));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_key(_dialog.designId, 'scrim')));
      await tester.pumpAndSettle();
      expect(dismissed.done, isTrue);
      expect(dismissed.value, isNull);
    });

    testWidgets('katalog kipi: dismissible false kayıt scrim ile kapanmaz', (
      tester,
    ) async {
      final h = _Harness(
        dialogSpecs: {
          _dialog: DialogSpec(
            title: (l, _) => l.commonOk,
            primary: (l) => l.commonOk,
            dismissible: false,
          ),
        },
      );
      await h.pump(tester);
      final result = _Result<bool>()
        ..watch(h.service.showDialog<bool>(_dialog));
      await tester.pumpAndSettle();
      final barrier = tester.widget<ModalBarrier>(
        find.byType(ModalBarrier).last,
      );
      expect(barrier.dismissible, isFalse);
      await tester.tap(find.byKey(_key(_dialog.designId, 'scrim')));
      await tester.pumpAndSettle();
      expect(result.done, isFalse);
      await tester.tap(find.byKey(_key(_dialog.designId, 'confirm')));
      await tester.pumpAndSettle();
      expect(result.value, isTrue);
    });

    testWidgets('SpecDialog: metinler, anahtarlar, birincil true / '
        'ikincil false', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      final l10n = tester.l10n;
      final spec = DialogSpec(
        title: (l, p) => l.tst05('${p['name']}'),
        body: (l, _) => l.commonUndo,
        primary: (l) => l.commonOk,
        secondary: (l) => l.commonGiveUp,
        icon: GuIcons.info,
        destructive: true,
      );
      Future<bool?> open() => h.service.showDialog<bool>(
        _dialog,
        builder: (_) => SpecDialog(
          id: _dialog,
          spec: spec,
          params: const {'name': 'Ayşe'},
        ),
      );

      final confirmed = _Result<bool>()..watch(open());
      await tester.pumpAndSettle();
      final frame = tester.widget<GuDialogFrame>(find.byType(GuDialogFrame));
      expect(frame.title, l10n.tst05('Ayşe'));
      expect(frame.body, l10n.commonUndo);
      expect(frame.icon, GuIcons.info);
      expect(frame.danger, isTrue);
      expect(frame.dismissable, isTrue);
      final primary = tester.widget<GuButton>(
        find.byKey(_key(_dialog.designId, 'confirm')),
      );
      expect(primary.label, l10n.commonOk);
      expect(primary.variant, GuButtonVariant.danger);
      final secondary = tester.widget<GuButton>(
        find.byKey(_key(_dialog.designId, 'cancel')),
      );
      expect(secondary.label, l10n.commonGiveUp);
      expect(secondary.variant, GuButtonVariant.text);
      await tester.tap(find.byKey(_key(_dialog.designId, 'confirm')));
      await tester.pumpAndSettle();
      expect(confirmed.value, isTrue);

      final cancelled = _Result<bool>()..watch(open());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_key(_dialog.designId, 'cancel')));
      await tester.pumpAndSettle();
      expect(cancelled.done, isTrue);
      expect(cancelled.value, isFalse);
    });

    testWidgets('SpecDialog: tek düğme, özel sonek, kapatılamaz, birincil '
        'varyant', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      final spec = DialogSpec(
        title: (l, _) => l.commonOk,
        primary: (l) => l.commonOk,
        dismissible: false,
        primaryAction: 'update',
      );
      final result = _Result<bool>()
        ..watch(
          h.service.showDialog<bool>(
            _dialog,
            builder: (_) => SpecDialog(id: _dialog, spec: spec),
          ),
        );
      await tester.pumpAndSettle();
      final frame = tester.widget<GuDialogFrame>(find.byType(GuDialogFrame));
      expect(frame.body, isNull);
      expect(frame.icon, isNull);
      expect(frame.danger, isFalse);
      expect(frame.actions, hasLength(1));
      expect(
        tester
            .widget<GuButton>(find.byKey(_key(_dialog.designId, 'update')))
            .variant,
        GuButtonVariant.primary,
      );
      // dismissible: false → scrim kapatmaz (çerçevenin PopScope'u).
      await tester.tap(find.byKey(_key(_dialog.designId, 'scrim')));
      await tester.pumpAndSettle();
      expect(result.done, isFalse);
      await tester.tap(find.byKey(_key(_dialog.designId, 'update')));
      await tester.pumpAndSettle();
      expect(result.value, isTrue);
    });
  });

  group('T-07 · AppFeedbackService · menü', () {
    testWidgets('açılır; öğe dokunuşu value ile kapatır', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      var tapped = 0;
      final result = _Result<String>()
        ..watch(
          h.service.showMenu<String>(
            id: MenuId.values.last,
            scrimKey: _menuScrimKey,
            items: [
              GuPopMenuItem(
                key: _pickKey,
                label: tester.l10n.commonOk,
                value: 'paylaş',
                onTap: () => tapped++,
              ),
            ],
          ),
        );
      await tester.pumpAndSettle();
      expect(find.byType(GuPopMenu), findsOneWidget);
      await tester.tap(find.byKey(_pickKey));
      await tester.pumpAndSettle();
      expect(result.value, 'paylaş');
      expect(tapped, 1);
      expect(find.byType(GuPopMenu), findsNothing);
    });

    testWidgets('satır içi menü (id: null): çağıranın scrim anahtarı null ile '
        'kapatır', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      final result = _Result<String>()
        ..watch(
          h.service.showMenu<String>(
            scrimKey: _menuScrimKey,
            items: [GuPopMenuItem(label: tester.l10n.commonOk, value: 'x')],
          ),
        );
      await tester.pumpAndSettle();
      expect(find.byType(GuPopMenu), findsOneWidget);
      await tester.tap(find.byKey(_menuScrimKey));
      await tester.pumpAndSettle();
      expect(result.done, isTrue);
      expect(result.value, isNull);
      expect(find.byType(GuPopMenu), findsNothing);
    });
  });

  group('T-07 · AppFeedbackService · gezgin bağlı değil', () {
    testWidgets('çağrılar yok sayılır; overlay çağrıları null döner', (
      tester,
    ) async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.service.showToast(_plain);
      expect(h.controller.isVisible, isFalse);
      expect(
        await h.service.showSheet<String>(
          _sheet,
          builder: (_) => const SizedBox.shrink(),
        ),
        isNull,
      );
      expect(await h.service.showDialog<bool>(_dialog), isNull);
      expect(
        await h.service.showMenu<String>(
          scrimKey: _menuScrimKey,
          items: const [],
        ),
        isNull,
      );
      h.service.closeToast();
    });
  });
}
