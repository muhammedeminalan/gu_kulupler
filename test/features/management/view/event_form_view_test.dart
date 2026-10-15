// MGT-05 · Etkinlik formu — içerik (1. adım tasarım yakalaması, 3. adım alt
// çubuğu, yayındaki etkinlikte "Kaydet" + K-F açıklaması), durumlar
// (düzenlemede yükleniyor / hata, yetkisiz, gönderim hatası bandı; boş durum
// yok — K-51), aksiyon envanteri (10 anahtar), aksiyon sonuçları (kapat →
// DLG-25, adımlar, tarih → SHT-28, mekân → SHT-30, yayınla → DLG-22 →
// TST-30 → MGT-04, taslak → TST-13 → MGT-04 "Taslaklar"), cihaz matrisi,
// açık + koyu golden.
// Referans: design/reference-shots/screens/MGT-05__*.webp,
// design/prototype/app/screens-manage.js:86–117.
//
// İki kip (FED-03 testleriyle aynı düzen):
// * **Durum kipi**: ekran `pumpApp` ile çizilir, ViewModel durumu ezilir.
// * **Akış kipi**: gerçek ViewModel, sahte depolar ve yer tutucu rotalar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/event_form_state.dart';
import 'package:gu_kulupler/features/management/provider/event_form_view_model.dart';
import 'package:gu_kulupler/features/management/view/event_form_view.dart';
import 'package:gu_kulupler/features/management/view/widget/place_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_management_repository.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/semantics_scan.dart';
import '../../../helpers/test_l10n.dart';
import '../event_form_test_support.dart';
import '../manage_test_support.dart';

final Key _close = GuKey.action('MGT-05.close');
final Key _next = GuKey.action('MGT-05.next');
final Key _back = GuKey.action('MGT-05.back');
final Key _retry = GuKey.action('MGT-05.retry');
final Key _saveDraft = GuKey.action('MGT-05.saveDraft');
final Key _publish = GuKey.action('MGT-05.publish');
final Key _title = GuKey.action('MGT-05.title');
final Key _place = GuKey.action('MGT-05.place');
final Key _startDate = GuKey.action('MGT-05.startDate');

const String _eventsPath = '/clubs/$kManageClubId/manage/events';
const String _newPath = '$_eventsPath/new';

final EventFormViewModelProvider _provider = eventFormViewModelProvider(
  clubId: kManageClubId,
);

EventFormViewModelProvider _editOf(EventModel event) =>
    eventFormViewModelProvider(clubId: kManageClubId, editEventId: event.id);

const Widget _view = EventFormView(clubId: kManageClubId);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({
  SessionState? session,
  EventFormState? state,
  EventFormViewModelProvider? of,
}) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => session ?? manageSession(),
  ),
  (of ?? _provider).overrideWithBuild(
    (ref, notifier) => state ?? newEventState(),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  SessionState? session,
  EventFormState? state,
  EventModel? edit,
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpApp(
    EventFormView(clubId: kManageClubId, eventId: edit?.id),
    locale: locale,
    overrides: _overrides(
      session: session,
      state: state,
      of: edit == null ? null : _editOf(edit),
    ),
  );
  await tester.pump();
}

/// Akış kipi: ekranı gerçek ViewModel ve yer tutucu rotalarla açar.
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  String path = _newPath,
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    size: const Size(390, 1400),
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: _eventsPath,
          builder: (_, state) => _Stub(state.uri.toString()),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, _) => _view,
            ),
            GoRoute(
              path: ':eventId/edit',
              builder: (_, state) => EventFormView(
                clubId: kManageClubId,
                eventId: state.pathParameters['eventId'],
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/events/:eventId',
          builder: (_, state) => _Stub(state.uri.toString()),
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => manageSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedEventForm();
  router.go(path);
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Future<void> _tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

EventFormState _stateOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(EventFormView)),
).read(_provider);

/// Yer tutucu hedef sayfa: yolunu gösterir.
class _Stub extends StatelessWidget {
  const _Stub(this.path);

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(path));
}

void main() {
  group('MGT-05 · Etkinlik formu · içerik', () {
    testWidgets('1. adım (tasarım yakalaması): başlık "Etkinlik oluştur · '
        '1/3", yalnızca "Devam"', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;
      expect(
        find.text(l10n.eventFormProgress(l10n.eventFormTitle, '1', '3')),
        findsOneWidget,
      );
      expect(find.byType(GuStepbar), findsOneWidget);
      expect(find.byKey(_next), findsOneWidget);
      expect(find.byKey(_back), findsNothing);
      expect(find.byKey(_publish), findsNothing);
      expect(find.text(l10n.eventTypeSosyal), findsOneWidget);
      await expectA11yGuidelines(tester);
    });

    testWidgets('3. adım: "Geri" + "Taslak olarak kaydet" + "Yayınla"', (
      tester,
    ) async {
      await _pump(
        tester,
        state: filledEventState(step: EventFormStep.settings),
      );
      final l10n = tester.l10n;
      expect(find.byKey(_back), findsOneWidget);
      expect(find.byKey(_saveDraft), findsOneWidget);
      expect(
        tester.widget<GuButton>(find.byKey(_publish)).label,
        l10n.eventFormPublish,
      );
    });

    testWidgets('düzenleme, yayında + kayıtlı: "Kaydet"; "Taslak olarak '
        'kaydet" kapalı + K-F açıklaması', (tester) async {
      await _pump(
        tester,
        edit: kPublishedEvent,
        state: filledEventState(
          step: EventFormStep.settings,
        ).copyWith(original: kPublishedEvent),
      );
      final l10n = tester.l10n;
      expect(
        find.text(l10n.eventFormProgress(l10n.eventFormEditTitle, '3', '3')),
        findsOneWidget,
      );
      expect(
        tester.widget<GuButton>(find.byKey(_publish)).label,
        l10n.commonSave,
      );
      expect(tester.widget<GuButton>(find.byKey(_saveDraft)).disabled, isTrue);
      expect(find.text(l10n.sht23UnpublishBlocked), findsOneWidget);
    });
  });

  group('MGT-05 · Etkinlik formu · durumlar', () {
    testWidgets('düzenleme yükleniyor: iskelet, alt çubuk yok', (tester) async {
      await _pump(
        tester,
        edit: kDraftEvent,
        state: const EventFormState(isLoading: true),
      );
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byKey(_next), findsNothing);
    });

    testWidgets('düzenleme hatası: "Yeniden dene"', (tester) async {
      await _pump(
        tester,
        edit: kDraftEvent,
        state: const EventFormState(isError: true),
      );
      expect(find.byType(GuErrorState), findsOneWidget);
      expect(find.byKey(_retry), findsOneWidget);
    });

    testWidgets('danışman: form yok, kilit + "yetkin yok"', (tester) async {
      await _pump(tester, session: manageSession(role: ClubRole.advisor));
      expect(find.text(tester.l10n.mgtNoAccess), findsOneWidget);
      expect(find.byKey(_back), findsOneWidget);
      expect(find.byKey(_next), findsNothing);
    });

    testWidgets('gönderim hatası: tehlike bandı', (tester) async {
      await _pump(
        tester,
        state: newEventState().copyWith(isSubmitError: true),
      );
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.danger);
    });
  });

  group('MGT-05 · Etkinlik formu · aksiyon envanteri', () {
    testWidgets('yönetici bakışı: envanterdeki 10 anahtar birebir', (
      tester,
    ) async {
      await _pump(tester);
      expectActionInventory(tester, 'MGT-05', role: 'manager');
    });
  });

  group('MGT-05 · Etkinlik formu · aksiyonlar', () {
    testWidgets('kapat: değişiklik yokken MGT-04; değişiklik varken DLG-25 — '
        '"Kaydetmeden çık" çıkar', (tester) async {
      var router = await _pumpRoute(tester);
      await _tapKey(tester, _close);
      expect(_location(router), _eventsPath);
      expect(_feedback().dialogs, isEmpty);

      router = await _pumpRoute(tester);
      await tester.enterText(
        find.descendant(
          of: find.byKey(_title),
          matching: find.byType(EditableText),
        ),
        'Ilgaz',
      );
      await tester.pump();
      _feedback().nextDialogResult = UnsavedChangesResult.discard;
      await _tapKey(tester, _close);
      expect(_feedback().dialogs, [DialogId.dlg25]);
      expect(_location(router), _eventsPath);
    });

    testWidgets('adımlar + yayın: başlık → "Devam" → SHT-28 / SHT-30 → '
        '"Devam" → "Yayınla" → DLG-22 → TST-30 + event_new → MGT-04', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _next);
      expect(_stateOf(tester).step, EventFormStep.basics);

      await tester.enterText(
        find.descendant(
          of: find.byKey(_title),
          matching: find.byType(EditableText),
        ),
        'Ilgaz Kayak Günü',
      );
      await tester.pump();
      await _tapKey(tester, _next);
      expect(_stateOf(tester).step, EventFormStep.schedule);

      _feedback().nextSheetResult = DateTime(2026, 10, 25);
      await _tapKey(tester, _startDate);
      expect(_feedback().sheets, [SheetId.sht28]);
      // 25 Ekim 18:00 Istanbul.
      expect(_stateOf(tester).startsAt, DateTime.utc(2026, 10, 25, 15));

      _feedback().nextSheetResult = const PlacePickerResult.place('pl09');
      await _tapKey(tester, _place);
      expect(_stateOf(tester).placeId, 'pl09');
      await _tapKey(tester, _next);
      expect(_stateOf(tester).step, EventFormStep.settings);

      _feedback().dialogResults[DialogId.dlg22] = true;
      await _tapKey(tester, _publish);
      expect(_feedback().dialogs, [DialogId.dlg22]);
      expect(_feedback().toasts, [ToastId.tst30]);
      final management =
          GetIt.I<ManagementRepository>() as FakeManagementRepository;
      expect(management.fanOuts.single.kind, NotificationType.eventNew);
      expect(_location(router), _eventsPath);

      _feedback().tapToastAction();
      await tester.pumpAndSettle();
      expect(_location(router), startsWith('/events/'));
    });

    testWidgets('DLG-22 "Düzenlemeye dön": yayın yok, ekranda kalınır', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EventFormView)),
      );
      container.read(_provider.notifier)
        ..setTitle('Ilgaz')
        ..setPlace(placeId: 'pl09')
        ..next()
        ..next();
      await tester.pumpAndSettle();
      await _tapKey(tester, _publish);
      expect(_feedback().dialogs, [DialogId.dlg22]);
      expect(_feedback().toasts, isEmpty);
      expect(_location(router), _newPath);
    });

    testWidgets('"Taslak olarak kaydet" → TST-13 → MGT-04 "Taslaklar"', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EventFormView)),
      );
      container.read(_provider.notifier)
        ..setTitle('Ilgaz')
        ..setPlace(placeId: 'pl09')
        ..next()
        ..next();
      await tester.pumpAndSettle();
      await _tapKey(tester, _saveDraft);
      expect(_feedback().toasts, [ToastId.tst13]);
      expect(_location(router), '$_eventsPath?tab=draft');
    });
  });

  group('MGT-05 · Etkinlik formu · cihaz matrisi', () {
    Widget view(BuildContext context) => _view;

    testWidgets('1. adım (klavye + güvenli alan)', (tester) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(),
        keyboard: true,
        safeAreas: true,
      );
    });

    testWidgets('2. ve 3. adım, gönderim hatası, yetkisiz', (tester) async {
      for (final state in [
        filledEventState(step: EventFormStep.schedule),
        filledEventState(
          step: EventFormStep.settings,
        ).copyWith(isSubmitError: true),
      ]) {
        await DeviceMatrix.run(
          tester,
          view,
          overrides: _overrides(state: state),
        );
      }
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(session: manageSession(role: ClubRole.advisor)),
      );
    });

    testWidgets('düzenleme: yayında + kilitli zaman, yükleniyor, hata', (
      tester,
    ) async {
      Widget edit(BuildContext context) =>
          EventFormView(clubId: kManageClubId, eventId: kStartedEvent.id);
      for (final state in [
        filledEventState(step: EventFormStep.settings).copyWith(
          original: kStartedEvent,
          timeLocked: true,
        ),
        filledEventState(step: EventFormStep.schedule).copyWith(
          original: kStartedEvent,
          timeLocked: true,
        ),
        const EventFormState(isLoading: true),
        const EventFormState(isError: true),
      ]) {
        await DeviceMatrix.run(
          tester,
          edit,
          overrides: _overrides(state: state, of: _editOf(kStartedEvent)),
        );
      }
    });
  });

  group('MGT-05 · Etkinlik formu · semantik', () {
    testWidgets('3. adım: kaydırma boyunca rol doğrulaması hatasız (görünürlük '
        'GuSegmented; iOS + Android)', (tester) async {
      await expectSemanticsCleanWhileScrolling(
        tester,
        (platform) => tester.pumpApp(
          _view,
          overrides: _overrides(
            state: filledEventState(step: EventFormStep.settings),
          ),
          // 3. adım 390 × 844'e sığar: kısa görünüm + 1.6 + klavye.
          // `SingleChildScrollView`: semantik kırpma tüm içeriği kapsar.
          size: const Size(320, 568),
          textScale: 1.6,
          keyboardInset: 260,
          platform: platform,
        ),
      );
    });
  });

  group('MGT-05 · Etkinlik formu · golden', () {
    testWidgets('varsayılan (yeni etkinlik, 1. adım) açık + koyu', (
      tester,
    ) async {
      await goldenForThemes(
        tester,
        'MGT-05',
        _view,
        overrides: _overrides(),
      );
    });
  });
}
