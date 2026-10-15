// MGT-06 · AttendanceViewModel: yükleme (kulüp + etkinlik + canlı
// katılımcı akışı), süzgeç / arama / yüzde, "Katıldı" anahtarı (iyimser →
// TST-31 "Geri al"; hata → geri alınır + TST-X18), yoklama penceresi (K-G;
// FakeAppClock), kendi kaydı (CD-153), danışman (TST-26), "Kayıtlıya al"
// (TST-X13 / kontenjan dolu TST-X14), DLG-17 toplu yoklama (ilerleme +
// TST-31 + geri al), kayıt aç / kapa (TST-X15) — PLAN §12.6, roadmap T-35.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/attendance_state.dart';
import 'package:gu_kulupler/features/management/provider/attendance_view_model.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';

import '../../../fakes/fake_attendance_repository.dart';
import '../../../fakes/fake_event_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../attendance_test_support.dart';

void main() {
  late FakeAttendanceRepository attendance;
  late FakeEventRepository events;
  late FakeFeedbackService feedback;

  final provider = attendanceViewModelProvider(
    kAttendanceClubId,
    kAttendanceEventId,
  );

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    attendance = GetIt.I<AttendanceRepository>() as FakeAttendanceRepository;
    events = GetIt.I<EventRepository>() as FakeEventRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
  });

  Future<ProviderContainer> loaded({
    SessionState? session,
    DateTime? now,
    List<RsvpModel> extra = const [],
  }) async {
    seedAttendance(now: now, extra: extra);
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => session ?? attendanceSession(),
        ),
      ],
    );
    addTearDown(container.listen(provider, (_, _) {}).close);
    await pumpEventQueue();
    return container;
  }

  AttendanceViewModel vm(ProviderContainer c) => c.read(provider.notifier);

  AttendanceState state(ProviderContainer c) => c.read(provider);

  RsvpStatus statusOf(ProviderContainer c, String userId) =>
      state(c).find(userId)!.status;

  /// İlk `going` kayıt (oturumdaki yönetici hariç).
  String firstGoing(ProviderContainer c) => state(c).registered
      .firstWhere(
        (r) => r.status == RsvpStatus.going && r.userId != kAttendanceUid,
      )
      .userId;

  group('MGT-06 · yükleme, süzgeç, yüzde', () {
    test('kulüp + etkinlik + canlı katılımcılar; sayılar ve yüzde (5 / 52 '
        '→ %10); ada göre sıra', () async {
      final container = await loaded();
      final s = state(container);
      expect(s.isFetching, isFalse);
      expect(s.isError, isFalse);
      expect(s.club?.id, kAttendanceClubId);
      expect(s.event?.id, kAttendanceEventId);
      expect(s.phase, AttendancePhase.open);
      expect(attendance.callsTo('watchParticipants'), hasLength(1));
      expect(s.countOf(AttendanceSummaryFilter.all), 52);
      expect(s.countOf(AttendanceSummaryFilter.attended), 5);
      expect(s.countOf(AttendanceSummaryFilter.absent), 47);
      expect(s.countOf(AttendanceSummaryFilter.waitlist), 0);
      expect(s.attendanceRate, 10);
      expect(s.users, hasLength(52));
      expect(s.nameOf(s.visible.first.userId), 'Alp Aksoy');
    });

    test(
      'canlı akış: yeni olay listeyi değiştirir (okutma başka cihazda)',
      () async {
        final container = await loaded();
        final id = firstGoing(container);
        final updated = [
          for (final r in state(container).rsvps)
            r.userId == id ? r.copyWith(status: RsvpStatus.attended) : r,
        ];
        attendance
            .watchParticipantsController(kAttendanceEventId)
            .add(FirebaseSuccess(updated));
        await pumpEventQueue();
        expect(statusOf(container, id), RsvpStatus.attended);
        expect(state(container).countOf(AttendanceSummaryFilter.attended), 6);
      },
    );

    test('süzgeç ve arama (Türkçe küçük harf)', () async {
      final container = await loaded();
      vm(container).setSummary(AttendanceSummaryFilter.attended);
      expect(state(container).visible, hasLength(5));
      expect(state(container).showsWaitlist, isFalse);
      vm(container).setSummary(AttendanceSummaryFilter.absent);
      expect(state(container).visible, hasLength(47));
      vm(container)
        ..setSummary(AttendanceSummaryFilter.all)
        ..setQuery('ALP');
      expect([
        for (final r in state(container).visible)
          state(container).nameOf(r.userId),
      ], contains('Alp Aksoy'));
      vm(container).setSummary(AttendanceSummaryFilter.waitlist);
      expect(state(container).visible, isEmpty);
      expect(state(container).showsWaitlist, isTrue);
    });
  });

  group('MGT-06 · Katıldı anahtarı (TST-31)', () {
    test(
      'işaretle → iyimser + markAttended + TST-31; "Geri al" → kaldırır',
      () async {
        final container = await loaded();
        final id = firstGoing(container);
        final name = state(container).nameOf(id);
        final future = vm(container).setAttended(id, true);
        expect(statusOf(container, id), RsvpStatus.attended, reason: 'iyimser');
        expect(await future, isTrue);
        await pumpEventQueue();
        expect(attendance.callsTo('markAttended').single.args, [
          kAttendanceEventId,
          id,
          kAttendanceUid,
          true,
        ]);
        expect(feedback.toasts, [ToastId.tst31]);
        expect(feedback.toastParams.single.name, name);
        expect(state(container).marks, isEmpty, reason: 'akış doğruladı');

        feedback.tapToastAction();
        await pumpEventQueue();
        expect(attendance.callsTo('markAttended').last.args.last, isFalse);
        expect(statusOf(container, id), RsvpStatus.going);
        expect(feedback.toasts, [
          ToastId.tst31,
        ], reason: 'kaldırmada toast yok');
      },
    );

    test('yazılamadı → anahtar geri döner + TST-X18', () async {
      final container = await loaded();
      final id = firstGoing(container);
      attendance.failNext(FirestoreError.permissionDenied);
      expect(await vm(container).setAttended(id, true), isFalse);
      expect(statusOf(container, id), RsvpStatus.going);
      expect(feedback.toasts, [ToastId.tstX18]);
    });

    test('kendi kaydı (CD-153) yazılmaz', () async {
      final container = await loaded();
      expect(await vm(container).setAttended(kAttendanceUid, true), isFalse);
      expect(attendance.callsTo('markAttended'), isEmpty);
    });

    test('danışman → TST-26, yazım yok', () async {
      final container = await loaded(
        session: attendanceSession(role: ClubRole.advisor),
      );
      expect(state(container).isReadOnly, isTrue);
      expect(state(container).canMark, isFalse);
      expect(
        await vm(container).setAttended(firstGoing(container), true),
        isFalse,
      );
      expect(feedback.toasts, [ToastId.tst26]);
      expect(attendance.callsTo('markAttended'), isEmpty);
    });
  });

  group('MGT-06 · yoklama penceresi (K-G)', () {
    test('başlangıçtan 2 sa önceden erken → bant, yazım yok', () async {
      final container = await loaded(
        now: kAttendanceEvent.startsAt.subtract(
          Limits.attendanceWindowBefore + const Duration(minutes: 1),
        ),
      );
      expect(state(container).phase, AttendancePhase.beforeWindow);
      expect(state(container).canMark, isFalse);
      expect(
        await vm(container).setAttended(firstGoing(container), true),
        isFalse,
      );
      expect(attendance.callsTo('markAttended'), isEmpty);
    });

    test(
      'pencere açık ama başlamadı → "henüz başlamadı" bandı, yazılır',
      () async {
        final container = await loaded(
          now: kAttendanceEvent.startsAt.subtract(const Duration(hours: 1)),
        );
        expect(state(container).phase, AttendancePhase.beforeStart);
        expect(
          await vm(container).setAttended(firstGoing(container), true),
          isTrue,
        );
      },
    );

    test('bitişten 6 sa sonra → kapandı', () async {
      final container = await loaded(
        now: kAttendanceEvent.endsAt.add(
          Limits.attendanceWindowAfter + const Duration(minutes: 1),
        ),
      );
      expect(state(container).phase, AttendancePhase.closed);
      expect(await vm(container).markAllAttended(allLabel: 'x'), isFalse);
      expect(feedback.dialogs, isEmpty);
    });
  });

  group('MGT-06 · Kayıtlıya al (TST-X13, TST-X14)', () {
    test('bekleyen → promote → TST-X13; liste akıştan güncellenir', () async {
      final container = await loaded(extra: [waitlisted('u_mehmet')]);
      expect(state(container).waitlist.single.userId, 'u_mehmet');
      expect(await vm(container).promote('u_mehmet'), isTrue);
      await pumpEventQueue();
      expect(attendance.promoted.single.userId, 'u_mehmet');
      expect(feedback.toasts, [ToastId.tstX13]);
      expect(statusOf(container, 'u_mehmet'), RsvpStatus.going);
    });

    test('kontenjan dolu → TST-X14, yazım yok', () async {
      seedAttendance(extra: [waitlisted('u_mehmet')]);
      events.put(kAttendanceEvent.copyWith(capacity: 52));
      final container = createContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => attendanceSession(),
          ),
        ],
      );
      addTearDown(container.listen(provider, (_, _) {}).close);
      await pumpEventQueue();
      expect(state(container).isFull, isTrue);
      expect(await vm(container).promote('u_mehmet'), isFalse);
      expect(feedback.toasts, [ToastId.tstX14]);
      expect(attendance.callsTo('promote'), isEmpty);
    });
  });

  group('MGT-06 · DLG-17 toplu yoklama', () {
    test('onay → sıralı yazım, ilerleme yüzdesi; TST-31 "Tüm kayıtlılar"; '
        'kendi kaydı atlanır; "Geri al" → hepsi geri', () async {
      final container = await loaded();
      final progress = <AttendanceBulkProgress?>[];
      container.listen(
        provider.select((s) => s.bulkProgress),
        (_, next) => progress.add(next),
      );
      feedback.dialogResults[DialogId.dlg17] = true;
      expect(
        await vm(container).markAllAttended(allLabel: 'Tüm kayıtlılar'),
        isTrue,
      );
      await pumpEventQueue();
      expect(feedback.dialogs, [DialogId.dlg17]);
      expect(progress.first, (done: 0, total: 46));
      expect(progress, contains((done: 46, total: 46)));
      expect(progress.last, isNull);
      expect(feedback.toasts, [ToastId.tst31]);
      expect(feedback.toastParams.single.name, 'Tüm kayıtlılar');
      expect(state(container).countOf(AttendanceSummaryFilter.attended), 51);
      expect(statusOf(container, kAttendanceUid), RsvpStatus.going);

      feedback.tapToastAction();
      await pumpEventQueue();
      expect(state(container).countOf(AttendanceSummaryFilter.attended), 5);
      expect(state(container).bulkProgress, isNull);
    });
  });

  group('MGT-06 · kayıt aç / kapa (TST-X15)', () {
    test('açık → kapatılır, iyimser + TST-X15', () async {
      final container = await loaded();
      expect(await vm(container).toggleRegistration(), isTrue);
      expect(state(container).event?.registrationOpen, isFalse);
      expect(feedback.toasts, [ToastId.tstX15]);
      expect(events.events[kAttendanceEventId]?.registrationOpen, isFalse);
    });
  });
}
