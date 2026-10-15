// MGT-06 · Katılımcılar ve yoklama — içerik (tasarım yakalaması: u_elif →
// c01 / e17, 52 kayıt, "Kayıtlı 52 · Katıldın 5 · Gelmedi 47", "Yoklama
// %10"), durumlar (yükleniyor, hata, boş, danışman bandı, yoklama penceresi
// bantları — K-G), aksiyon envanteri (61 anahtar), temel aksiyon sonuçları
// (anahtar → TST-31; "⋮" → DLG-17 → TST-31 / kayıt kapat → TST-X15;
// kontenjan dolu "Kayıtlıya al" → TST-X14; QR → MGT-07; etkinlik değiştir;
// geri → MGT-04), cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/MGT-06__*.webp,
// design/prototype/app/screens-manage.js:121–139.
//
// İki kip (MGT-03 testleriyle aynı düzen):
// * **Durum kipi**: ekran `pumpApp` ile çizilir, ViewModel durumu ezilir.
// * **Akış kipi**: gerçek ViewModel, sahte depolar ve yer tutucu rotalar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/attendance_state.dart';
import 'package:gu_kulupler/features/management/provider/attendance_view_model.dart';
import 'package:gu_kulupler/features/management/view/attendance_view.dart';
import 'package:gu_kulupler/features/management/view/mixin/attendance_view_mixin.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/widget/member/attendee_row.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../attendance_test_support.dart';

final Key _back = GuKey.action('MGT-06.back');
final Key _retry = GuKey.action('MGT-06.retry');
final Key _menu = GuKey.action('MGT-06.menu');
final Key _scan = GuKey.action('MGT-06.scan');
final Key _switchEvent = GuKey.action('MGT-06.switchEvent');

Key _attended(String id) => GuKey.action('MGT-06.attended.$id');
Key _promote(String id) => GuKey.action('MGT-06.promote.$id');

/// 52 satırın hepsi kurulsun diye uzun yüzey.
const Size _tall = Size(390, 6400);

const String _eventsPath = '/clubs/$kAttendanceClubId/manage/events';
const String _path = '$_eventsPath/$kAttendanceEventId/attendance';

final AttendanceViewModelProvider _provider = attendanceViewModelProvider(
  kAttendanceClubId,
  kAttendanceEventId,
);

const Widget _view = AttendanceView(
  clubId: kAttendanceClubId,
  eventId: kAttendanceEventId,
);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({SessionState? session, AttendanceState? state}) => [
  appClockProvider.overrideWithValue(FakeAppClock(kInWindowNow)),
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => session ?? attendanceSession(),
  ),
  _provider.overrideWithBuild(
    (ref, notifier) => state ?? loadedAttendanceState(),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  SessionState? session,
  AttendanceState? state,
  Size size = _tall,
}) async {
  await tester.pumpApp(
    _view,
    size: size,
    overrides: _overrides(session: session, state: state),
  );
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel + yer tutucu rotalar.
Future<GoRouter> _pumpRoute(WidgetTester tester) async {
  GoRouter? created;
  Widget stub(GoRouterState state) => _Stub(state.uri.toString());
  await tester.pumpAppRouter(
    size: _tall,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, s) => stub(s)),
        GoRoute(
          path: _eventsPath,
          builder: (_, s) => stub(s),
          routes: [
            GoRoute(
              path: ':eventId/attendance',
              builder: (_, s) => AttendanceView(
                clubId: kAttendanceClubId,
                eventId: s.pathParameters['eventId']!,
              ),
              routes: [GoRoute(path: 'scan', builder: (_, s) => stub(s))],
            ),
          ],
        ),
      ],
    ),
    overrides: [
      appClockProvider.overrideWithValue(FakeAppClock(kInWindowNow)),
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => attendanceSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedAttendance();
  router.go(_path);
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

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

AttendeeRow _row(WidgetTester tester, String userId) => tester
    .widgetList<AttendeeRow>(find.byType(AttendeeRow))
    .firstWhere((r) => r.rsvp.userId == userId);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });

  group('MGT-06 · Katılımcılar ve yoklama · içerik', () {
    testWidgets('dolu: başlık, 4 çip ("Kayıtlı 52"…), "Yoklama %10", 52 '
        'satır ada göre, kendi kaydı kilitli, bekleme listesi boş', (
      tester,
    ) async {
      await _pump(tester);
      final l10n = tester.l10n;
      expect(find.text('Veri Bilimi Söyleşisi'), findsOneWidget);
      expect(
        find.textContaining(kAttendanceClub.name, findRichText: true),
        findsOneWidget,
      );
      expect(find.text(l10n.attendanceSummaryChip('Kayıtlı', 52)), findsOne);
      expect(find.text(l10n.attendanceSummaryChip('Gelmedi', 47)), findsOne);
      expect(find.text(l10n.attendanceRateValue('%10')), findsOneWidget);
      final rows = tester.widgetList<AttendeeRow>(find.byType(AttendeeRow));
      expect(rows, hasLength(52));
      expect(rows.first.name, 'Alp Aksoy');
      final own = _row(tester, kAttendanceUid);
      expect(own.isSelf, isTrue);
      expect(own.onToggle, isNull);
      expect(_row(tester, rows.first.rsvp.userId).readOnly, isFalse);
      expect(find.byKey(_scan), findsOneWidget);
      expect(find.byType(GuBanner), findsNothing);
      expect(find.text(l10n.attendanceNoWaitlist), findsOneWidget);
      await expectA11yGuidelines(tester);
    });

    testWidgets('danışman: salt okunur bandı, QR yok; anahtar → TST-26', (
      tester,
    ) async {
      await _pump(
        tester,
        session: attendanceSession(role: ClubRole.advisor),
        state: loadedAttendanceState(access: ClubAccess.advisor),
      );
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.readonly);
      expect(find.byKey(_scan), findsNothing);
      await _tapKey(tester, _attended('u008'));
      expect(_feedback().toasts, [ToastId.tst26]);
    });

    testWidgets('yoklama penceresi (K-G): önce / sonra bandı, anahtarlar '
        'kilitli; başlamadıysa yalnızca bant', (tester) async {
      await _pump(
        tester,
        state: loadedAttendanceState(phase: AttendancePhase.beforeWindow),
      );
      final l10n = tester.l10n;
      expect(find.text(l10n.attendanceWindowNotOpen(2)), findsOneWidget);
      expect(_row(tester, 'u008').readOnly, isTrue);
      await _pump(
        tester,
        state: loadedAttendanceState(phase: AttendancePhase.closed),
      );
      expect(find.text(l10n.attendanceWindowClosed(6)), findsOneWidget);
      expect(_row(tester, 'u008').readOnly, isTrue);
      await _pump(
        tester,
        state: loadedAttendanceState(phase: AttendancePhase.beforeStart),
      );
      expect(find.text(l10n.attendanceNotStarted), findsOneWidget);
      expect(_row(tester, 'u008').readOnly, isFalse);
    });

    testWidgets('yükleniyor → iskelet; hata → "Yeniden dene"; kayıt yok → '
        '"Henüz kayıt yok"', (tester) async {
      await _pump(tester, state: const AttendanceState(isFetching: true));
      expect(find.byType(GuSkeletonList), findsOneWidget);
      await _pump(tester, state: const AttendanceState(isError: true));
      expect(find.byKey(_retry), findsOneWidget);
      await _pump(tester, state: loadedAttendanceState(rsvps: const []));
      expect(find.text(tester.l10n.attendanceEmpty), findsOneWidget);
    });

    testWidgets('bekleme listesi: sıra + "Kayıtlıya al"; kontenjan dolu → '
        'devre dışı, dokunuş TST-X14', (tester) async {
      final rsvps = [...attendanceRsvps(), waitlisted('u_mehmet')];
      await _pump(
        tester,
        state: loadedAttendanceState(
          rsvps: rsvps,
          event: kAttendanceEvent.copyWith(capacity: 52),
          summary: AttendanceSummaryFilter.waitlist,
        ),
      );
      final waiting = tester.widget<AttendeeRow>(find.byType(AttendeeRow));
      expect(
        (waiting.rsvp.status, waiting.waitlistPosition),
        (
          RsvpStatus.waitlist,
          1,
        ),
      );
      await _tapKey(tester, _promote('u_mehmet'));
      expect(_feedback().toasts, [ToastId.tstX14]);
    });
  });

  group('MGT-06 · Katılımcılar ve yoklama · envanter', () {
    testWidgets('61 anahtar (yönetici bakışı)', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'MGT-06', role: 'manager');
    });
  });

  group('MGT-06 · Katılımcılar ve yoklama · aksiyonlar', () {
    testWidgets('anahtar → TST-31; "⋮" → DLG-17 → TST-31; kayıt kapat → '
        'TST-X15', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _attended('u010'));
      expect(_feedback().toasts, [ToastId.tst31]);
      expect(_row(tester, 'u010').attended, isTrue);

      _feedback()
        ..nextMenuResult = AttendanceMenuAction.markAll
        ..dialogResults[DialogId.dlg17] = true;
      await _tapKey(tester, _menu);
      expect(_feedback().dialogs, [DialogId.dlg17]);
      expect(_feedback().toasts, [ToastId.tst31, ToastId.tst31]);
      expect(
        find.text(tester.l10n.attendanceSummaryChip('Katıldın', 51)),
        findsOneWidget,
      );

      _feedback().nextMenuResult = AttendanceMenuAction.toggleRegistration;
      await _tapKey(tester, _menu);
      expect(_feedback().toasts.last, ToastId.tstX15);
    });

    testWidgets('QR → MGT-07; etkinlik değiştir → seçilen; geri → MGT-04', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _scan);
      expect(_location(router), '$_path/scan');

      router.go(_path);
      await tester.pumpAndSettle();
      _feedback().nextMenuResult = 'e01';
      await _tapKey(tester, _switchEvent);
      expect(_location(router), '$_eventsPath/e01/attendance');

      await _tapKey(tester, _back);
      expect(_location(router), _eventsPath);
    });
  });

  group('MGT-06 · Katılımcılar ve yoklama · matris', () {
    testWidgets('yönetici + danışman bakışı', (tester) async {
      await DeviceMatrix.run(tester, (_) => _view, overrides: _overrides());
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: _overrides(
          session: attendanceSession(role: ClubRole.advisor),
          state: loadedAttendanceState(
            access: ClubAccess.advisor,
            phase: AttendancePhase.closed,
          ),
        ),
      );
    });
  });

  group('MGT-06 · Katılımcılar ve yoklama · golden', () {
    testWidgets('varsayılan açık + koyu', (tester) async {
      await goldenForThemes(tester, 'MGT-06', _view, overrides: _overrides());
    });
  });
}
