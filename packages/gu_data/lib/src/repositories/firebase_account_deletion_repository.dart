import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/anonymization.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/account_deletion_plan.dart';
import 'package:gu_data/src/models/enums/club_role.dart';
import 'package:gu_data/src/models/enums/membership_status.dart';
import 'package:gu_data/src/models/enums/rsvp_status.dart';
import 'package:gu_data/src/models/enums/user_status.dart';
import 'package:gu_data/src/models/event_model.dart';
import 'package:gu_data/src/models/membership_model.dart';
import 'package:gu_data/src/models/rsvp_model.dart';
import 'package:gu_data/src/models/user_model.dart';
import 'package:gu_data/src/repositories/account_deletion_repository.dart';
import 'package:gu_data/src/repositories/event_repository.dart';
import 'package:gu_data/src/repositories/firebase_membership_repository.dart';
import 'package:gu_data/src/repositories/membership_repository.dart';
import 'package:gu_data/src/repositories/query_x.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/repositories/rsvp_repository.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/utils/retry_policy.dart';

/// [AccountDeletionRepository] uygulaması (SET-03; PLAN §10.4; domain-model
/// §11; sözleşme `docs/plans/T-29.md` §4).
///
/// Dizi: [precheck] → (çağıranda yeniden doğrulama) → [markDeleted] (tek
/// batch) → [resumeCleanup] = [buildPlan] + katılım parçaları
/// ([cancelRsvpChunk], transaction) → etkinliği okunamayan kayıtlar
/// ([cancelUnreadableRsvp], kayıt başına batch) → üyelik parçaları
/// ([anonymizeMembershipChunk] → `MembershipRepository.anonymizeChunk`,
/// transaction) → kişisel belge parçaları ([softDeletePersonalChunk],
/// batch). Katılımlar üyeliklerden **önce** işlenir: üyelere özel etkinlik
/// ancak etkin üyelikle okunur (Rules `seesInside`); okunamayan etkinliğin
/// kaydı (ayrılınan kulüp, yeniden başlayan dizide önce `left` olan üyelik)
/// etkinlik okunmadan vazgeçilir.
///
/// Her adım idempotenttir: [markDeleted] durumu okuyarak atlanır, plan her
/// çağrıda güncel durumdan çıkarılır (tamamlanmış iş plana girmez), parçalar
/// atomiktir ve işlem içinde güncel durumu yeniden okur; geçici hatada parça
/// [RetryPolicy] ile yeniden denenir, başarısız parça diziyi durdurmaz. Hiçbir
/// belge ve Auth kimliği silinmez (Q-11, D-10); oturum kapatma çağıranın
/// işidir.
final class FirebaseAccountDeletionRepository
    implements AccountDeletionRepository {
  /// Belgeleri [_firestore] ile okur / yazar; üyelikleri [_memberships],
  /// katılım kayıtlarını [_rsvps], etkinlik bitişlerini [_events] üzerinden
  /// okur. "Şu an" [_clock] saatindendir (W-80 bitiş süzgeci).
  /// [resumeCleanup] parçaları `retry` ile yeniden denenir (testler anında
  /// dönen bekleme verir).
  FirebaseAccountDeletionRepository(
    this._firestore,
    this._memberships,
    this._rsvps,
    this._events,
    this._clock, {
    this._retry = const RetryPolicy(),
  });

  final FirestoreService _firestore;
  final MembershipRepository _memberships;
  final RsvpRepository _rsvps;
  final EventRepository _events;
  final AppClock _clock;
  final RetryPolicy _retry;

  /// Katılım sayacı deltası: kayıt `going` / `waitlist` durumundan çıktı.
  static const int _left = -1;

  /// Hesap silmede vazgeçilen katılım durumları (W-80: `attended` ve
  /// `cancelled` dokunulmaz).
  static const Set<RsvpStatus> _openRsvp = {
    RsvpStatus.going,
    RsvpStatus.waitlist,
  };

  /// Durumu değişen üyelikler (`active → left`, `pending → cancelled`).
  static const Set<MembershipStatus> _liveMembership = {
    MembershipStatus.active,
    MembershipStatus.pending,
  };

  @override
  Future<FirestoreResult<DeletionPrecheck>> precheck(String uid) async {
    if (RepositoryHelpers.rejectInvalidIds<DeletionPrecheck>({'uid': uid})
        case final rejected?) {
      return rejected;
    }
    final active = await _memberships.listMine(
      uid,
      statuses: const {MembershipStatus.active},
    );
    return active.map((memberships) {
      final clubIds = [
        for (final membership in memberships)
          if (membership.role == ClubRole.president) membership.clubId,
      ]..sort();
      return clubIds.isEmpty
          ? const DeletionPrecheck.ready()
          : DeletionPrecheck.blockedByPresidency(clubIds);
    });
  }

  @override
  Future<FirestoreResult<void>> markDeleted(String uid) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({'uid': uid})
        case final rejected?) {
      return rejected;
    }
    switch (await _readUser(uid)) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(data: final user):
        // Dönüşü olmayan nokta önceden geçilmiş: yazım yok (idempotent).
        if (user.status == UserStatus.deleted) {
          return const FirebaseSuccess(null);
        }
        if (user.status != UserStatus.active || user.isDeleted) {
          return FirebaseFailure(
            FirestoreError.failedPrecondition,
            message: 'markDeleted: hesap etkin değil (${user.status.json})',
          );
        }
    }
    // Tek batch: profil ve e-posta birlikte anonimleşir (Rules iki belgeyi
    // `getAfter` ile karşılıklı bağlar). Servis yükü olduğu gibi yazar:
    // `userPayload` soft delete alanlarıyla `updatedAt`'i zaten taşır.
    return _firestore.commitBatch((batch) {
      batch
        ..update(_userRef(uid), Anonymization.userPayload(uid))
        ..update(_accountRef(uid), {
          ...Anonymization.accountPayload(),
          ...BaseFieldsPayload.update(),
        });
    });
  }

  @override
  Future<FirestoreResult<DeletionPlan>> buildPlan(String uid) async {
    if (RepositoryHelpers.rejectInvalidIds<DeletionPlan>({'uid': uid})
        case final rejected?) {
      return rejected;
    }
    switch (await _readUser(uid)) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(data: final user):
        if (user.status != UserStatus.deleted) {
          return FirebaseFailure(
            FirestoreError.failedPrecondition,
            message: 'buildPlan: hesap silinmemiş (${user.status.json})',
          );
        }
    }

    final List<RsvpModel> rsvps;
    final List<RsvpModel> unreadableRsvps;
    switch (await _openRsvps(uid)) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(:final data):
        (rsvps, unreadableRsvps) = data;
    }

    final List<MembershipModel> memberships;
    switch (await _memberships.listMine(uid)) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(:final data):
        memberships = [
          for (final membership in data)
            // Etkin başkan üyeliği `left` olamaz (Rules M14; kulübün devri —
            // W-90): durum değişmeden anonimleşir, anlık görüntüsü anonimse
            // plana girmez (yoksa temizlik hiç bitmezdi).
            if (membership.userId == uid &&
                ((_liveMembership.contains(membership.status) &&
                        !_isActivePresident(membership)) ||
                    membership.applicant !=
                        FirebaseMembershipRepository.anonymizedApplicant))
              membership,
        ]..sort((a, b) => a.clubId.compareTo(b.clubId));
    }

    final personalRefs = <PersonalDocRef>[];
    for (final kind in PersonalDocKind.values) {
      switch (await _firestore.getList(_personalQuery(kind, uid))) {
        case FirebaseFailure(:final error, :final message, :final detail):
          return FirebaseFailure(error, message: message, detail: detail);
        case FirebaseSuccess(data: final docs):
          personalRefs.addAll([
            for (final doc in docs) PersonalDocRef(kind, doc.id),
          ]);
      }
    }

    return FirebaseSuccess(
      DeletionPlan(
        rsvps: rsvps,
        unreadableRsvps: unreadableRsvps,
        memberships: memberships,
        personalRefs: personalRefs,
      ),
    );
  }

  @override
  Future<FirestoreResult<void>> cancelRsvpChunk(
    String uid,
    List<RsvpModel> chunk,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({'uid': uid})
        case final rejected?) {
      return rejected;
    }
    if (chunk.length > Limits.accountDeletionChunk) {
      return RepositoryHelpers.invalidArgument(
        'cancelRsvpChunk: ${chunk.length} kayıt, sınır '
        '${Limits.accountDeletionChunk}',
      );
    }
    final eventIds = <String>[];
    for (final rsvp in chunk) {
      if (rsvp.userId != uid) {
        return RepositoryHelpers.invalidArgument(
          'cancelRsvpChunk: başka kullanıcının kaydı',
        );
      }
      if (!RepositoryHelpers.isValidId(rsvp.eventId)) {
        return RepositoryHelpers.invalidArgument('geçersiz kimlik: eventId');
      }
      // Kimlik `eventId_uid`: aynı etkinlik iki kez = aynı belge iki kez.
      if (eventIds.contains(rsvp.eventId)) {
        return RepositoryHelpers.invalidArgument(
          'cancelRsvpChunk: aynı etkinlikten iki kayıt',
        );
      }
      eventIds.add(rsvp.eventId);
    }
    if (eventIds.isEmpty) return const FirebaseSuccess(null);

    final result = await _firestore.runTransaction<FirestoreResult<void>>((
      tx,
    ) async {
      try {
        // Transaction kuralı: tüm okumalar yazımlardan önce. Etkinlik yalnızca
        // vazgeçilecek kayıt için okunur.
        final open = <String, RsvpStatus>{};
        final events = <String, EventModel?>{};
        for (final eventId in eventIds) {
          final current = _ownRsvp(
            await tx.get(_rsvpRef(eventId, uid)),
            eventId,
            uid,
          );
          // Yok / zaten vazgeçilmiş / yoklaması alınmış: atlanır (W-80).
          if (current == null || !_openRsvp.contains(current.status)) continue;
          open[eventId] = current.status;
          events[eventId] = _liveEventOrNull(await tx.get(_eventRef(eventId)));
        }
        final cutoff = _endCutoff();
        for (final MapEntry(key: eventId, value: status) in open.entries) {
          final event = events[eventId];
          // Biten (ya da bitmek üzere olan) etkinliğin kaydı korunur: Rules
          // `canCancelRsvp` yalnızca bitmemiş etkinlikte vazgeçmeye izin verir
          // (CD-144); okunamayan / silinmiş etkinlik de atlanır.
          if (event == null || !event.endsAt.isAfter(cutoff)) continue;
          tx
            ..update(_rsvpRef(eventId, uid), {
              FirestoreFields.status: RsvpStatus.cancelled.json,
              ...BaseFieldsPayload.update(),
            })
            ..update(_eventRef(eventId), _counterPayload(status));
        }
        return const FirebaseSuccess(null);
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

  @override
  Future<FirestoreResult<void>> cancelUnreadableRsvp(
    String uid,
    RsvpModel rsvp,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'uid': uid,
          'eventId': rsvp.eventId,
        })
        case final rejected?) {
      return rejected;
    }
    if (rsvp.userId != uid) {
      return RepositoryHelpers.invalidArgument(
        'cancelUnreadableRsvp: başka kullanıcının kaydı',
      );
    }
    if (!_openRsvp.contains(rsvp.status)) return const FirebaseSuccess(null);
    // Etkinlik okunmaz (okunamıyor): sayaç kaydın durumundan seçilir. Rules
    // kaydın yazım-öncesi durumunu (`going | waitlist`) ve sayacın tam o
    // kadar oynadığını görür — bayat durum ya da çift −1 reddedilir.
    final result = await _firestore.commitBatch((batch) {
      batch
        ..update(_rsvpRef(rsvp.eventId, uid), {
          FirestoreFields.status: RsvpStatus.cancelled.json,
          ...BaseFieldsPayload.update(),
        })
        ..update(_eventRef(rsvp.eventId), _counterPayload(rsvp.status));
    });
    return switch (result) {
      // Bitmiş etkinlik (W-80: kayıt korunur), artık açık olmayan kayıt ya da
      // var olmayan etkinlik: yapılacak iş yok.
      FirebaseFailure(
        error: FirestoreError.permissionDenied || FirestoreError.notFound,
      ) =>
        const FirebaseSuccess(null),
      _ => result,
    };
  }

  @override
  Future<FirestoreResult<void>> anonymizeMembershipChunk(
    String uid,
    List<MembershipModel> chunk,
  ) => _memberships.anonymizeChunk(uid: uid, memberships: chunk);

  @override
  Future<FirestoreResult<void>> softDeletePersonalChunk(
    String uid,
    List<PersonalDocRef> refs,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({'uid': uid})
        case final rejected?) {
      return rejected;
    }
    if (refs.length > Limits.batchMaxWrites) {
      return RepositoryHelpers.invalidArgument(
        'softDeletePersonalChunk: ${refs.length} belge, sınır '
        '${Limits.batchMaxWrites}',
      );
    }
    for (final ref in refs) {
      if (!RepositoryHelpers.isValidId(ref.id)) {
        return RepositoryHelpers.invalidArgument('geçersiz kimlik: refs.id');
      }
    }
    if (refs.isEmpty) return const FirebaseSuccess(null);
    return _firestore.commitBatch((batch) {
      for (final ref in refs) {
        // Batch kipindeki yazımın hatası batch'i geçersiz kılar; sonucu
        // burada beklenmez.
        unawaited(
          _firestore.softDelete(_personalRef(ref), actorId: uid, batch: batch),
        );
      }
    });
  }

  @override
  Future<FirestoreResult<void>> resumeCleanup(
    String uid, {
    DeleteProgressCallback? onProgress,
  }) async {
    final DeletionPlan plan;
    switch (await buildPlan(uid)) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(:final data):
        plan = data;
    }
    final total = plan.chunkCount;
    var done = 0;
    FirestoreResult<void>? firstFailure;
    // Parçalar birbirinden bağımsızdır: biri düşse de kalanların kişisel
    // verisi boşalır (T-29 güvenlik incelemesi); ilk hata sonda döner,
    // sonraki çağrı planı güncel durumdan yeniden çıkarır.
    Future<void> run<T>(
      List<T> chunk,
      Future<FirestoreResult<void>> Function(List<T> chunk) write, {
      bool split = true,
    }) async {
      final result = await _runChunk(chunk, write, split: split);
      if (result is FirebaseFailure) {
        firstFailure ??= result;
        return;
      }
      onProgress?.call(DeleteProgress(done: ++done, total: total));
    }

    for (final chunk in plan.rsvpChunks) {
      await run(chunk, (part) => cancelRsvpChunk(uid, part));
    }
    for (final rsvp in plan.unreadableRsvps) {
      await run([rsvp], (part) => cancelUnreadableRsvp(uid, part.single));
    }
    for (final chunk in plan.membershipChunks) {
      await run(chunk, (part) => anonymizeMembershipChunk(uid, part));
    }
    for (final chunk in plan.personalChunks) {
      // 450'lik parça öğe öğe bölünmez (kalıcı hata = sonraki girişte yeniden).
      await run(
        chunk,
        (part) => softDeletePersonalChunk(uid, part),
        split: false,
      );
    }
    return firstFailure ?? const FirebaseSuccess(null);
  }

  /// [chunk] parçasını [write] ile yazar. Geçici hata (`aborted` /
  /// `unavailable`) [RetryPolicy] ile yeniden denenir; denemeler tükenirse
  /// (ağ yok) parça olduğu gibi düşer. Kalıcı hata veren çok öğeli parça
  /// ([split]) öğe öğe yeniden koşulur: tek bozuk öğe (ör. 0'a kaymış
  /// `memberCount`, bitmiş etkinlik) aynı parçadaki diğerlerini kilitlemez;
  /// öğelerin ilk hatası döner.
  Future<FirestoreResult<void>> _runChunk<T>(
    List<T> chunk,
    Future<FirestoreResult<void>> Function(List<T> chunk) write, {
    required bool split,
  }) async {
    final result = await _retry.run(() => write(chunk));
    final error = result.errorOrNull;
    if (error == null ||
        !split ||
        chunk.length == 1 ||
        RetryPolicy.shouldRetry(error)) {
      return result;
    }
    FirestoreResult<void>? failure;
    for (final item in chunk) {
      final single = await _retry.run(() => write([item]));
      if (single is FirebaseFailure) failure ??= single;
    }
    return failure ?? const FirebaseSuccess(null);
  }

  /// `users/{uid}` (silinmiş belge dahil); belge yoksa
  /// [FirestoreError.notFound].
  Future<FirestoreResult<UserModel>> _readUser(String uid) async =>
      switch (RepositoryHelpers.parseOrNull(
        await _firestore.getDoc(_userRef(uid)),
        _userOf,
        includeDeleted: true,
      )) {
        FirebaseSuccess(data: final user?) => FirebaseSuccess(user),
        FirebaseSuccess(data: null) => FirebaseFailure(
          FirestoreError.notFound,
          message: '${_userRef(uid).path}: yok',
        ),
        FirebaseFailure(:final error, :final message, :final detail) =>
          FirebaseFailure(error, message: message, detail: detail),
      };

  /// [uid] kullanıcısının vazgeçilecek açık (`going` / `waitlist`) katılım
  /// kayıtları, iki küme: etkinliği okunabilen, silinmemiş ve bitmemiş
  /// (`endsAt > şimdi + Limits.clockSkewTolerance` — W-80) olanlar ve
  /// etkinliği okunamayan / silinmiş / var olmayanlar (bitişi bilinemez;
  /// [cancelUnreadableRsvp] dener, bitmişse Rules reddeder). Okunabilen ama
  /// biten etkinliğin kaydı ikisine de girmez (korunur).
  Future<FirestoreResult<(List<RsvpModel>, List<RsvpModel>)>> _openRsvps(
    String uid,
  ) async {
    final List<RsvpModel> open;
    switch (await _rsvps.listMine(uid)) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(:final data):
        open = [
          for (final rsvp in data)
            if (rsvp.userId == uid && _openRsvp.contains(rsvp.status)) rsvp,
        ];
    }
    if (open.isEmpty) return const FirebaseSuccess(([], []));
    // Göremediği / var olmayan / silinmiş etkinlik sonuçta yer almaz.
    final events = await _events.getEvents([
      for (final rsvp in open) rsvp.eventId,
    ]);
    return events.map((events) {
      final cutoff = _endCutoff();
      final readable = {for (final event in events) event.id: event};
      int byEvent(RsvpModel a, RsvpModel b) => a.eventId.compareTo(b.eventId);
      return (
        [
          for (final rsvp in open)
            if (readable[rsvp.eventId]?.endsAt.isAfter(cutoff) ?? false) rsvp,
        ]..sort(byEvent),
        [
          for (final rsvp in open)
            if (!readable.containsKey(rsvp.eventId)) rsvp,
        ]..sort(byEvent),
      );
    });
  }

  /// Etkin başkan üyeliği mi (M14'te `left` olamaz)?
  static bool _isActivePresident(MembershipModel membership) =>
      membership.role == ClubRole.president &&
      membership.status == MembershipStatus.active;

  /// Vazgeçmenin son anı: bu andan önce biten etkinliğin kaydı korunur.
  /// Saat kayması payı Rules'un sunucu saatiyle (`endsAt > request.time`)
  /// verdiği retti önler.
  DateTime _endCutoff() => _clock.nowUtc().add(Limits.clockSkewTolerance);

  /// [kind] koleksiyonunda [uid] kullanıcısının silinmemiş belgeleri
  /// (rules-spec §6 sahiplik süzgeçleri: `userId` / `blockerId`).
  Query<Json> _personalQuery(PersonalDocKind kind, String uid) =>
      switch (kind) {
        PersonalDocKind.notification =>
          _firestore
              .collection(FirestoreCollections.notifications)
              .where(FirestoreFields.userId, isEqualTo: uid),
        PersonalDocKind.savedPost =>
          _firestore
              .collection(FirestoreCollections.savedPosts)
              .where(FirestoreFields.userId, isEqualTo: uid),
        PersonalDocKind.block =>
          _firestore
              .collection(FirestoreCollections.blocks)
              .where(FirestoreFields.blockerId, isEqualTo: uid),
      }.notDeleted();

  DocumentReference<Json> _personalRef(PersonalDocRef ref) => _firestore.doc(
    switch (ref.kind) {
      PersonalDocKind.notification => FirestoreCollections.notifications,
      PersonalDocKind.savedPost => FirestoreCollections.savedPosts,
      PersonalDocKind.block => FirestoreCollections.blocks,
    },
    ref.id,
  );

  /// İşlemde okunan, [userId] kullanıcısının [eventId] kaydı; belge yoksa
  /// `null`. Bileşik kimlik başka bir (etkinlik, kullanıcı) çiftine denk
  /// geliyorsa [FirestoreError.permissionDenied] (kimlik birleşimi
  /// belirsizliği: sahiplik alanlardan okunur — T-22 §6.1).
  static RsvpModel? _ownRsvp(
    DocumentSnapshot<Json> snapshot,
    String eventId,
    String userId,
  ) {
    final doc = FirestoreDoc.fromSnapshot(snapshot);
    if (doc == null) return null;
    final rsvp = _parsed(doc, _rsvpOf);
    if (rsvp.eventId != eventId || rsvp.userId != userId) {
      throw _Halt(
        FirestoreError.permissionDenied,
        '${doc.path}: başka bir kaydın kimliği',
      );
    }
    return rsvp;
  }

  /// İşlemde okunan etkinlik; yoksa ya da silinmişse `null`.
  static EventModel? _liveEventOrNull(DocumentSnapshot<Json> snapshot) {
    final doc = FirestoreDoc.fromSnapshot(snapshot);
    if (doc == null || RepositoryHelpers.isSoftDeleted(doc)) return null;
    return _parsed(doc, _eventOf);
  }

  static T _parsed<T>(FirestoreDoc doc, T Function(FirestoreDoc doc) fromDoc) =>
      switch (RepositoryHelpers.parse(doc, fromDoc)) {
        FirebaseSuccess(:final data) => data,
        FirebaseFailure(:final error, :final message) => throw _Halt(
          error,
          message,
        ),
      };

  /// Etkinliğin sayaç yazımı: [status] durumunun sayacı (`going` →
  /// `goingCount`, `waitlist` → `waitlistCount`) `−1`. Kaydın yolu etkinlik
  /// belgesine yazılmaz (W-64).
  static Json _counterPayload(RsvpStatus status) => {
    (status == RsvpStatus.waitlist
        ? FirestoreFields.waitlistCount
        : FirestoreFields.goingCount): FieldValue.increment(
      _left,
    ),
    ...BaseFieldsPayload.update(),
  };

  static UserModel _userOf(FirestoreDoc doc) =>
      UserModel.fromJson(doc.data, id: doc.id);

  static RsvpModel _rsvpOf(FirestoreDoc doc) =>
      RsvpModel.fromJson(doc.data, id: doc.id);

  static EventModel _eventOf(FirestoreDoc doc) =>
      EventModel.fromJson(doc.data, id: doc.id);

  DocumentReference<Json> _userRef(String uid) =>
      _firestore.doc(FirestoreCollections.users, uid);

  DocumentReference<Json> _accountRef(String uid) => _firestore.doc(
    RepositoryHelpers.subcollectionPath(
      FirestoreCollections.users,
      uid,
      FirestoreCollections.privateSub,
    ),
    FirestoreCollections.accountDoc,
  );

  DocumentReference<Json> _eventRef(String eventId) =>
      _firestore.doc(FirestoreCollections.events, eventId);

  DocumentReference<Json> _rsvpRef(String eventId, String userId) =>
      _firestore.doc(
        FirestoreCollections.rsvps,
        FirestoreIds.rsvp(eventId, userId),
      );
}

/// Transaction gövdesinin, yazım kuyruğa girmeden işlemi durdurduğu hata
/// (ayrıştırılamadı, kimlik birleşimi).
final class _Halt implements Exception {
  const _Halt(this.error, this.message);

  final FirestoreError error;
  final String? message;
}
