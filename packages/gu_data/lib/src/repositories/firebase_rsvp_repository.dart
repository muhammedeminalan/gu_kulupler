import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/conflict_exception.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/firestore_failure_detail.dart';
import 'package:gu_data/src/models/enums/event_status.dart';
import 'package:gu_data/src/models/enums/reminder_option.dart';
import 'package:gu_data/src/models/enums/rsvp_status.dart';
import 'package:gu_data/src/models/event_model.dart';
import 'package:gu_data/src/models/rsvp_model.dart';
import 'package:gu_data/src/repositories/query_x.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/repositories/rsvp_repository.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/utils/ticket_code.dart';

/// [RsvpRepository] uygulaması: `rsvps/{eventId}_{userId}` (PLAN §10.4;
/// sözleşme `docs/plans/T-22.md §6.3–§6.5`, `§6.8`).
///
/// Durumu değiştiren her yazım **tek transaction**'dır: katılım kaydı ile
/// etkinliğin `goingCount` / `waitlistCount` deltası birlikte işlenir (ya
/// ikisi ya hiçbiri). Sayaç mutlak değerle yazılmaz (`FieldValue.increment`);
/// kontenjan kararı işlem içinde okunan etkinlikten verilir, aynı anda gelen
/// ikinci istek çakışmada yeniden koşar ve güncel sayacı görür.
///
/// Etkinlik belgesine kaydın yolunu gösteren işaretçi **yazılmaz** (W-64):
/// belge doğrulanmış herkese açıktır; Security Rules yolu oturumdan türetir.
/// Üyelik (üyelere özel etkinlik), hesap ve kulüp durumu burada okunmaz —
/// Rules'ta denetlenir, ret [FirestoreError.permissionDenied] olarak döner.
final class FirebaseRsvpRepository implements RsvpRepository {
  /// [_firestore] servisi üzerinden okur ve yazar; bilet kodunu
  /// [_ticketCodes] üreticisinden, "şu an"ı [_clock] saatinden alır.
  FirebaseRsvpRepository(this._firestore, this._ticketCodes, this._clock);

  final FirestoreService _firestore;
  final TicketCodeGenerator _ticketCodes;
  final AppClock _clock;

  /// Sayaç deltası: kayıt `going` / `waitlist` durumuna girdi.
  static const int _entered = 1;

  /// Sayaç deltası: kayıt `going` / `waitlist` durumundan çıktı.
  static const int _left = -1;

  /// `findByTicket` en çok iki kayıt okur: ikinci eşleşme, kodun
  /// kopyalandığını gösterir (belirsiz eşleşme).
  static const int _ambiguousMatch = 2;

  static final RegExp _ticketCode = RegExp(FirestoreIds.ticketCodePattern);

  @override
  Future<FirestoreResult<RsvpModel>> join({
    required String eventId,
    required String clubId,
    required String userId,
    required ReminderOption reminder,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<RsvpModel>({
          'eventId': eventId,
          'clubId': clubId,
          'userId': userId,
        })
        case final rejected?) {
      return rejected;
    }
    final eventRef = _eventRef(eventId);
    final rsvpRef = _rsvpRef(eventId, userId);
    // Kod gövdenin dışında tutulur: çakışmada yeniden koşan işlem aynı kodu
    // yazar; yeniden katılımda hiç üretilmez.
    String? issuedCode;

    Future<FirestoreResult<RsvpModel>> attempt() => _transact((tx) async {
      // Transaction kuralı: tüm okumalar yazımlardan önce.
      final eventSnapshot = await tx.get(eventRef);
      final current = _ownRsvp(await tx.get(rsvpRef), eventId, userId);
      final event = _liveEvent(eventSnapshot, clubId);
      final now = _clock.nowUtc();

      if (event.status != EventStatus.published || !event.registrationOpen) {
        throw _violation(FirestoreRuleCode.registrationClosed);
      }
      if (!event.endsAt.isAfter(now)) {
        throw _violation(FirestoreRuleCode.eventEnded);
      }
      if (current != null && current.status != RsvpStatus.cancelled) {
        throw const ConflictException.conflict();
      }

      // Kontenjan kararı bu işlemde okunan sayaçtan: yer yoksa ya da önde
      // bekleyen varsa bekleme listesi (boşalan yer önce bekleyenindir).
      final waitlisted = event.joinsWaitlist;
      final status = waitlisted ? RsvpStatus.waitlist : RsvpStatus.going;
      final RsvpModel joined;
      if (current == null) {
        // `null` alanların anahtarı yazılmaz (W-51); `waitlistAt` yalnızca
        // bekleme listesinde, sunucu zamanıyla.
        final rsvp = RsvpModel(
          eventId: eventId,
          clubId: clubId,
          userId: userId,
          ticketCode: issuedCode ??= _ticketCodes.ticketCode(),
          status: status,
          reminder: reminder,
        );
        tx.set(rsvpRef, {
          ...rsvp.toJson(),
          if (waitlisted)
            FirestoreFields.waitlistAt: _firestore.serverTimestamp(),
          ...BaseFieldsPayload.create(),
        });
        joined = rsvp.copyWith(
          waitlistAt: waitlisted ? now : null,
          createdAt: now,
          updatedAt: now,
        );
      } else {
        // Yeniden katılım: aynı belge, aynı bilet kodu; `createdAt` korunur.
        tx.update(rsvpRef, {
          FirestoreFields.status: status.json,
          FirestoreFields.reminder: reminder.json,
          FirestoreFields.waitlistAt: waitlisted
              ? _firestore.serverTimestamp()
              : null,
          ...BaseFieldsPayload.update(),
        });
        joined = current.copyWith(
          status: status,
          reminder: reminder,
          waitlistAt: waitlisted ? now : null,
          clearWaitlistAt: !waitlisted,
          updatedAt: now,
        );
      }
      tx.update(eventRef, _counterPayload(status, _entered));

      // Sunucu zamanı işlem içinde okunamaz: zaman alanları yaklaşık değerdir.
      return joined;
    });

    // Kontenjan yarışında kaybeden işlemin commit'i, sunucu çakışmayı
    // bildirmeden Security Rules'a takılabilir (`permission-denied`: bayat
    // okumayla `going` yazımı kontenjanı aşar; emülatör böyle döner ve SDK
    // yeniden denemez — `firebase/test/rules/repository_payloads.test.js`
    // "iki eşzamanlı katılım"). İşlem güncel sayaçla **bir kez** daha koşar
    // (yer yoksa bekleme listesi); gerçek yetki reddi ikinci denemede de döner.
    final first = await attempt();
    if (first case FirebaseFailure(error: FirestoreError.permissionDenied)) {
      return attempt();
    }
    return first;
  }

  @override
  Future<FirestoreResult<void>> cancel({
    required String eventId,
    required String userId,
  }) async {
    if (_rejectPair<void>(eventId, userId) case final rejected?) {
      return rejected;
    }
    final eventRef = _eventRef(eventId);
    final rsvpRef = _rsvpRef(eventId, userId);
    return _transact((tx) async {
      final current = _ownRsvp(await tx.get(rsvpRef), eventId, userId);
      if (current == null) {
        throw _Halt(FirestoreError.notFound, '${rsvpRef.path}: yok');
      }
      switch (current.status) {
        case RsvpStatus.cancelled:
          // Zaten vazgeçilmiş: yazım yok (çift dokunma, iki cihaz).
          return;
        case RsvpStatus.attended:
          throw _Halt(
            FirestoreError.failedPrecondition,
            '${rsvpRef.path}: yoklaması alınmış',
          );
        case RsvpStatus.going || RsvpStatus.waitlist:
          // Etkinliğin yalnızca bitişi aranır (durumu ve kulübün askısı
          // aranmaz; askıdaki hesap da vazgeçebilir): bitmiş etkinlikte
          // "Gelmedin" kaydı iptale çevrilip yoklama oranı şişirilemez
          // (Rules `canCancelRsvp`; CD-144). Boşalan yere kimse alınmaz.
          final eventDoc = FirestoreDoc.fromSnapshot(await tx.get(eventRef));
          if (eventDoc == null) {
            throw _Halt(FirestoreError.notFound, '${eventRef.path}: yok');
          }
          final event = _parsed(eventDoc, _eventOf);
          if (!event.endsAt.isAfter(_clock.nowUtc())) {
            throw _violation(FirestoreRuleCode.eventEnded);
          }
          tx
            ..update(rsvpRef, {
              FirestoreFields.status: RsvpStatus.cancelled.json,
              ...BaseFieldsPayload.update(),
            })
            ..update(eventRef, _counterPayload(current.status, _left));
      }
    });
  }

  @override
  Future<FirestoreResult<void>> setReminder({
    required String eventId,
    required String userId,
    required ReminderOption reminder,
  }) async {
    if (_rejectPair<void>(eventId, userId) case final rejected?) {
      return rejected;
    }
    final rsvpRef = _rsvpRef(eventId, userId);
    return _transact((tx) async {
      final current = _ownRsvp(await tx.get(rsvpRef), eventId, userId);
      final status = current?.status;
      if (status != RsvpStatus.going && status != RsvpStatus.waitlist) {
        // Katılmadan hatırlatıcı ayarlanamaz (TST-X7).
        throw _violation(FirestoreRuleCode.notMember);
      }
      tx.update(rsvpRef, {
        FirestoreFields.reminder: reminder.json,
        ...BaseFieldsPayload.update(),
      });
    });
  }

  @override
  Future<FirestoreResult<RsvpModel?>> getMine({
    required String eventId,
    required String userId,
  }) async {
    if (_rejectPair<RsvpModel?>(eventId, userId) case final rejected?) {
      return rejected;
    }
    return _mine(
      await _firestore.getDoc(_rsvpRef(eventId, userId)),
      eventId,
      userId,
    );
  }

  @override
  Stream<FirestoreResult<RsvpModel?>> watchMine({
    required String eventId,
    required String userId,
  }) {
    if (_rejectPair<RsvpModel?>(eventId, userId) case final rejected?) {
      return Stream.value(rejected);
    }
    return _firestore
        .watchDoc(_rsvpRef(eventId, userId))
        .map((event) => _mine(event, eventId, userId));
  }

  @override
  Future<FirestoreResult<List<RsvpModel>>> listMine(
    String userId, {
    Set<RsvpStatus>? statuses,
    String? clubId,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<List<RsvpModel>>({
          'userId': userId,
          'clubId': ?clubId,
        })
        case final rejected?) {
      return rejected;
    }
    // Boş `whereIn` geçersiz bir sorgudur; boş küme = eşleşme yok.
    if (statuses != null && statuses.isEmpty) return const FirebaseSuccess([]);
    final mine = _rsvps
        .where(FirestoreFields.userId, isEqualTo: userId)
        .notDeleted();
    // Sorgu sözleşmesi (rules-spec §6, EVT-04 / PRF-03): sahibi + silinmemiş,
    // en yeni üstte; vazgeçilmiş kayıtlar dahildir. Süzgeçli kip (T-44 ·
    // D3-02) yalnızca eşitlik / `in` taşır ve sırasızdır (indeksler rules-spec
    // §8).
    final Query<Json> query;
    if (statuses == null && clubId == null) {
      query = mine.orderBy(FirestoreFields.createdAt, descending: true);
    } else {
      var filtered = mine;
      if (clubId != null) {
        filtered = filtered.where(FirestoreFields.clubId, isEqualTo: clubId);
      }
      if (statuses != null) {
        filtered = filtered.where(
          FirestoreFields.status,
          whereIn: [for (final status in statuses) status.json],
        );
      }
      query = filtered;
    }
    return RepositoryHelpers.parseAll(
      await _firestore.getList(query),
      _rsvpOf,
    );
  }

  @override
  Future<FirestoreResult<int>> waitlistPosition({
    required String eventId,
    required String clubId,
    required DateTime waitlistAtUtc,
  }) async {
    if (_rejectScope<int>(eventId, clubId) case final rejected?) {
      return rejected;
    }
    // Sıra = önce girmiş bekleyenlerin sayısı + 1. Katılım kaydı hiç soft
    // delete edilmez: süzgeç ve indeks `isDeleted` taşımaz (rules-spec §8).
    final earlier = await _firestore.count(
      _inEvent(eventId, clubId)
          .where(FirestoreFields.status, isEqualTo: RsvpStatus.waitlist.json)
          .where(
            FirestoreFields.waitlistAt,
            isLessThan: Timestamp.fromDate(waitlistAtUtc.toUtc()),
          ),
    );
    return earlier.map((ahead) => ahead + 1);
  }

  @override
  Future<FirestoreResult<RsvpModel?>> findByTicket({
    required String eventId,
    required String clubId,
    required String code,
  }) async {
    if (_rejectScope<RsvpModel?>(eventId, clubId) case final rejected?) {
      return rejected;
    }
    // Biçimi tutmayan kod (elle girilmiş, bozuk QR) hiçbir kayıtla eşleşmez.
    if (!_ticketCode.hasMatch(code)) return const FirebaseSuccess(null);
    // Yalnızca eşitlik süzgeçleri: bileşik indeks gerekmez. Arama etkinliğe ve
    // kulübe kapsamlıdır — başka etkinliğin bileti eşleşmez.
    final found = RepositoryHelpers.parseAll(
      await _firestore.getList(
        _inEvent(eventId, clubId)
            .where(FirestoreFields.ticketCode, isEqualTo: code)
            .limit(_ambiguousMatch),
      ),
      _rsvpOf,
    );
    return switch (found) {
      // Kodu istemci üretir ve Rules tekillik aramaz: başkasının kodunu
      // kopyalayan ikinci kayıt, gerçek sahibin okutmasını kendine
      // çeviremez — eşleşme belirsizdir, hiçbiri döndürülmez.
      FirebaseSuccess(data: [_, _, ...]) => FirebaseFailure(
        FirestoreError.failedPrecondition,
        message: 'bilet kodu birden çok kayıtta: $eventId',
      ),
      FirebaseSuccess(:final data) => FirebaseSuccess(data.firstOrNull),
      FirebaseFailure(:final error, :final message, :final detail) =>
        FirebaseFailure(error, message: message, detail: detail),
    };
  }

  /// [body] gövdesini transaction içinde çalıştırır. Gövde, yazım kuyruğa
  /// girmeden **önce** reddedebilir: `ConflictException` (çakışma / iş
  /// kuralı) ya da [_Halt] (bulunamadı, ön koşul, ayrıştırılamadı, geçersiz
  /// girdi).
  Future<FirestoreResult<T>> _transact<T>(
    Future<T> Function(Transaction tx) body,
  ) async {
    final result = await _firestore.runTransaction<FirestoreResult<T>>((
      tx,
    ) async {
      try {
        return FirebaseSuccess(await body(tx));
      } on _Halt catch (halt) {
        return FirebaseFailure(halt.error, message: halt.message);
      }
    });
    return switch (result) {
      FirebaseSuccess(:final data) => data,
      FirebaseFailure(:final error, :final message, :final detail) =>
        FirebaseFailure(error, message: message, detail: detail),
    };
  }

  /// Tekil okuma sonucunu [userId] kullanıcısının [eventId] kaydına çevirir;
  /// belge yoksa ya da başka bir (etkinlik, kullanıcı) çiftine aitse başarı
  /// `null` ([_isOwn]).
  static FirestoreResult<RsvpModel?> _mine(
    FirestoreResult<FirestoreDoc?> result,
    String eventId,
    String userId,
  ) => RepositoryHelpers.parseOrNull(
    result,
    _rsvpOf,
  ).map((rsvp) => rsvp != null && _isOwn(rsvp, eventId, userId) ? rsvp : null);

  /// İşlemde okunan, [userId] kullanıcısının [eventId] kaydı; belge yoksa
  /// `null`. Ayrıştırılamıyorsa [FirestoreError.parse], kimlik başka bir
  /// (etkinlik, kullanıcı) çiftinin kaydına denk geliyorsa
  /// [FirestoreError.permissionDenied] ile işlemi durdurur ([_isOwn]).
  static RsvpModel? _ownRsvp(
    DocumentSnapshot<Json> snapshot,
    String eventId,
    String userId,
  ) {
    final doc = FirestoreDoc.fromSnapshot(snapshot);
    if (doc == null) return null;
    final rsvp = _parsed(doc, _rsvpOf);
    if (!_isOwn(rsvp, eventId, userId)) {
      throw _Halt(
        FirestoreError.permissionDenied,
        '${doc.path}: başka bir kaydın kimliği',
      );
    }
    return rsvp;
  }

  /// [rsvp] gerçekten ([eventId], [userId]) çiftinin kaydı mı?
  ///
  /// Bileşik kimlik tek başına kanıt değildir: `a_b` + `c` ile `a` + `b_c`
  /// aynı kimliği üretir. Sahiplik belgenin alanlarından okunur (Security
  /// Rules da aynısını yapar — `docs/plans/T-22.md §6.1`).
  static bool _isOwn(RsvpModel rsvp, String eventId, String userId) =>
      rsvp.eventId == eventId && rsvp.userId == userId;

  /// İşlemde okunan, [clubId] kulübüne ait etkinlik: belge yoksa ya da
  /// silinmişse [FirestoreError.notFound], başka kulübün etkinliğiyse
  /// [FirestoreError.invalidArgument], ayrıştırılamıyorsa
  /// [FirestoreError.parse] ile işlemi durdurur.
  static EventModel _liveEvent(DocumentSnapshot<Json> snapshot, String clubId) {
    final doc = FirestoreDoc.fromSnapshot(snapshot);
    if (doc == null || RepositoryHelpers.isSoftDeleted(doc)) {
      throw _Halt(FirestoreError.notFound, '${snapshot.reference.path}: yok');
    }
    final event = _parsed(doc, _eventOf);
    if (event.clubId != clubId) {
      throw _Halt(
        FirestoreError.invalidArgument,
        '${doc.path}: başka kulübün etkinliği',
      );
    }
    return event;
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

  /// Etkinliğin sayaç yazımı: [status] durumunun sayacı (`going` →
  /// `goingCount`, `waitlist` → `waitlistCount`) [delta] kadar değişir.
  /// Değer hesaplanıp yazılmaz, yalnızca delta gönderilir; kaydın yolu
  /// etkinlik belgesine **yazılmaz** (W-64).
  static Json _counterPayload(RsvpStatus status, int delta) => {
    (status == RsvpStatus.waitlist
        ? FirestoreFields.waitlistCount
        : FirestoreFields.goingCount): FieldValue.increment(
      delta,
    ),
    ...BaseFieldsPayload.update(),
  };

  static FirestoreResult<T>? _rejectPair<T>(String eventId, String userId) =>
      RepositoryHelpers.rejectInvalidIds<T>({
        'eventId': eventId,
        'userId': userId,
      });

  static FirestoreResult<T>? _rejectScope<T>(String eventId, String clubId) =>
      RepositoryHelpers.rejectInvalidIds<T>({
        'eventId': eventId,
        'clubId': clubId,
      });

  static RsvpModel _rsvpOf(FirestoreDoc doc) =>
      RsvpModel.fromJson(doc.data, id: doc.id);

  static EventModel _eventOf(FirestoreDoc doc) =>
      EventModel.fromJson(doc.data, id: doc.id);

  Query<Json> get _rsvps => _firestore.collection(FirestoreCollections.rsvps);

  /// [clubId] kulübünün [eventId] etkinliğinin kayıtları (yönetim sorguları:
  /// Rules `seesMgmt(clubId)` ister, bu yüzden kulüp süzgeci zorunludur).
  Query<Json> _inEvent(String eventId, String clubId) => _rsvps
      .where(FirestoreFields.eventId, isEqualTo: eventId)
      .where(FirestoreFields.clubId, isEqualTo: clubId);

  DocumentReference<Json> _eventRef(String eventId) =>
      _firestore.doc(FirestoreCollections.events, eventId);

  DocumentReference<Json> _rsvpRef(String eventId, String userId) =>
      _firestore.doc(
        FirestoreCollections.rsvps,
        FirestoreIds.rsvp(eventId, userId),
      );
}

/// Transaction gövdesinin, yazım kuyruğa girmeden işlemi durdurduğu hata
/// (bulunamadı, ön koşul, ayrıştırılamadı, geçersiz girdi). Çakışma ve iş
/// kuralı reddi bunun yerine `ConflictException` ile bildirilir.
final class _Halt implements Exception {
  const _Halt(this.error, this.message);

  final FirestoreError error;
  final String? message;
}
