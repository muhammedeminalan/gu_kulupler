import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/bulk_result.dart';
import 'package:gu_data/src/core/conflict_exception.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/firestore_failure_detail.dart';
import 'package:gu_data/src/models/enums/event_status.dart';
import 'package:gu_data/src/models/enums/rsvp_status.dart';
import 'package:gu_data/src/models/enums/scan_outcome.dart';
import 'package:gu_data/src/models/event_model.dart';
import 'package:gu_data/src/models/rsvp_model.dart';
import 'package:gu_data/src/notifications/notification_dispatcher.dart';
import 'package:gu_data/src/repositories/attendance_repository.dart';
import 'package:gu_data/src/repositories/firebase_event_repository.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/repositories/rsvp_repository.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';

/// [AttendanceRepository] uygulaması: yöneticinin `rsvps/{eventId}_{userId}`
/// yoklama ve terfi yazımları (PLAN §10.4; rules-spec §3.7, §3.8; sözleşme
/// `docs/plans/T-30.md` §4 a, b).
///
/// Her geçiş **tek transaction**'dır ve önce tüm okumaları yapar (etkinlik,
/// kayıt), beklenen durumu doğrular, sonra yazar:
/// - kayıt — yalnızca `status` (+ yoklamada `scannedAt` / `scannedBy`) ve
///   `updatedAt`;
/// - etkinlik — sayaç deltası (`FieldValue.increment`; yoklama
///   `attendedCount ±1`, terfi `goingCount +1` + `waitlistCount −1`) ve
///   `updatedAt`;
/// - yan belge `events/{eventId}/private/counter` — `{clubId, lastRsvpRef,
///   updatedAt}` (`set`, birleştirme yok; W-64, W-77): sayaç işaretçisi
///   herkese açık etkinlik belgesine **yazılmaz**;
/// - terfide `waitlist_promoted` bildirimi (aynı transaction).
///
/// Kayıt silinmez (D-10). Yetkiyi (etkin yönetici; danışman ve süper admin
/// değil) Security Rules uygular, ret [FirestoreError.permissionDenied]
/// olarak döner.
final class FirebaseAttendanceRepository implements AttendanceRepository {
  /// [_firestore] üzerinden okur ve yazar; bilet aramasını [_rsvps]'e
  /// devreder, terfi bildirimini [_notifications] ile aynı transaction'a
  /// ekler; yoklama penceresi ve etkinlik bitişi [_clock] saatinden.
  FirebaseAttendanceRepository(
    this._firestore,
    this._rsvps,
    this._notifications,
    this._clock,
  );

  final FirestoreService _firestore;
  final RsvpRepository _rsvps;
  final NotificationDispatcher _notifications;
  final AppClock _clock;

  /// Sayaç deltası: kayıt durumuna girdi.
  static const int _entered = 1;

  /// Sayaç deltası: kayıt durumundan çıktı.
  static const int _left = -1;

  @override
  Stream<FirestoreResult<List<RsvpModel>>> watchParticipants({
    required String eventId,
    required String clubId,
  }) {
    if (_rejectScope<List<RsvpModel>>(eventId, clubId) case final rejected?) {
      return Stream.value(rejected);
    }
    return _firestore.watchList(_inEvent(eventId, clubId)).map(_participantsOf);
  }

  @override
  Future<FirestoreResult<List<RsvpModel>>> listParticipants({
    required String eventId,
    required String clubId,
    Set<RsvpStatus>? statuses,
  }) async {
    if (_rejectScope<List<RsvpModel>>(eventId, clubId) case final rejected?) {
      return rejected;
    }
    if (statuses != null && statuses.isEmpty) return const FirebaseSuccess([]);
    var query = _inEvent(eventId, clubId);
    if (statuses != null) {
      query = query.where(
        FirestoreFields.status,
        whereIn: [for (final status in statuses) status.json],
      );
    }
    return _participantsOf(await _firestore.getList(query));
  }

  @override
  Future<FirestoreResult<ScanOutcome>> scanTicket({
    required String eventId,
    required String clubId,
    required String qrPayload,
    required String actorId,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<ScanOutcome>({
          'eventId': eventId,
          'clubId': clubId,
          'actorId': actorId,
        })
        case final rejected?) {
      return rejected;
    }
    // QR yükü dış girdidir: çözülemeyen ya da başka etkinliğin bileti hiçbir
    // kayda bakılmadan geçersizdir.
    final ticket = FirestoreIds.parseTicketQr(qrPayload);
    if (ticket == null || ticket.eventId != eventId) {
      return const FirebaseSuccess(ScanOutcome.invalid);
    }
    switch (await _rsvps.findByTicket(
      eventId: eventId,
      clubId: clubId,
      code: ticket.code,
    )) {
      // Kod iki kayıtta (kopyalanmış — W-79): gerçek sahibin okutması
      // kopyalayana çevrilmez; yoklama MGT-06'dan elle alınır.
      case FirebaseFailure(error: FirestoreError.failedPrecondition):
        return const FirebaseSuccess(ScanOutcome.invalid);
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(data: final rsvp):
        if (rsvp == null) return const FirebaseSuccess(ScanOutcome.invalid);
        return switch (rsvp.status) {
          RsvpStatus.attended => const FirebaseSuccess(
            ScanOutcome.alreadyScanned,
          ),
          RsvpStatus.cancelled || RsvpStatus.waitlist => const FirebaseSuccess(
            ScanOutcome.invalid,
          ),
          // Yöneticinin kendi bileti: kendi yoklamasını alamaz (rules-spec
          // §3.8) — başka bir yönetici okutur.
          RsvpStatus.going when rsvp.userId == actorId => const FirebaseSuccess(
            ScanOutcome.invalid,
          ),
          RsvpStatus.going => _attend(
            eventId: eventId,
            userId: rsvp.userId,
            attended: true,
            actorId: actorId,
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
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'eventId': eventId,
          'userId': userId,
          'actorId': actorId,
        })
        case final rejected?) {
      return rejected;
    }
    final result = await _attend(
      eventId: eventId,
      userId: userId,
      attended: attended,
      actorId: actorId,
    );
    return result.map((_) {});
  }

  @override
  Future<FirestoreResult<BulkResult>> markAllAttended({
    required String eventId,
    required String clubId,
    required String actorId,
    void Function(int done, int total)? onProgress,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<BulkResult>({
          'eventId': eventId,
          'clubId': clubId,
          'actorId': actorId,
        })
        case final rejected?) {
      return rejected;
    }
    final List<RsvpModel> going;
    switch (await listParticipants(
      eventId: eventId,
      clubId: clubId,
      statuses: const {RsvpStatus.going},
    )) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(:final data):
        // Kendi kaydı kümeye girmez (rules-spec §3.8 — başka yönetici alır).
        going = [
          for (final rsvp in data)
            if (rsvp.userId != actorId) rsvp,
        ];
    }
    final succeeded = <String>[];
    final conflicted = <String>[];
    final failed = <String>[];
    // Her kayıt ayrı transaction (Rules sayaç dalı tam ±1 ister; `+n` yok).
    for (final (index, rsvp) in going.indexed) {
      final result = await _attend(
        eventId: eventId,
        userId: rsvp.userId,
        attended: true,
        actorId: actorId,
        clubId: clubId,
      );
      switch (result) {
        case FirebaseSuccess():
          succeeded.add(rsvp.userId);
        case FirebaseFailure(error: FirestoreError.conflict):
          conflicted.add(rsvp.userId);
        // Pencere kapandı: kalan kayıtlar da yazılamaz.
        case FirebaseFailure(
              error: FirestoreError.ruleViolation,
              :final FirestoreFailureDetail detail,
              :final message,
            )
            when detail.code == FirestoreRuleCode.attendanceWindowClosed:
          return FirebaseFailure(
            FirestoreError.ruleViolation,
            message: message,
            detail: detail,
          );
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
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'eventId': eventId,
          'userId': userId,
          'actorId': actorId,
        })
        case final rejected?) {
      return rejected;
    }
    if (_rejectSelf<void>(userId, actorId) case final rejected?) {
      return rejected;
    }
    final eventRef = _eventRef(eventId);
    final rsvpRef = _rsvpRef(eventId, userId);
    return _transact((tx) async {
      // Transaction kuralı: tüm okumalar yazımlardan önce.
      final eventSnapshot = await tx.get(eventRef);
      final rsvpSnapshot = await tx.get(rsvpRef);
      final event = _publishedEvent(eventSnapshot);
      final rsvp = _managedRsvp(rsvpSnapshot, event, eventId, userId);
      if (!event.endsAt.isAfter(_clock.nowUtc())) {
        throw _violation(FirestoreRuleCode.eventEnded);
      }
      // Kontenjan kararı bu işlemde okunan sayaçtan (Rules `capacityHolds`).
      if (event.isFull) throw _violation(FirestoreRuleCode.capacityFull);
      if (rsvp?.status != RsvpStatus.waitlist) {
        throw const ConflictException.conflict();
      }
      // Yalnızca `status`: bekleme anı ve bilet kodu yerinde kalır.
      tx
        ..update(rsvpRef, {
          FirestoreFields.status: RsvpStatus.going.json,
          ...BaseFieldsPayload.update(),
        })
        ..update(eventRef, {
          FirestoreFields.goingCount: FieldValue.increment(_entered),
          FirestoreFields.waitlistCount: FieldValue.increment(_left),
          ...BaseFieldsPayload.update(),
        });
      _pointCounter(tx, event, eventId, userId);
      // Geçersiz girdide dağıtıcı fırlatır (işlem düşer); başarısızlık
      // sonucu da işlemi düşürür ([_Abort] gövdeden kaçar — yazımlar kuyrukta
      // olduğundan [_Halt] gibi sonuca çevrilmez): terfi bildirimsiz
      // kesinleşmez.
      final notified = await _notifications.notifyWaitlistPromotedInTransaction(
        eventId: eventId,
        clubId: event.clubId,
        userId: userId,
        transaction: tx,
      );
      if (notified case FirebaseFailure(:final error, :final message)) {
        throw _Abort(error, message);
      }
    });
  }

  /// Yoklama geçişi: [attended] `true` ise `going → attended`, `false` ise
  /// `attended → going` — kayıt, `attendedCount ±1` ve yan belge tek
  /// transaction'da.
  ///
  /// [clubId] verilirse etkinlik o kulübün olmalıdır
  /// ([FirestoreError.invalidArgument]). [ticketCode] verilirse (bilet
  /// okutma) kayıt işlem içinde yeniden okunur: kayıt yoksa ya da kod
  /// tutmuyorsa [ScanOutcome.invalid], zaten `attended` ise
  /// [ScanOutcome.alreadyScanned] (ikisinde de yazım yok). Başarı
  /// [ScanOutcome.valid].
  Future<FirestoreResult<ScanOutcome>> _attend({
    required String eventId,
    required String userId,
    required bool attended,
    required String actorId,
    String? clubId,
    String? ticketCode,
  }) {
    if (_rejectSelf<ScanOutcome>(userId, actorId) case final rejected?) {
      return Future.value(rejected);
    }
    final eventRef = _eventRef(eventId);
    final rsvpRef = _rsvpRef(eventId, userId);
    final from = attended ? RsvpStatus.going : RsvpStatus.attended;
    final to = attended ? RsvpStatus.attended : RsvpStatus.going;
    return _transact((tx) async {
      final eventSnapshot = await tx.get(eventRef);
      final rsvpSnapshot = await tx.get(rsvpRef);
      final event = _publishedEvent(eventSnapshot, clubId: clubId);
      final rsvp = _managedRsvp(rsvpSnapshot, event, eventId, userId);
      // K-G penceresi (Rules ile aynı uçlar; iki uç dahil).
      if (!event.attendanceWindow(_clock)) {
        throw _violation(FirestoreRuleCode.attendanceWindowClosed);
      }
      if (ticketCode != null) {
        if (rsvp == null || rsvp.ticketCode != ticketCode) {
          return ScanOutcome.invalid;
        }
        if (rsvp.status == RsvpStatus.attended) {
          return ScanOutcome.alreadyScanned;
        }
      }
      if (rsvp?.status != from) throw const ConflictException.conflict();
      tx
        ..update(rsvpRef, {
          FirestoreFields.status: to.json,
          FirestoreFields.scannedAt: attended
              ? _firestore.serverTimestamp()
              : null,
          FirestoreFields.scannedBy: attended ? actorId : null,
          ...BaseFieldsPayload.update(),
        })
        ..update(eventRef, {
          FirestoreFields.attendedCount: FieldValue.increment(
            attended ? _entered : _left,
          ),
          ...BaseFieldsPayload.update(),
        });
      _pointCounter(tx, event, eventId, userId);
      return ScanOutcome.valid;
    });
  }

  /// Yan belge `events/{eventId}/private/counter`'ı [tx]'e yazar: sayacı
  /// oynatan kaydın yolu (W-64 — yalnızca `seesMgmt` okur). `set`: önceki
  /// işaretçinin yerine geçer.
  void _pointCounter(
    Transaction tx,
    EventModel event,
    String eventId,
    String userId,
  ) => tx.set(_counterRef(eventId), {
    FirestoreFields.clubId: event.clubId,
    FirestoreFields.lastRsvpRef: FirestoreIds.rsvpRef(eventId, userId),
    ...BaseFieldsPayload.update(),
  });

  /// [body] gövdesini transaction içinde çalıştırır. Gövde, yazım kuyruğa
  /// girmeden **önce** reddedebilir: `ConflictException` (çakışma / iş
  /// kuralı) ya da [_Halt] (bulunamadı, ayrıştırılamadı, geçersiz girdi,
  /// başka kaydın kimliği). Yazımlar kuyruğa girdikten **sonra** reddetmek
  /// için gövde [_Abort] fırlatır: istisna gövdeden kaçar, SDK işlemi
  /// commit etmez ve sonuç [_Abort]'un hatasıdır (güvenlik incelemesi T-30).
  Future<FirestoreResult<T>> _transact<T>(
    Future<T> Function(Transaction tx) body,
  ) async {
    _Abort? aborted;
    final result = await _firestore.runTransaction<FirestoreResult<T>>((
      tx,
    ) async {
      aborted = null;
      try {
        return FirebaseSuccess(await body(tx));
      } on _Halt catch (halt) {
        return FirebaseFailure(halt.error, message: halt.message);
      } on _Abort catch (abort) {
        aborted = abort;
        rethrow;
      }
    });
    if (aborted case final abort?) {
      return FirebaseFailure(abort.error, message: abort.message);
    }
    return switch (result) {
      FirebaseSuccess(:final data) => data,
      FirebaseFailure(:final error, :final message, :final detail) =>
        FirebaseFailure(error, message: message, detail: detail),
    };
  }

  /// İşlemde okunan yayındaki etkinlik: belge yoksa
  /// [FirestoreError.notFound]; [clubId] verilmiş ve etkinlik başka kulübünse
  /// [FirestoreError.invalidArgument]; silinmiş ya da yayında değilse
  /// [FirestoreError.conflict] (durum değişmiş — DLG-18); ayrıştırılamıyorsa
  /// [FirestoreError.parse].
  static EventModel _publishedEvent(
    DocumentSnapshot<Json> snapshot, {
    String? clubId,
  }) {
    final doc = FirestoreDoc.fromSnapshot(snapshot);
    if (doc == null) {
      throw _Halt(FirestoreError.notFound, '${snapshot.reference.path}: yok');
    }
    final event = _parsed(doc, FirebaseEventRepository.eventOf);
    if (clubId != null && event.clubId != clubId) {
      throw _Halt(
        FirestoreError.invalidArgument,
        '${doc.path}: başka kulübün etkinliği',
      );
    }
    if (event.isDeleted || event.status != EventStatus.published) {
      throw const ConflictException.conflict();
    }
    return event;
  }

  /// İşlemde okunan ([eventId], [userId]) kaydı; belge yoksa `null`.
  ///
  /// Bileşik kimlik tek başına kanıt değildir (`a_b` + `c` = `a` + `b_c`):
  /// kayıt alanları ([eventId], [userId], etkinliğin kulübü) tutmuyorsa
  /// [FirestoreError.permissionDenied] (Rules da aynısını reddeder);
  /// ayrıştırılamıyorsa [FirestoreError.parse].
  static RsvpModel? _managedRsvp(
    DocumentSnapshot<Json> snapshot,
    EventModel event,
    String eventId,
    String userId,
  ) {
    final doc = FirestoreDoc.fromSnapshot(snapshot);
    if (doc == null) return null;
    final rsvp = _parsed(doc, _rsvpOf);
    if (rsvp.eventId != eventId ||
        rsvp.userId != userId ||
        rsvp.clubId != event.clubId) {
      throw _Halt(
        FirestoreError.permissionDenied,
        '${doc.path}: başka bir kaydın kimliği',
      );
    }
    return rsvp;
  }

  /// Sorgu sonucunu kayıtlara çevirir; sıra `status`, `waitlistAt` (boş
  /// önce), `userId`.
  ///
  /// Sıralama istemcidedir: `orderBy(waitlistAt)` alanı **olmayan** belgeyi
  /// sonuçtan düşürür (Firestore) ve `going` kaydı alanı hiç yazmaz (W-51).
  static FirestoreResult<List<RsvpModel>> _participantsOf(
    FirestoreResult<List<FirestoreDoc>> result,
  ) => RepositoryHelpers.parseAll(
    result,
    _rsvpOf,
  ).map((rsvps) => [...rsvps]..sort(_byStatusThenQueue));

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

  static T _parsed<T>(FirestoreDoc doc, T Function(FirestoreDoc doc) fromDoc) =>
      switch (RepositoryHelpers.parse(doc, fromDoc)) {
        FirebaseSuccess(:final data) => data,
        FirebaseFailure(:final error, :final message) => throw _Halt(
          error,
          message,
        ),
      };

  /// [code] iş kuralının reddi; kod başarısızlığın `detail` alanında taşınır.
  static ConflictException _violation(FirestoreRuleCode code) =>
      ConflictException(code, detail: FirestoreFailureDetail(code));

  /// Katılımcının kendisi — yönetici de — kendi kaydının yoklamasını alamaz /
  /// geri alamaz, kendini terfi ettiremez (rules-spec §3.8; Rules
  /// `managedHere` aynısını reddeder): [userId] == [actorId] ise
  /// [FirestoreError.invalidArgument], işlem açılmaz.
  static FirestoreResult<T>? _rejectSelf<T>(String userId, String actorId) =>
      userId == actorId
      ? const FirebaseFailure(
          FirestoreError.invalidArgument,
          message: 'yönetici kendi kaydında yoklama / terfi yapamaz',
        )
      : null;

  static FirestoreResult<T>? _rejectScope<T>(String eventId, String clubId) =>
      RepositoryHelpers.rejectInvalidIds<T>({
        'eventId': eventId,
        'clubId': clubId,
      });

  static RsvpModel _rsvpOf(FirestoreDoc doc) =>
      RsvpModel.fromJson(doc.data, id: doc.id);

  /// [clubId] kulübünün [eventId] etkinliğinin kayıtları (Rules
  /// `seesMgmt(clubId)` ister, bu yüzden kulüp süzgeci zorunludur).
  Query<Json> _inEvent(String eventId, String clubId) => _firestore
      .collection(FirestoreCollections.rsvps)
      .where(FirestoreFields.eventId, isEqualTo: eventId)
      .where(FirestoreFields.clubId, isEqualTo: clubId);

  DocumentReference<Json> _eventRef(String eventId) =>
      _firestore.doc(FirestoreCollections.events, eventId);

  DocumentReference<Json> _rsvpRef(String eventId, String userId) =>
      _firestore.doc(
        FirestoreCollections.rsvps,
        FirestoreIds.rsvp(eventId, userId),
      );

  DocumentReference<Json> _counterRef(String eventId) => _firestore.doc(
    RepositoryHelpers.subcollectionPath(
      FirestoreCollections.events,
      eventId,
      FirestoreCollections.privateSub,
    ),
    FirestoreCollections.counterDoc,
  );
}

/// Transaction gövdesinin, yazım kuyruğa girmeden işlemi durdurduğu hata
/// (bulunamadı, ayrıştırılamadı, geçersiz girdi, başka kaydın kimliği).
/// Çakışma ve iş kuralı reddi bunun yerine `ConflictException` ile
/// bildirilir.
final class _Halt implements Exception {
  const _Halt(this.error, this.message);

  final FirestoreError error;
  final String? message;
}

/// Yazımlar transaction'a eklendikten sonraki ret: [_Halt]'ın aksine
/// gövdeden kaçar (işlem commit edilmez); `_transact` sonucu [error] olur.
final class _Abort implements Exception {
  const _Abort(this.error, this.message);

  final FirestoreError error;
  final String? message;
}
