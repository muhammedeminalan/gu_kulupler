// `AttendanceRepository` fake'i (PLAN §16.3; T-30): yoklama ve bekleme
// listesi terfisini paylaşılan `FakeRsvpRepository` (kayıtlar) ve
// `FakeEventRepository` (etkinlik + sayaçlar) üzerinde bellekte uygular.
//
//   final events = FakeEventRepository(clock)..put(event);
//   final rsvps = FakeRsvpRepository(clock, events: events)..put(rsvp);
//   final attendance = FakeAttendanceRepository(clock, rsvps: rsvps);
//   await attendance.markAttended(eventId: 'e01', userId: 'u1', actorId: 'u_b', attended: true);
//   expect(events.events['e01']!.attendedCount, 1);
//   expect(attendance.promoted.single.userId, 'u2');
//
// Denetim sırası ve sonuçlar `FirebaseAttendanceRepository` ile aynıdır:
// etkinlik yok → `notFound`, başka kulübün etkinliği → `invalidArgument`,
// silinmiş / yayında değil → `conflict`, K-G penceresi dışı →
// `ruleViolation(attendanceWindowClosed)`, beklenen durumda olmayan kayıt →
// `conflict`; yöneticinin kendi kaydı (rules-spec §3.8) → `invalidArgument`
// (okutmada `ScanOutcome.invalid`, toplu yoklamada kümeye girmez); terfide
// bitmiş etkinlik `eventEnded`, dolu kontenjan
// `capacityFull`. Sayaçlar kayıtla aynı "işlemde" ±1 oynar. Yetki (danışman,
// başka kulübün yöneticisi, askıdaki kulüp) Rules'tadır: test
// `failNext(FirestoreError.permissionDenied)` ile kurar. Kayıt silinmez (D-10).
import 'dart:async';

import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';
import 'fake_event_repository.dart';
import 'fake_rsvp_repository.dart';

/// Başarılı terfi (gerçek repository aynı işlemde `waitlist_promoted`
/// bildirimi yazar).
typedef FakePromotion = ({String eventId, String userId, String actorId});

/// Katılımcı akışının tek olayı.
typedef FakeParticipantsEvent = FirestoreResult<List<RsvpModel>>;

final class FakeAttendanceRepository extends FakeBase
    implements AttendanceRepository {
  /// Kayıtlar [rsvps] fake'inde, etkinlikler ve sayaçlar onun
  /// `FakeEventRepository`'sinde tutulur; "şu an" [_clock] saatidir.
  FakeAttendanceRepository(this._clock, {required this.rsvps});

  final AppClock _clock;

  /// Katılım kayıtları (`registerDefaultFakes` kayıtlı örneği verir).
  final FakeRsvpRepository rsvps;

  /// Başarılı terfiler, sırasıyla.
  final List<FakePromotion> promoted = <FakePromotion>[];

  final Map<String, StreamController<FakeParticipantsEvent>> _controllers =
      <String, StreamController<FakeParticipantsEvent>>{};

  /// Etkinlik belgeleri ve sayaçları.
  FakeEventRepository get events => rsvps.events;

  /// [eventId] katılımcı akışının denetleyicisi: test elle olay (hata dahil)
  /// yazar.
  StreamController<FakeParticipantsEvent> watchParticipantsController(
    String eventId,
  ) => _controllers.putIfAbsent(
    eventId,
    StreamController<FakeParticipantsEvent>.broadcast,
  );

  @override
  Stream<FirestoreResult<List<RsvpModel>>> watchParticipants({
    required String eventId,
    required String clubId,
  }) {
    record('watchParticipants', [eventId, clubId]);
    if (_rejected<List<RsvpModel>>([eventId, clubId]) case final failure?) {
      return Stream.value(failure);
    }
    final source = watchParticipantsController(eventId);
    late final StreamController<FakeParticipantsEvent> output;
    StreamSubscription<FakeParticipantsEvent>? subscription;
    output = StreamController<FakeParticipantsEvent>(
      onListen: () {
        output.add(FirebaseSuccess(_participants(eventId, clubId)));
        subscription = source.stream.listen(output.add);
      },
      onCancel: () => subscription?.cancel(),
    );
    return output.stream;
  }

  @override
  Future<FirestoreResult<List<RsvpModel>>> listParticipants({
    required String eventId,
    required String clubId,
    Set<RsvpStatus>? statuses,
  }) async {
    record('listParticipants', [eventId, clubId, statuses]);
    if (_rejected<List<RsvpModel>>([eventId, clubId]) case final failure?) {
      return failure;
    }
    return FirebaseSuccess([
      for (final rsvp in _participants(eventId, clubId))
        if (statuses == null || statuses.contains(rsvp.status)) rsvp,
    ]);
  }

  @override
  Future<FirestoreResult<ScanOutcome>> scanTicket({
    required String eventId,
    required String clubId,
    required String qrPayload,
    required String actorId,
  }) async {
    record('scanTicket', [eventId, clubId, qrPayload, actorId]);
    if (_rejected<ScanOutcome>([eventId, clubId, actorId])
        case final failure?) {
      return failure;
    }
    final ticket = FirestoreIds.parseTicketQr(qrPayload);
    if (ticket == null || ticket.eventId != eventId) {
      return const FirebaseSuccess(ScanOutcome.invalid);
    }
    switch (await rsvps.findByTicket(
      eventId: eventId,
      clubId: clubId,
      code: ticket.code,
    )) {
      // Kopyalanmış kod (W-79): eşleşme belirsiz → geçersiz.
      case FirebaseFailure(error: FirestoreError.failedPrecondition):
        return const FirebaseSuccess(ScanOutcome.invalid);
      case FirebaseFailure(:final error, :final detail):
        return FirebaseFailure(error, detail: detail);
      case FirebaseSuccess(data: final rsvp):
        return switch (rsvp?.status) {
          null ||
          RsvpStatus.cancelled ||
          RsvpStatus.waitlist => const FirebaseSuccess(ScanOutcome.invalid),
          RsvpStatus.attended => const FirebaseSuccess(
            ScanOutcome.alreadyScanned,
          ),
          RsvpStatus.going when rsvp!.userId == actorId =>
            const FirebaseSuccess(
              ScanOutcome.invalid,
            ),
          RsvpStatus.going => _attend(
            eventId,
            rsvp!.userId,
            actorId,
            attended: true,
            clubId: clubId,
            ticketCode: ticket.code,
          ),
        };
    }
  }

  @override
  Future<FirestoreResult<void>> markAttended({
    required String eventId,
    required String userId,
    required String actorId,
    required bool attended,
  }) async {
    record('markAttended', [eventId, userId, actorId, attended]);
    if (_rejected<void>([eventId, userId, actorId]) case final failure?) {
      return failure;
    }
    return _attend(eventId, userId, actorId, attended: attended).map((_) {});
  }

  @override
  Future<FirestoreResult<BulkResult>> markAllAttended({
    required String eventId,
    required String clubId,
    required String actorId,
    void Function(int done, int total)? onProgress,
  }) async {
    record('markAllAttended', [eventId, clubId, actorId]);
    if (_rejected<BulkResult>([eventId, clubId, actorId]) case final failure?) {
      return failure;
    }
    final going = [
      for (final rsvp in _participants(eventId, clubId))
        if (rsvp.status == RsvpStatus.going && rsvp.userId != actorId) rsvp,
    ];
    final succeeded = <String>[];
    final conflicted = <String>[];
    final failed = <String>[];
    for (final (index, rsvp) in going.indexed) {
      switch (_attend(
        eventId,
        rsvp.userId,
        actorId,
        attended: true,
        clubId: clubId,
      )) {
        case FirebaseSuccess():
          succeeded.add(rsvp.userId);
        case FirebaseFailure(error: FirestoreError.conflict):
          conflicted.add(rsvp.userId);
        // Pencere kapandı: kalan kayıtlar da yazılamaz.
        case FirebaseFailure(
              error: FirestoreError.ruleViolation,
              :final FirestoreFailureDetail detail,
            )
            when detail.code == FirestoreRuleCode.attendanceWindowClosed:
          return FirebaseFailure(FirestoreError.ruleViolation, detail: detail);
        case FirebaseFailure():
          failed.add(rsvp.userId);
      }
      onProgress?.call(index + 1, going.length);
    }
    return FirebaseSuccess(
      BulkResult(
        succeeded: succeeded,
        conflicted: conflicted,
        failed: failed,
      ),
    );
  }

  @override
  Future<FirestoreResult<void>> promote({
    required String eventId,
    required String userId,
    required String actorId,
  }) async {
    record('promote', [eventId, userId, actorId]);
    if (_rejected<void>([eventId, userId, actorId]) case final failure?) {
      return failure;
    }
    if (userId == actorId) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final (event, failure) = _publishedEvent(eventId);
    if (failure != null) return FirebaseFailure(failure);
    if (!event!.endsAt.isAfter(_clock.nowUtc())) {
      return _violation(FirestoreRuleCode.eventEnded);
    }
    if (event.isFull) return _violation(FirestoreRuleCode.capacityFull);
    final rsvp = rsvps.rsvps[FirestoreIds.rsvp(eventId, userId)];
    if (rsvp?.status != RsvpStatus.waitlist) {
      return const FirebaseFailure(FirestoreError.conflict);
    }
    rsvps.put(
      rsvp!.copyWith(status: RsvpStatus.going, updatedAt: _clock.nowUtc()),
    );
    events.put(
      event.copyWith(
        goingCount: event.goingCount + 1,
        waitlistCount: event.waitlistCount - 1,
      ),
    );
    promoted.add((eventId: eventId, userId: userId, actorId: actorId));
    _emit(eventId, event.clubId);
    return const FirebaseSuccess(null);
  }

  /// Yoklama geçişi (`going ↔ attended`); [ticketCode] verilirse bilet
  /// okutmanın işlem içi yeniden karşılaştırması.
  FirestoreResult<ScanOutcome> _attend(
    String eventId,
    String userId,
    String actorId, {
    required bool attended,
    String? clubId,
    String? ticketCode,
  }) {
    if (userId == actorId) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final (event, failure) = _publishedEvent(eventId, clubId: clubId);
    if (failure != null) return FirebaseFailure(failure);
    if (!event!.attendanceWindow(_clock)) {
      return _violation(FirestoreRuleCode.attendanceWindowClosed);
    }
    final rsvp = rsvps.rsvps[FirestoreIds.rsvp(eventId, userId)];
    if (ticketCode != null) {
      if (rsvp == null || rsvp.ticketCode != ticketCode) {
        return const FirebaseSuccess(ScanOutcome.invalid);
      }
      if (rsvp.status == RsvpStatus.attended) {
        return const FirebaseSuccess(ScanOutcome.alreadyScanned);
      }
    }
    final from = attended ? RsvpStatus.going : RsvpStatus.attended;
    if (rsvp?.status != from) {
      return const FirebaseFailure(FirestoreError.conflict);
    }
    final now = _clock.nowUtc();
    rsvps.put(
      attended
          ? rsvp!.copyWith(
              status: RsvpStatus.attended,
              scannedAt: now,
              scannedBy: actorId,
              updatedAt: now,
            )
          : rsvp!.copyWith(
              status: RsvpStatus.going,
              clearScannedAt: true,
              clearScannedBy: true,
              updatedAt: now,
            ),
    );
    events.put(
      event.copyWith(attendedCount: event.attendedCount + (attended ? 1 : -1)),
    );
    _emit(eventId, event.clubId);
    return const FirebaseSuccess(ScanOutcome.valid);
  }

  /// Yayındaki etkinlik ya da gerçek repository'nin hatası.
  (EventModel?, FirestoreError?) _publishedEvent(
    String eventId, {
    String? clubId,
  }) {
    final event = events.events[eventId];
    if (event == null) return (null, FirestoreError.notFound);
    if (clubId != null && event.clubId != clubId) {
      return (null, FirestoreError.invalidArgument);
    }
    if (event.isDeleted || event.status != EventStatus.published) {
      return (null, FirestoreError.conflict);
    }
    return (event, null);
  }

  /// Etkinliğin kayıtları; sıra `status`, `waitlistAt` (boş önce), `userId`
  /// (gerçek repository ile aynı).
  List<RsvpModel> _participants(String eventId, String clubId) => [
    for (final rsvp in rsvps.rsvps.values)
      if (rsvp.eventId == eventId && rsvp.clubId == clubId) rsvp,
  ]..sort(_byStatusThenQueue);

  void _emit(String eventId, String clubId) => _controllers[eventId]?.add(
    FirebaseSuccess(_participants(eventId, clubId)),
  );

  static int _byStatusThenQueue(RsvpModel a, RsvpModel b) {
    final byStatus = a.status.json.compareTo(b.status.json);
    if (byStatus != 0) return byStatus;
    final aAt = a.waitlistAt;
    final bAt = b.waitlistAt;
    if (aAt != bAt) {
      if (aAt == null) return -1;
      if (bAt == null) return 1;
      final byQueue = aAt.compareTo(bAt);
      if (byQueue != 0) return byQueue;
    }
    return a.userId.compareTo(b.userId);
  }

  static FirestoreResult<T> _violation<T>(FirestoreRuleCode code) =>
      FirebaseFailure(
        FirestoreError.ruleViolation,
        detail: FirestoreFailureDetail(code),
      );

  /// Bekleyen hata ya da geçersiz kimlik varsa başarısızlık; yoksa `null`.
  FirestoreResult<T>? _rejected<T>(List<String> ids) {
    final failure = switch (takeFailure()) {
      null => null,
      final FirestoreError error => error,
      _ => FirestoreError.unknown,
    };
    if (failure != null) return FirebaseFailure(failure);
    if (!ids.every(RepositoryHelpers.isValidId)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    return null;
  }
}
