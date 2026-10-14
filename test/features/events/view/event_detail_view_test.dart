// EVT-02 · Etkinlik — içerik (kapak, rozetler, tarih / mekân, kontenjan,
// hatırlatıcı, açıklama), aksiyon envanteri, rsvp görünümleri (katılmadı /
// going / waitlist / cancelled / attended; dolu; kayıt kapalı; üyelere özel;
// iptal; bitti; yönetici; danışman), durumlar (yükleniyor, hata), aksiyon
// sonuçları (SHT-12 → katılım, SHT-13, SHT-14, SHT-15, SHT-10, EVT-MENU,
// TST-X2 / TST-X6 / TST-X7, DLG-14 / DLG-16; CLB-03 / EVT-03 / SYS-04 /
// Etkinlikler gezinmesi), cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/EVT-02__*.webp,
// design/prototype/app/screens-events.js:37–75.
//
// * Durum kipi: ViewModel durumu ezilir (okuma yok), saat `kNowUtc`.
// * Akış kipi: gerçek ViewModel + sahte depolar + yer tutucu rotalar.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/event_detail_state.dart';
import 'package:gu_kulupler/features/events/provider/event_detail_view_model.dart';
import 'package:gu_kulupler/features/events/view/event_detail_view.dart';
import 'package:gu_kulupler/features/events/view/widget/event_detail_cta_bar.dart';
import 'package:gu_kulupler/features/events/view/widget/event_menu.dart';
import 'package:gu_kulupler/features/events/view/widget/rsvp_confirm_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/event_menu_sheet.dart'
    as sht23;
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/menu_id.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../fakes/fake_event_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fixtures/event_model_fixtures.dart';
import '../../../fixtures/rsvp_model_fixtures.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../event_detail_test_support.dart';

Key _k(String action) => GuKey.action('EVT-02.$action');

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

/// Durum kipi: oturum + ViewModel durumu + saat ezilir.
List<Override> _overrides({
  EventDetailState? state,
  SessionState session = kVisitorSession,
  String? eventId,
}) => [
  sessionViewModelProvider.overrideWithBuild((ref, notifier) => session),
  eventDetailViewModelProvider(
    eventId ?? state?.event?.id ?? kEvent.id,
  ).overrideWithBuild((ref, notifier) => state ?? loadedState()),
  appClockProvider.overrideWithValue(FakeAppClock(kNowUtc)),
];

Future<void> _pump(
  WidgetTester tester, {
  EventDetailState? state,
  SessionState session = kVisitorSession,
  Locale locale = const Locale('tr'),
}) async {
  final current = state ?? loadedState(session: session);
  await tester.pumpApp(
    eventDetailView(eventId: current.event?.id ?? kEvent.id),
    locale: locale,
    overrides: _overrides(state: current, session: session),
  );
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

GuButton _button(WidgetTester tester, Key key) =>
    tester.widget<GuButton>(find.byKey(key));

/// Akış kipi: gerçek ViewModel ve yer tutucu rotalar.
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  SessionState session = kVisitorSession,
  List<RsvpModel> rsvps = const [],
  List<EventModel>? events,
  String path = '/events/e01',
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/events',
      routes: [
        GoRoute(
          path: '/events',
          builder: (_, _) => const _Stub('/events'),
          routes: [
            GoRoute(
              path: ':eventId',
              builder: (_, state) =>
                  eventDetailView(eventId: state.pathParameters['eventId']),
              routes: [
                GoRoute(
                  path: 'ticket',
                  builder: (_, state) => _Stub(state.uri.path),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/clubs/:clubId',
          builder: (_, state) => _Stub(state.uri.path),
          routes: [
            GoRoute(
              path: 'manage/events/:eventId/edit',
              builder: (_, state) => _Stub(state.uri.path),
            ),
          ],
        ),
        GoRoute(
          path: '/not-found',
          builder: (_, _) => const _Stub('/not-found'),
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild((ref, notifier) => session),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  EventDetailViewModel.resetCancelledNotices();
  seedEvents(events: events, rsvps: rsvps);
  unawaited(router.push(path));
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

class _Stub extends StatelessWidget {
  const _Stub(this.path);

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(path));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });

  setUp(EventDetailViewModel.resetCancelledNotices);

  group('EVT-02 · Etkinlik · içerik', () {
    testWidgets('ziyaretçi: kapak düğmeleri, başlık, kulüp, rozetler, tarih / '
        'mekân, kontenjan, hatırlatıcı, açıklama, "Katıl" (lg)', (
      tester,
    ) async {
      await _pump(tester);
      final l10n = tester.l10n;
      final context = tester.element(find.byType(EventDetailView));
      final gu = context.gu;

      expect(find.byType(GuAppBar), findsNothing);
      expect(find.byType(GuParallaxHeader), findsOneWidget);
      for (final (action, icon) in [
        ('back', GuIcons.arrowLeft),
        ('share', GuIcons.share2),
        ('menu', GuIcons.moreVertical),
      ]) {
        final button = tester.widget<GuIconButton>(find.byKey(_k(action)));
        expect(button.icon, icon);
        expect(button.onCover, isTrue);
      }
      expect(
        tester.widget<Text>(find.text(kEvent.title)).style,
        gu.text.titleL,
      );
      expect(find.text(kClub.name), findsOneWidget);
      final badges = tester
          .widgetList<GuBadge>(find.byType(GuBadge))
          .map((b) => (b.label, b.kind, b.icon))
          .toList();
      expect(badges, [
        (
          StaticLabels.eventType(context, kEvent.type),
          GuBadgeKind.neutral,
          null,
        ),
        (l10n.eventVisibilityPublic, GuBadgeKind.success, GuIcons.globe),
      ]);

      // Tarih / mekân kartı (referans: "9 Ekim Cuma", "18:00–20:00 · 2 sa").
      expect(find.text('9 Ekim Cuma'), findsOneWidget);
      expect(find.text('18:00–20:00 · 2 sa'), findsOneWidget);
      expect(find.text(l10n.eventPlaceCampus), findsOneWidget);
      final place = StaticLabels.place(context, kEvent.placeId!);
      expect(
        tester.widget<GuMapPlaceholder>(find.byType(GuMapPlaceholder)).label,
        l10n.eventMapPlaceholder(place),
      );

      // Kontenjan: 36/40, "4 kişi kaldı", %90 → uyarı çubuğu.
      expect(find.text('36/40'), findsOneWidget);
      expect(find.text(l10n.eventRemaining(4)), findsOneWidget);
      expect(
        tester.widget<GuProgress>(find.byType(GuProgress)).kind,
        GuProgressKind.warning,
      );

      // Hatırlatıcı (kayıt yok) + takvim.
      final reminder = tester.widget<GuTile>(find.byKey(_k('reminder')));
      expect(reminder.subtitle, l10n.eventReminderAfterJoin);
      expect(reminder.chevron, isTrue);
      expect(find.byKey(_k('addToCalendar')), findsOneWidget);

      // Açıklama 3 satır + "Devamı" (168 > 160 karakter).
      expect(tester.widget<Text>(find.text(kEvent.desc)).maxLines, 3);
      await _tap(tester, _k('more'));
      expect(tester.widget<Text>(find.text(kEvent.desc)).maxLines, isNull);
      expect(find.byKey(_k('more')), findsNothing);

      // Alt çubuk: "Katıl" — tam genişlik, büyük.
      final join = _button(tester, _k('join'));
      expect(join.label, l10n.eventCtaJoin);
      expect(join.size, GuButtonSize.lg);
      expect(join.full, isTrue);
      expect(find.byKey(_k('report')), findsOneWidget);
      expect(find.byKey(_k('attendeesPreview')), findsNothing);
    });

    testWidgets('EN metinleri', (tester) async {
      await _pump(tester, locale: const Locale('en'));
      final l10n = tester.l10n;
      expect(find.text(l10n.eventCtaJoin), findsOneWidget);
      expect(find.text(l10n.eventCapacity), findsOneWidget);
    });
  });

  group('EVT-02 · Etkinlik · aksiyon envanteri', () {
    testWidgets('ziyaretçi, yaklaşan herkese açık etkinlik: envanterle '
        'birebir', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'EVT-02', role: 'guest');
    });
  });

  group('EVT-02 · Etkinlik · rsvp görünümleri', () {
    testWidgets('going: "Vazgeç" + "Biletini göster", durum rozeti, '
        'hatırlatıcı tercihi, katılımcı satırı (üye)', (tester) async {
      final session = memberSession();
      await _pump(
        tester,
        session: session,
        state: loadedState(rsvp: kGoing, session: session),
      );
      final l10n = tester.l10n;
      expect(_button(tester, _k('leave')).label, l10n.eventCtaLeave);
      expect(_button(tester, _k('ticket')).label, l10n.eventCtaTicket);
      expect(find.byKey(_k('join')), findsNothing);
      expect(
        tester.widget<GuStatusBadge>(find.byType(GuStatusBadge)).label,
        l10n.statusGoing,
      );
      expect(
        tester.widget<GuTile>(find.byKey(_k('reminder'))).subtitle,
        l10n.reminder1h,
      );
      expect(find.byKey(_k('attendeesPreview')), findsOneWidget);
      // Kayıt listesi katılımcıya kapalı: avatar yok, "+N" hapı; dokunma →
      // TST-X8 (yönetici değil).
      final group = tester.widget<GuAvatarGroup>(find.byType(GuAvatarGroup));
      expect(group.avatars, isEmpty);
      expect(group.moreLabel, '+${kEvent.goingCount}');
      await _tap(tester, _k('attendeesPreview'));
      expect(_feedback().toasts, [ToastId.tstX8]);
      expect(_feedback().toastParams.single.count, kEvent.goingCount);
    });

    testWidgets('waitlist: sıra (katılım anında) / sırasız metin + "Ayrıl"', (
      tester,
    ) async {
      final waiting = kGoing.copyWith(status: RsvpStatus.waitlist);
      await _pump(
        tester,
        state: loadedState(rsvp: waiting, waitlistPosition: 3),
      );
      final l10n = tester.l10n;
      expect(find.text(l10n.eventWaitlistPos(3)), findsOneWidget);
      expect(find.text(l10n.eventWaitlistNote), findsOneWidget);
      expect(_button(tester, _k('leave')).label, l10n.eventCtaLeaveWaitlist);

      await _pump(tester, state: loadedState(rsvp: waiting));
      expect(find.text(l10n.eventWaitlistIn), findsOneWidget);
    });

    testWidgets('cancelled kayıt: yeniden "Katıl"', (tester) async {
      final left = kGoing.copyWith(status: RsvpStatus.cancelled);
      await _pump(tester, state: loadedState(rsvp: left));
      expect(_button(tester, _k('join')).label, tester.l10n.eventCtaJoin);
      expect(find.byType(GuStatusBadge), findsNothing);
    });

    testWidgets('dolu (joinsWaitlist) → "Bekleme listesine katıl" (tonal, '
        'kum saati); "Kontenjan doldu · 4 kişi bekliyor"', (tester) async {
      final full = EventModelFixtures.e03;
      await _pump(tester, state: loadedState(event: full));
      final l10n = tester.l10n;
      final button = _button(tester, _k('waitlist'));
      expect(button.label, l10n.eventCtaWaitlist);
      expect(button.variant, GuButtonVariant.tonal);
      expect(button.icon, GuIcons.hourglass);
      expect(
        find.text('${l10n.eventFull} · ${l10n.eventWaitlistCount(4)}'),
        findsOneWidget,
      );
    });

    testWidgets('kayıt kapalı → devre dışı "Kayıtlar kapalı" → TST-X2', (
      tester,
    ) async {
      await _pump(
        tester,
        state: loadedState(event: kEvent.copyWith(registrationOpen: false)),
      );
      final button = _button(tester, _k('join'));
      expect(button.label, tester.l10n.eventCtaClosed);
      expect(button.disabled, isTrue);
      await _tap(tester, _k('join'));
      expect(_feedback().toasts, [ToastId.tstX2]);
    });

    testWidgets('üyelere özel, içini görmeyen → "Kulübe başvur"', (
      tester,
    ) async {
      await _pump(tester, state: loadedState(event: EventModelFixtures.e02));
      final l10n = tester.l10n;
      expect(_button(tester, _k('applyClub')).label, l10n.eventCtaApplyClub);
      expect(find.text(l10n.eventVisibilityMembers), findsOneWidget);
    });

    testWidgets('iptal: üst + alt bant, hatırlatıcı kartı yok, çubuk yok; '
        'DLG-16 açılışta', (tester) async {
      final cancelled = EventModelFixtures.e21;
      await _pump(tester, state: loadedState(event: cancelled));
      final l10n = tester.l10n;
      final text = l10n.eventCancelledBannerReason(l10n.cancelReasonWeather);
      expect(find.text(text), findsNWidgets(2));
      expect(find.byKey(_k('reminder')), findsNothing);
      expect(find.byType(GuStickyCta), findsNothing);
      await tester.pump();
      expect(_feedback().dialogs, [DialogId.dlg16]);
    });

    testWidgets('bitti: "Etkinlik sona erdi" (TST-X6) / attended → '
        '"Katıldın" rozeti', (tester) async {
      final past = EventModelFixtures.e19;
      await _pump(tester, state: loadedState(event: past));
      expect(_button(tester, _k('ended')).disabled, isTrue);
      expect(find.byKey(_k('reminder')), findsNothing);
      await _tap(tester, _k('ended'));
      expect(_feedback().toasts, [ToastId.tstX6]);

      final attended = RsvpModelFixtures.e18Mehmet;
      await _pump(
        tester,
        state: loadedState(event: EventModelFixtures.e19, rsvp: attended),
      );
      expect(find.byKey(_k('ended')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(EventDetailCtaBar),
          matching: find.text(tester.l10n.statusAttended),
        ),
        findsOneWidget,
      );
    });

    testWidgets('yönetici: Düzenle · Katılımcılar · Yoklama, şikayet yok; '
        'danışman: salt okunur bandı', (tester) async {
      final manager = memberSession(role: ClubRole.board);
      await _pump(tester, session: manager);
      for (final action in ['edit', 'attendees', 'scan']) {
        expect(find.byKey(_k(action)), findsOneWidget);
      }
      expect(find.byKey(_k('report')), findsNothing);

      final advisor = memberSession(role: ClubRole.advisor);
      await _pump(tester, session: advisor);
      expect(find.text(tester.l10n.mgtReadOnlyBanner), findsOneWidget);
      expect(find.byType(GuStickyCta), findsNothing);
      expect(find.byKey(_k('report')), findsNothing);
    });
  });

  group('EVT-02 · Etkinlik · durumlar', () {
    testWidgets('yükleniyor: başlık çubuğu + iskelet', (tester) async {
      await _pump(tester, state: const EventDetailState(isFetching: true));
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byKey(_k('back')), findsOneWidget);
    });

    testWidgets('hata: "Yeniden dene"', (tester) async {
      await _pump(tester, state: const EventDetailState(isError: true));
      expect(find.byType(GuErrorState), findsOneWidget);
      expect(find.byKey(_k('retry')), findsOneWidget);
    });
  });

  group('EVT-02 · Etkinlik · aksiyonlar', () {
    testWidgets('yönetici (W-27): "Düzenle" → MGT-05; "⋮" → SHT-23 → '
        '"Çoğalt" → TST-13 → kopyanın MGT-05\'i', (tester) async {
      final router = await _pumpRoute(
        tester,
        session: memberSession(role: ClubRole.board),
      );
      final editPath = '/clubs/${kEvent.clubId}/manage/events';
      await _tap(tester, _k('edit'));
      await tester.pumpAndSettle();
      expect(_location(router), '$editPath/${kEvent.id}/edit');

      unawaited(router.push('/events/${kEvent.id}'));
      await tester.pumpAndSettle();
      final feedback = _feedback()
        ..nextSheetResult = sht23.EventMenuAction.duplicate;
      await _tap(tester, _k('menu'));
      await tester.pumpAndSettle();
      expect(feedback.sheets, [SheetId.sht23]);
      expect(feedback.toasts, [ToastId.tst13]);
      final copy =
          (GetIt.I<EventRepository>() as FakeEventRepository).created.single;
      expect(copy.startsAt, kEvent.startsAt.add(const Duration(days: 7)));
      expect(_location(router), '$editPath/${copy.id}/edit');
    });

    testWidgets('"Katıl" → SHT-12 (çipler, varsayılan 1 sa) → katılım → '
        'TST-41', (tester) async {
      await _pump(tester);
      seedEvents();
      final feedback = _feedback()..nextSheetResult = ReminderOption.oneDay;
      await _tap(tester, _k('join'));
      await tester.pumpAndSettle();
      expect(feedback.sheets, [SheetId.sht12]);
      expect(feedback.toasts.last, ToastId.tst41);
      final state = ProviderScope.containerOf(
        tester.element(find.byType(EventDetailView)),
      ).read(eventDetailViewModelProvider(kEvent.id));
      expect(state.rsvp?.reminder, ReminderOption.oneDay);
      expect(find.byKey(_k('ticket')), findsOneWidget);

      // SHT-12 gövdesi.
      await tester.pumpApp(
        Builder(builder: feedback.lastSheetBuilder!),
        overrides: [appClockProvider.overrideWithValue(FakeAppClock(kNowUtc))],
      );
      final chips = tester.widgetList<GuChip>(find.byType(GuChip)).toList();
      expect(chips.map((c) => c.key), [
        for (final option in RsvpConfirmSheet.options)
          RsvpConfirmSheet.reminderKeyOf(option),
      ]);
      expect(chips.map((c) => c.selected), [false, true, false]);
    });

    testWidgets('hatırlatıcı (kayıt yok) → TST-X7; takvim → SHT-14; paylaş → '
        'SHT-15; şikayet → SHT-10; yol tarifi → DLG-32', (tester) async {
      await _pump(tester);
      final feedback = _feedback();
      await _tap(tester, _k('reminder'));
      expect(feedback.toasts, [ToastId.tstX7]);
      expect(feedback.sheets, isEmpty);
      await _tap(tester, _k('addToCalendar'));
      await _tap(tester, _k('share'));
      await _tap(tester, _k('report'));
      expect(feedback.sheets, [SheetId.sht14, SheetId.sht15, SheetId.sht10]);
      await _tap(tester, _k('directions'));
      expect(feedback.dialogs, [DialogId.dlg32]);
    });

    testWidgets('⋮ → EVT-MENU (kayıtsız: hatırlatıcı yok); "Takvime ekle" '
        '→ SHT-14', (tester) async {
      await _pump(tester);
      final feedback = _feedback()..nextMenuResult = EventMenuAction.calendar;
      await _tap(tester, _k('menu'));
      expect(feedback.menus, [MenuId.evtMenu]);
      expect(
        feedback.lastMenuItems.map((item) => item.key),
        [
          EventMenu.keyOf(EventMenuAction.calendar),
          EventMenu.keyOf(EventMenuAction.share),
          EventMenu.keyOf(EventMenuAction.report),
        ],
      );
      expect(feedback.sheets, [SheetId.sht14]);
    });

    testWidgets('going → "Vazgeç" → DLG-14 (bekleme metni değil)', (
      tester,
    ) async {
      final session = memberSession();
      await _pump(
        tester,
        session: session,
        state: loadedState(rsvp: kGoing, session: session),
      );
      (GetIt.I<AppClock>() as FakeAppClock).set(kNowUtc);
      await _tap(tester, _k('leave'));
      expect(_feedback().dialogs, [DialogId.dlg14]);
    });

    testWidgets('gezinme: kulüp → CLB-03, bilet → EVT-03, geri', (
      tester,
    ) async {
      var router = await _pumpRoute(tester, rsvps: [kGoing]);
      await _tap(tester, _k('club'));
      await tester.pumpAndSettle();
      expect(_location(router), '/clubs/${kEvent.clubId}');

      router = await _pumpRoute(tester, rsvps: [kGoing]);
      await _tap(tester, _k('ticket'));
      await tester.pumpAndSettle();
      expect(_location(router), '/events/${kEvent.id}/ticket');

      router = await _pumpRoute(tester);
      await _tap(tester, _k('back'));
      await tester.pumpAndSettle();
      expect(_location(router), '/events');
    });

    testWidgets('derin bağlantı: okuma izni yok → TST-X18 + Etkinlikler '
        '(CD-57); silinmiş → SYS-04', (tester) async {
      var router = await _pumpRoute(tester, events: const []);
      expect(_location(router), '/events');
      expect(_feedback().toasts, [ToastId.tstX18]);

      router = await _pumpRoute(
        tester,
        events: [kEvent.copyWith(isDeleted: true)],
      );
      expect(_location(router), '/not-found');
    });
  });

  group('EVT-02 · Etkinlik · cihaz matrisi', () {
    testWidgets('ziyaretçi + kayıtlı görünüm', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => eventDetailView(),
        overrides: _overrides(),
        safeAreas: true,
      );
      final session = memberSession();
      await DeviceMatrix.run(
        tester,
        (_) => eventDetailView(),
        overrides: _overrides(
          session: session,
          state: loadedState(rsvp: kGoing, session: session),
        ),
      );
    });
  });

  group('EVT-02 · Etkinlik · golden', () {
    testWidgets('ziyaretçi (referans: e01) açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'EVT-02',
        eventDetailView(),
        overrides: _overrides(),
      );
    });
  });
}
