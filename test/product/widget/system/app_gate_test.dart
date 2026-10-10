// DLG-26 · Güncelleme gerekli ve DLG-27 · Oturumun sona erdi — kök kapı
// katmanı (AppGate): hangi bayrakta hangi dialog, öncelik, onay sonuçları
// (mağaza / oturumu kapat), kapatılamazlık ve rota düşürmesinden sonra
// yeniden gösterim. Referans: design/reference-shots/dialogs/DLG-26__*.webp,
// DLG-27__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/init/app_gate_state.dart';
import 'package:gu_kulupler/product/init/app_gate_view_model.dart';
import 'package:gu_kulupler/product/widget/system/app_gate.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_auth_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_remote_config_service.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

const Key _childKey = ValueKey<String>('gate.child');
const Widget _child = SizedBox.expand(key: _childKey);

Override _gate(AppGateState state) =>
    appGateViewModelProvider.overrideWithBuild((ref, notifier) => state);

const _updateRequired = AppGateState(
  minSupportedBuild: 9,
  currentBuild: 1,
  isUpdateRequired: true,
);
const _sessionExpired = AppGateState(isSessionExpired: true);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppGate)));

AppGateState _state(WidgetTester tester) =>
    _container(tester).read(appGateViewModelProvider);

AppGateViewModel _notifier(WidgetTester tester) =>
    _container(tester).read(appGateViewModelProvider.notifier);

FakeAuthService _auth() => GetIt.I<AuthService>() as FakeAuthService;

/// [body] boyunca `AppLogger` satırlarını toplar. `debugPrint` gövde bitmeden
/// geri alınır (flutter_test hata ayıklama değişkenlerini gövde sonunda
/// denetler).
Future<List<String>> _captureLogs(Future<void> Function() body) async {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return logs;
}

/// Sahte servisle çizer: kapı ilk karenin ardından dialog ister, bu yüzden
/// sonuç ([FakeFeedbackService.nextDialogResult]) çizimden **önce** kurulur.
Future<FakeFeedbackService> _pumpGate(
  WidgetTester tester, {
  AppGateState? state,
  Object? firstResult,
}) async {
  final feedback = FakeFeedbackService()..nextDialogResult = firstResult;
  await tester.pumpApp(
    const AppGate(child: _child),
    overrides: [
      if (state != null) _gate(state),
      feedbackServiceProvider.overrideWithValue(feedback),
    ],
  );
  await tester.pump();
  return feedback;
}

/// Gerçek `AppFeedbackService` + kendi gezgini: dialoglar gerçekten çizilir.
class _RealHarness {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GuToastController controller = GuToastController();

  Future<void> pump(WidgetTester tester, AppGateState state) async {
    addTearDown(controller.dispose);
    await tester.pumpApp(
      AppGate(
        child: Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: _child),
          ),
        ),
      ),
      overrides: [
        _gate(state),
        feedbackServiceProvider.overrideWithValue(
          AppFeedbackService(
            navigatorKey: navigatorKey,
            toastController: controller,
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  group('DLG-26 · DLG-27 · AppGate (kapı seçimi)', () {
    testWidgets('kapı kapalıyken dialog yok; içerik olduğu gibi çizilir', (
      tester,
    ) async {
      final feedback = await _pumpGate(tester);
      await tester.pumpAndSettle();
      expect(feedback.dialogs, isEmpty);
      expect(find.byKey(_childKey), findsOneWidget);
    });

    testWidgets('açılışta güncelleme zorunluysa DLG-26 gösterilir', (
      tester,
    ) async {
      final feedback = await _pumpGate(tester, state: _updateRequired);
      expect(feedback.dialogs, [DialogId.dlg26]);
    });

    testWidgets('Remote Config sonradan güncelleme isterse DLG-26 gösterilir', (
      tester,
    ) async {
      final feedback = await _pumpGate(tester);
      await tester.pumpAndSettle();
      expect(feedback.dialogs, isEmpty);

      final config = GetIt.I<RemoteConfigService>() as FakeRemoteConfigService;
      config.values[RemoteConfigKeys.minSupportedBuild] = 99;
      config.configUpdatedController.add(null);
      await tester.pump();
      await tester.pump();
      expect(_state(tester).isUpdateRequired, isTrue);
      expect(feedback.dialogs, [DialogId.dlg26]);
    });

    testWidgets('oturum sona erince DLG-27 gösterilir', (tester) async {
      final feedback = await _pumpGate(tester);
      await tester.pumpAndSettle();
      _notifier(tester).onSessionExpired();
      await tester.pump();
      expect(feedback.dialogs, [DialogId.dlg27]);
    });

    testWidgets('iki kapı birden açıksa önce güncelleme (DLG-26)', (
      tester,
    ) async {
      final feedback = await _pumpGate(
        tester,
        state: _updateRequired.copyWith(isSessionExpired: true),
      );
      expect(feedback.dialogs, [DialogId.dlg26]);
    });

    testWidgets('dialog çizilmeden dönerse (gezgin hazır değil) kare başına '
        'yeniden denenmez; üst katman yeniden kurulunca denenir', (
      tester,
    ) async {
      final feedback = FakeFeedbackService();
      final overrides = [
        _gate(_updateRequired),
        feedbackServiceProvider.overrideWithValue(feedback),
      ];
      // Her kurulum yeni bir `AppGate` widget'ıdır (aynı öğe güncellenir).
      Widget tree(int revision) => ProviderScope(
        overrides: overrides,
        child: AppGate(child: SizedBox(key: ValueKey<int>(revision))),
      );
      await tester.pumpWidget(tree(0));
      for (var i = 0; i < 5; i++) {
        await tester.pump(GuMotion.base);
      }
      expect(feedback.dialogs, [DialogId.dlg26]);

      // Üst katmanın yeniden kurulması (ör. rota değişimi) yeni bir denemedir.
      await tester.pumpWidget(tree(1));
      await tester.pump();
      expect(feedback.dialogs, [DialogId.dlg26, DialogId.dlg26]);
    });
  });

  group('DLG-26 · Güncelleme gerekli', () {
    testWidgets('"Güncelle" mağazayı açar (W-55: bağlantı T-13’te) ve kapı '
        'açık kaldığı için dialog yeniden gösterilir', (tester) async {
      late FakeFeedbackService feedback;
      final logs = await _captureLogs(() async {
        feedback = await _pumpGate(
          tester,
          state: _updateRequired,
          firstResult: true,
        );
        await tester.pump();
      });
      expect(logs.join('\n'), contains('W-55'));
      expect(feedback.dialogs, [DialogId.dlg26, DialogId.dlg26]);
      expect(_state(tester).isUpdateRequired, isTrue);
    });

    testWidgets('çizim: ikon, başlık, gövde, tek düğme `DLG-26.update`; scrim '
        've geri tuşu kapatmaz', (tester) async {
      final h = _RealHarness();
      await h.pump(tester, _updateRequired);
      final l10n = tester.l10n;
      final frame = tester.widget<GuDialogFrame>(find.byType(GuDialogFrame));
      expect(frame.title, l10n.dlg26Title);
      expect(frame.body, l10n.dlg26Body);
      expect(frame.icon, GuIcons.download);
      expect(frame.danger, isFalse);
      expect(frame.dismissable, isFalse);
      expect(frame.actions, hasLength(1));
      final update = FeedbackKeys.of('DLG-26', 'update');
      expect(
        tester.widget<GuButton>(find.byKey(update)).label,
        l10n.dlg26Update,
      );

      await tester.tap(
        find.byKey(FeedbackKeys.of('DLG-26', 'scrim')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsOneWidget);
    });

    testWidgets('"Güncelle"den sonra da ekranda kalır', (tester) async {
      final h = _RealHarness();
      await h.pump(tester, _updateRequired);
      final logs = await _captureLogs(() async {
        await tester.tap(find.byKey(FeedbackKeys.of('DLG-26', 'update')));
        await tester.pumpAndSettle();
      });
      expect(logs.join('\n'), contains('W-55'));
      expect(
        tester.widget<GuDialogFrame>(find.byType(GuDialogFrame)).title,
        tester.l10n.dlg26Title,
      );
    });

    testWidgets('alttaki sayfa dialogu düşürürse (yönlendirme) yeniden '
        'gösterilir', (tester) async {
      final h = _RealHarness();
      await h.pump(tester, _updateRequired);
      expect(find.byType(GuDialogFrame), findsOneWidget);

      // Rota değişimi dialog rotasını sonuçsuz kapatır.
      h.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsOneWidget);
    });

    testWidgets('kapı kalkınca (güncelleme yapıldı) yeniden gösterilmez', (
      tester,
    ) async {
      final h = _RealHarness();
      await h.pump(tester, _updateRequired);
      final gate = _notifier(tester);
      gate.state = gate.state.copyWith(isUpdateRequired: false);
      h.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsNothing);
    });
  });

  group('DLG-27 · Oturumun sona erdi', () {
    testWidgets('"Giriş yap" oturumu kapatır ve bayrağı indirir; dialog '
        'yeniden gösterilmez', (tester) async {
      final feedback = await _pumpGate(
        tester,
        state: _sessionExpired,
        firstResult: true,
      );
      await tester.pumpAndSettle();
      expect(feedback.dialogs, [DialogId.dlg27]);
      expect(_auth().callsTo('signOut'), hasLength(1));
      expect(_state(tester).isSessionExpired, isFalse);
    });

    testWidgets('çizim: ikon, başlık, gövde, tek düğme `DLG-27.login`; scrim '
        've geri tuşu kapatmaz; "Giriş yap" kapatır', (tester) async {
      final h = _RealHarness();
      await h.pump(tester, _sessionExpired);
      final l10n = tester.l10n;
      final frame = tester.widget<GuDialogFrame>(find.byType(GuDialogFrame));
      expect(frame.title, l10n.dlg27Title);
      expect(frame.body, l10n.dlg27Body);
      expect(frame.icon, GuIcons.lock);
      expect(frame.dismissable, isFalse);
      expect(frame.actions, hasLength(1));
      final login = FeedbackKeys.of('DLG-27', 'login');
      expect(
        tester.widget<GuButton>(find.byKey(login)).label,
        l10n.authLoginCta,
      );

      await tester.tap(
        find.byKey(FeedbackKeys.of('DLG-27', 'scrim')),
        warnIfMissed: false,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsOneWidget);

      await tester.tap(find.byKey(login));
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsNothing);
      expect(_auth().callsTo('signOut'), hasLength(1));
      expect(_state(tester).isSessionExpired, isFalse);
    });

    testWidgets('oturum kapatılamazsa kapı açık kalır ve DLG-27 yeniden '
        'gösterilir; sonraki denemede kapanır', (tester) async {
      final h = _RealHarness();
      await h.pump(tester, _sessionExpired);
      final login = FeedbackKeys.of('DLG-27', 'login');

      _auth().failNext(AuthError.network);
      final logs = await _captureLogs(() async {
        await tester.tap(find.byKey(login));
        await tester.pumpAndSettle();
      });
      expect(logs.join('\n'), contains('Oturum kapatılamadı'));
      expect(_auth().callsTo('signOut'), hasLength(1));
      // Bayrak inmedi: kullanıcı ölü oturumla uygulamada bırakılmaz.
      expect(_state(tester).isSessionExpired, isTrue);
      expect(
        tester.widget<GuDialogFrame>(find.byType(GuDialogFrame)).title,
        tester.l10n.dlg27Title,
      );

      await tester.tap(find.byKey(login));
      await tester.pumpAndSettle();
      expect(_auth().callsTo('signOut'), hasLength(2));
      expect(_state(tester).isSessionExpired, isFalse);
      expect(find.byType(GuDialogFrame), findsNothing);
    });

    testWidgets('DLG-27 kapanınca bekleyen güncelleme kapısı (DLG-26) açılır', (
      tester,
    ) async {
      final h = _RealHarness();
      await h.pump(tester, _sessionExpired);
      // DLG-27 ekrandayken güncelleme de zorunlu olur: sıra ona onaydan sonra
      // gelir (aynı anda tek kapı dialogu).
      final gate = _notifier(tester);
      gate.state = gate.state.copyWith(isUpdateRequired: true);
      await tester.pumpAndSettle();
      expect(
        tester.widget<GuDialogFrame>(find.byType(GuDialogFrame)).title,
        tester.l10n.dlg27Title,
      );

      await tester.tap(find.byKey(FeedbackKeys.of('DLG-27', 'login')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GuDialogFrame>(find.byType(GuDialogFrame)).title,
        tester.l10n.dlg26Title,
      );
    });
  });
}
