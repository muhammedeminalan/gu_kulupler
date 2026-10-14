// `RsvpRepository` fake'i (PLAN §16.3): katılım kayıtlarını bellekte tutar;
// etkinliği ve sayaçlarını paylaşılan `FakeEventRepository`'den okur / işler.
//
//   final events = FakeEventRepository(clock)..put(EventModelFixtures.e03);
//   final rsvps = FakeRsvpRepository(clock, events: events);
//   final joined = await rsvps.join(eventId: 'e03', clubId: 'c03', …);
//   expect(joined.dataOrNull!.status, RsvpStatus.waitlist); // 30 / 30 dolu
//   rsvps.watchMineController('e03', 'u_mehmet').add(const FirebaseSuccess(null));
//
// Gerçek repository + Security Rules'un birlikte verdiği sonuçları izler
// (docs/plans/T-22.md §6.3–§6.4):
// - kontenjan kararı katılım anındaki sayaçtan verilir: yer varsa ve bekleme
//   listesi boşsa `going`, aksi `waitlist` (`waitlistAt` = şimdi;
//   `EventModel.joinsWaitlist`); sayaç kayıtla birlikte ±1 değişir
//   (`goingCount` kontenjanı aşmaz). [capacityRace] bir sonraki katılımda son
//   yerin "aynı anda" başka birine gittiğini kurar: etkinliğin `goingCount`'u
//   karar öncesi 1 artar (gerçek repository işlemi yeniden koşturur ve güncel
//   sayacı görür);
// - yeniden katılım (`cancelled → going | waitlist`) aynı kaydı, **aynı bilet
//   koduyla** kullanır; bilet kodu yalnızca ilk katılımda üretilir;
// - vazgeçme otomatik terfi yapmaz (Mod C), zaten vazgeçilmiş kayıtta yazımsız
//   başarıdır; yoklaması alınmış kayıt `failedPrecondition`, bitmiş etkinlik
//   `ruleViolation(eventEnded)`;
// - `findByTicket` aynı kodu taşıyan iki kayıtta `failedPrecondition`
//   (kopyalanmış kod — belirsiz eşleşme);
// - **olmayan** etkinliğe katılım `permissionDenied`'dır (kural etkinliği
//   okuyamaz); silinmiş etkinlik `notFound`.
// Çağıranın rolü burada bilinmez (üyelere özel etkinlik, askıdaki hesap,
// katılımcıya kapalı `waitlistPosition` / `findByTicket`): yetki reddini test
// `failNext(FirestoreError.permissionDenied)` ile kurar.
import 'dart:async';

import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';
import 'fake_event_repository.dart';

/// `watchMine` akışının tek olayı.
typedef FakeRsvpEvent = FirestoreResult<RsvpModel?>;

/// `setReminder` ile **yazılan** hatırlatma tercihi.
typedef FakeReminderWrite = ({
  String eventId,
  String userId,
  ReminderOption reminder,
});

final class FakeRsvpRepository extends FakeBase implements RsvpRepository {
  /// "Şu an" [_clock] saatidir; etkinlikler ve sayaçlar [events] fake'inde
  /// tutulur (`registerDefaultFakes` kayıtlı örneği verir).
  FakeRsvpRepository(this._clock, {required this.events});

  final AppClock _clock;

  /// Etkinlik belgeleri ve sayaçları (kayıtla aynı "işlemde" oynar).
  final FakeEventRepository events;

  /// `rsvps/{eventId}_{userId}` kayıtları. Test ön veriyi [put] ile yazar.
  final Map<String, RsvpModel> rsvps = <String, RsvpModel>{};

  /// `setReminder` ile yazılan tercihler, sırayla.
  final List<FakeReminderWrite> reminderWrites = <FakeReminderWrite>[];

  /// `true` iken bir sonraki [join], okuma ile karar arasında son yerin başka
  /// bir katılımcıya gittiğini kurar (etkinliğin `goingCount`'u 1 artar);
  /// bayrak tek seferliktir.
  bool capacityRace = false;

  /// Açık `watchMine` dinleyicisi sayısı.
  int activeListeners = 0;

  final Map<String, StreamController<FakeRsvpEvent>> _controllers =
      <String, StreamController<FakeRsvpEvent>>{};
  int _issued = 0;

  /// ([eventId], [userId]) akışının denetleyicisi: test elle olay yazar (hata
  /// dahil).
  StreamController<FakeRsvpEvent> watchMineController(
    String eventId,
    String userId,
  ) => _controllers.putIfAbsent(
    FirestoreIds.rsvp(eventId, userId),
    StreamController<FakeRsvpEvent>.broadcast,
  );

  /// [rsvp] kaydını yazar (varsa üzerine) ve akışını günceller. Sayaçlara
  /// dokunmaz: sayaç etkinlik belgesiyle birlikte kurulur.
  void put(RsvpModel rsvp) {
    rsvps[rsvp.id] = rsvp;
    _emit(rsvp.id);
  }

  /// Sıralı, `FirestoreIds.ticketCodePattern` desenindeki [n]. bilet kodu
  /// (`GU-FAKE-AAAB`, `GU-FAKE-AAAC` …).
  static String ticketCodeAt(int n) {
    const alphabet = TicketCodeGenerator.alphabet;
    final chars = List.filled(4, alphabet[0]);
    var rest = n;
    for (var i = 3; i >= 0; i--) {
      chars[i] = alphabet[rest % alphabet.length];
      rest ~/= alphabet.length;
    }
    return 'GU-FAKE-${chars.join()}';
  }

  @override
  Future<FirestoreResult<RsvpModel>> join({
    required String eventId,
    required String clubId,
    required String userId,
    required ReminderOption reminder,
  }) async {
    record('join', [eventId, clubId, userId, reminder]);
    if (_rejected<RsvpModel>([eventId, clubId, userId]) case final failure?) {
      return failure;
    }
    var event = events.events[eventId];
    if (event == null) return _denied();
    if (event.isDeleted) return const FirebaseFailure(FirestoreError.notFound);
    if (event.clubId != clubId) return _invalid();
    if (event.status != EventStatus.published || !event.registrationOpen) {
      return _violation(FirestoreRuleCode.registrationClosed);
    }
    final now = _clock.nowUtc();
    if (!event.endsAt.isAfter(now)) {
      return _violation(FirestoreRuleCode.eventEnded);
    }
    final id = FirestoreIds.rsvp(eventId, userId);
    final current = rsvps[id];
    if (current != null && current.status != RsvpStatus.cancelled) {
      return const FirebaseFailure(FirestoreError.conflict);
    }
    if (capacityRace) {
      // Son yer aynı anda başka birine gitti; yeniden koşan işlem bunu görür.
      capacityRace = false;
      events.bumpCounters(eventId, going: 1);
      event = events.events[eventId] ?? event;
    }
    final waitlisted = event.joinsWaitlist;
    final status = waitlisted ? RsvpStatus.waitlist : RsvpStatus.going;
    final joined = current == null
        ? RsvpModel(
            eventId: eventId,
            clubId: clubId,
            userId: userId,
            ticketCode: ticketCodeAt(++_issued),
            status: status,
            reminder: reminder,
            waitlistAt: waitlisted ? now : null,
            createdAt: now,
            updatedAt: now,
          )
        : current.copyWith(
            status: status,
            reminder: reminder,
            waitlistAt: waitlisted ? now : null,
            clearWaitlistAt: !waitlisted,
            updatedAt: now,
          );
    _write(joined);
    events.bumpCounters(
      eventId,
      going: waitlisted ? 0 : 1,
      waitlist: waitlisted ? 1 : 0,
    );
    return FirebaseSuccess(joined);
  }

  @override
  Future<FirestoreResult<void>> cancel({
    required String eventId,
    required String userId,
  }) async {
    record('cancel', [eventId, userId]);
    if (_rejected<void>([eventId, userId]) case final failure?) {
      return failure;
    }
    final current = rsvps[FirestoreIds.rsvp(eventId, userId)];
    if (current == null) return const FirebaseFailure(FirestoreError.notFound);
    switch (current.status) {
      case RsvpStatus.cancelled:
        return const FirebaseSuccess(null);
      case RsvpStatus.attended:
        return const FirebaseFailure(FirestoreError.failedPrecondition);
      case RsvpStatus.going || RsvpStatus.waitlist:
        // Bitmiş etkinlikte vazgeçilemez ("Gelmedin" kaydı korunur).
        final event = events.events[eventId];
        if (event == null) {
          return const FirebaseFailure(FirestoreError.notFound);
        }
        if (!event.endsAt.isAfter(_clock.nowUtc())) {
          return _violation(FirestoreRuleCode.eventEnded);
        }
        // Boşalan yere kimse otomatik alınmaz (Mod C).
        _write(
          current.copyWith(
            status: RsvpStatus.cancelled,
            updatedAt: _clock.nowUtc(),
          ),
        );
        events.bumpCounters(
          eventId,
          going: current.status == RsvpStatus.going ? -1 : 0,
          waitlist: current.status == RsvpStatus.waitlist ? -1 : 0,
        );
        return const FirebaseSuccess(null);
    }
  }

  @override
  Future<FirestoreResult<void>> setReminder({
    required String eventId,
    required String userId,
    required ReminderOption reminder,
  }) async {
    record('setReminder', [eventId, userId, reminder]);
    if (_rejected<void>([eventId, userId]) case final failure?) {
      return failure;
    }
    final current = rsvps[FirestoreIds.rsvp(eventId, userId)];
    final status = current?.status;
    if (status != RsvpStatus.going && status != RsvpStatus.waitlist) {
      return _violation(FirestoreRuleCode.notMember);
    }
    _write(current!.copyWith(reminder: reminder, updatedAt: _clock.nowUtc()));
    reminderWrites.add((eventId: eventId, userId: userId, reminder: reminder));
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<RsvpModel?>> getMine({
    required String eventId,
    required String userId,
  }) async {
    record('getMine', [eventId, userId]);
    if (_rejected<RsvpModel?>([eventId, userId]) case final failure?) {
      return failure;
    }
    return FirebaseSuccess(rsvps[FirestoreIds.rsvp(eventId, userId)]);
  }

  @override
  Stream<FirestoreResult<RsvpModel?>> watchMine({
    required String eventId,
    required String userId,
  }) {
    record('watchMine', [eventId, userId]);
    if (!RepositoryHelpers.isValidId(eventId) ||
        !RepositoryHelpers.isValidId(userId)) {
      return Stream.value(
        const FirebaseFailure(FirestoreError.invalidArgument),
      );
    }
    final id = FirestoreIds.rsvp(eventId, userId);
    final source = watchMineController(eventId, userId);
    late final StreamController<FakeRsvpEvent> output;
    StreamSubscription<FakeRsvpEvent>? subscription;
    output = StreamController<FakeRsvpEvent>(
      onListen: () {
        activeListeners++;
        // İlk anlık görüntü (Firestore dinleyicisi gibi), sonra değişiklikler.
        output.add(FirebaseSuccess(rsvps[id]));
        subscription = source.stream.listen(output.add);
      },
      onCancel: () {
        activeListeners--;
        return subscription?.cancel();
      },
    );
    return output.stream;
  }

  @override
  Future<FirestoreResult<List<RsvpModel>>> listMine(String userId) async {
    record('listMine', [userId]);
    if (_rejected<List<RsvpModel>>([userId]) case final failure?) {
      return failure;
    }
    // Vazgeçilmişler dahil, en yeni üstte.
    return FirebaseSuccess(
      [
        for (final rsvp in rsvps.values)
          if (rsvp.userId == userId && !rsvp.isDeleted) rsvp,
      ]..sort(_newestFirst),
    );
  }

  @override
  Future<FirestoreResult<int>> waitlistPosition({
    required String eventId,
    required String clubId,
    required DateTime waitlistAtUtc,
  }) async {
    record('waitlistPosition', [eventId, clubId, waitlistAtUtc]);
    if (_rejected<int>([eventId, clubId]) case final failure?) return failure;
    final ahead = rsvps.values.where(
      (rsvp) =>
          rsvp.eventId == eventId &&
          rsvp.clubId == clubId &&
          rsvp.status == RsvpStatus.waitlist &&
          (rsvp.waitlistAt?.isBefore(waitlistAtUtc) ?? false),
    );
    return FirebaseSuccess(ahead.length + 1);
  }

  @override
  Future<FirestoreResult<RsvpModel?>> findByTicket({
    required String eventId,
    required String clubId,
    required String code,
  }) async {
    record('findByTicket', [eventId, clubId, code]);
    if (_rejected<RsvpModel?>([eventId, clubId]) case final failure?) {
      return failure;
    }
    if (!RegExp(FirestoreIds.ticketCodePattern).hasMatch(code)) {
      return const FirebaseSuccess(null);
    }
    final matches = rsvps.values
        .where(
          (rsvp) =>
              rsvp.eventId == eventId &&
              rsvp.clubId == clubId &&
              rsvp.ticketCode == code,
        )
        .toList();
    // Kopyalanmış kod: eşleşme belirsizdir, hiçbiri döndürülmez.
    if (matches.length > 1) {
      return const FirebaseFailure(FirestoreError.failedPrecondition);
    }
    return FirebaseSuccess(matches.firstOrNull);
  }

  void _write(RsvpModel rsvp) {
    rsvps[rsvp.id] = rsvp;
    _emit(rsvp.id);
  }

  void _emit(String id) {
    final controller = _controllers[id];
    if (controller != null && controller.hasListener) {
      controller.add(FirebaseSuccess(rsvps[id]));
    }
  }

  /// `createdAt` azalan; zamanı olmayan kayıt sonda.
  static int _newestFirst(RsvpModel a, RsvpModel b) {
    final left = a.createdAt;
    final right = b.createdAt;
    if (left == null || right == null) {
      return left == right ? 0 : (left == null ? 1 : -1);
    }
    return right.compareTo(left);
  }

  static FirestoreResult<T> _violation<T>(FirestoreRuleCode code) =>
      FirebaseFailure(
        FirestoreError.ruleViolation,
        detail: FirestoreFailureDetail(code),
      );

  static FirestoreResult<T> _denied<T>() =>
      const FirebaseFailure(FirestoreError.permissionDenied);

  static FirestoreResult<T> _invalid<T>() =>
      const FirebaseFailure(FirestoreError.invalidArgument);

  /// Bekleyen hata ya da geçersiz kimlik varsa başarısızlık; yoksa `null`.
  FirestoreResult<T>? _rejected<T>(List<String> ids) {
    final failure = switch (takeFailure()) {
      null => null,
      final FirestoreError error => error,
      _ => FirestoreError.unknown,
    };
    if (failure != null) return FirebaseFailure(failure);
    if (!ids.every(RepositoryHelpers.isValidId)) return _invalid();
    return null;
  }
}
