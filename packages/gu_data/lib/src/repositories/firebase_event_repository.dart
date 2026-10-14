import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/constants/storage_paths.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/conflict_exception.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/firestore_failure_detail.dart';
import 'package:gu_data/src/core/media_update_error.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/core/soft_delete.dart';
import 'package:gu_data/src/core/storage_error.dart';
import 'package:gu_data/src/models/activity_draft.dart';
import 'package:gu_data/src/models/activity_refs_model.dart';
import 'package:gu_data/src/models/enums/activity_kind.dart';
import 'package:gu_data/src/models/enums/event_status.dart';
import 'package:gu_data/src/models/enums/event_visibility.dart';
import 'package:gu_data/src/models/event_draft.dart';
import 'package:gu_data/src/models/event_model.dart';
import 'package:gu_data/src/repositories/event_repository.dart';
import 'package:gu_data/src/repositories/firebase_activity_repository.dart';
import 'package:gu_data/src/repositories/query_x.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/services/storage_service.dart';
import 'package:gu_data/src/utils/field_validators.dart';

/// [EventRepository] uygulaması: `events/{eventId}`, yayın / iptal günlük
/// kaydı ve özel kapak görseli (PLAN §10.4; rules-spec §3.7, §3.11;
/// `docs/plans/T-22.md §6`).
///
/// Yazma mekaniği:
/// - **oluşturma** — etkinlik (+ yayındaysa günlük) tek batch;
/// - **durum geçişleri** (`publish`, `unpublish`, `cancel`), **içerik
///   düzenleme** ve **taslağı kaldırma** — etkinlik okunur, geçiş denetlenir,
///   tek transaction'da yazılır (günlük aynı işlemde);
/// - **kayıt aç / kapa**, **geri yükleme** ve kapağın yol alanı — tek ve
///   **kör** yazım (önce okuma yok; durumu ve yetkiyi Security Rules denetler).
///
/// Sayaçlara (`goingCount`, `waitlistCount`, `attendedCount`) hiçbir yol
/// dokunmaz; onları yalnızca katılım kaydı yazar (`RsvpRepository`). Bildirim
/// dağıtımı burada yapılmaz (PLAN §10.5: çağıran yapar).
final class FirebaseEventRepository implements EventRepository {
  /// [_firestore] üzerinden okur ve yazar; kapak görselini [_storage] ile
  /// yükler; günlük kaydını [_activity] ile yayın / iptal işlemine ekler.
  /// Yayın koşulu (`startsAt > şimdi`) ve kapak dosya adının damgası [_clock]
  /// saatinden; dosya adının rastgele kısmı [_random] kaynağından gelir
  /// (kompozisyon kökü `Random.secure()` verir; `gu_data` rastgele kaynağı
  /// kendisi kurmaz).
  FirebaseEventRepository(
    this._firestore,
    this._storage,
    this._activity,
    this._clock,
    this._random,
  );

  final FirestoreService _firestore;
  final StorageService _storage;
  final FirebaseActivityRepository _activity;
  final AppClock _clock;
  final Random _random;

  /// Kapak görselinin özel üst veri anahtarı: Storage Rules yükleyenin
  /// yöneticiliğini `request.resource.metadata.clubId` kulübünde doğrular
  /// (CD-47). [_uploaderIdMetadata] dışında özel üst veri gönderilmez (Rules
  /// reddeder).
  static const String _clubIdMetadata = 'clubId';

  /// Yükleyenin kimliği: Storage Rules değerin oturumdaki uid olmasını ister
  /// (dosyayı kimin yüklediği yalnızca bu alandan izlenir).
  static const String _uploaderIdMetadata = 'uploaderId';

  /// Liste sorgularının durum süzgeci: yayında ve iptal edilmiş etkinlikler
  /// (taslak yalnızca yönetime görünür — rules-spec §3.7 R).
  static final List<String> _listedStatuses = List.unmodifiable([
    EventStatus.published.json,
    EventStatus.cancelled.json,
  ]);

  /// [doc] belgesinden etkinlik modeli.
  static EventModel eventOf(FirestoreDoc doc) =>
      EventModel.fromJson(doc.data, id: doc.id);

  @override
  Future<FirestoreResult<EventModel>> createDraft(
    EventDraft draft, {
    required String clubId,
    required String createdBy,
  }) => create(
    draft,
    clubId: clubId,
    createdBy: createdBy,
    status: EventStatus.draft,
  );

  @override
  Future<FirestoreResult<EventModel>> create(
    EventDraft draft, {
    required String clubId,
    required String createdBy,
    required EventStatus status,
  }) async {
    final published = status == EventStatus.published;
    final rejected =
        RepositoryHelpers.rejectInvalidIds<EventModel>({
          'clubId': clubId,
          'createdBy': createdBy,
        }) ??
        (status == EventStatus.cancelled
            ? RepositoryHelpers.invalidArgument<EventModel>(
                'create: etkinlik iptal edilmiş olarak oluşturulamaz',
              )
            : null) ??
        _rejectDraft(draft);
    if (rejected != null) return rejected;
    // Yayın koşulu (rules-spec §3.7 C): başlangıç gelecekte olmalı.
    if (published &&
        FieldValidators.eventStart(draft.startsAt, _clock) != null) {
      return _ruleFailure(FirestoreRuleCode.eventEnded);
    }

    final eventId = _firestore.newId(FirestoreCollections.events);
    // Model varsayılanları: üç sayaç sıfır. `null` alanların (`coverPath`,
    // `cancelReason`, boş mekân / kontenjan) anahtarı yazılmaz (W-51).
    final event = EventModel(
      clubId: clubId,
      createdBy: createdBy,
      title: draft.title,
      desc: draft.desc,
      type: draft.type,
      startsAt: draft.startsAt.toUtc(),
      endsAt: draft.endsAt.toUtc(),
      placeId: draft.placeId,
      placeText: draft.placeText,
      capacity: draft.capacity,
      visibility: draft.visibility,
      status: status,
      coverSeed: FirestoreIds.eventCoverSeed(eventId),
      coverPalette: draft.coverPalette,
      coverPattern: draft.coverPattern,
      registrationOpen: draft.registrationOpen,
      autoReminder: draft.autoReminder,
    );
    final written = await _firestore.commitBatch((batch) {
      batch.set(_eventRef(eventId), {
        ...event.toJson(),
        ...BaseFieldsPayload.create(),
        if (published)
          FirestoreFields.publishedAt: _firestore.serverTimestamp(),
      });
      if (published) {
        _activity.addToBatch(
          batch,
          _activityOf(
            ActivityKind.eventPublished,
            clubId: clubId,
            actorId: createdBy,
            eventId: eventId,
          ),
        );
      }
    });
    // Sunucu zamanı yazım anında okunamaz: zaman alanları yaklaşık değerdir.
    final now = _clock.nowUtc();
    return written.map(
      (_) => event.copyWith(
        id: eventId,
        createdAt: now,
        updatedAt: now,
        publishedAt: published ? now : null,
      ),
    );
  }

  @override
  Future<FirestoreResult<void>> update(
    String eventId,
    EventEditPatch patch,
  ) async {
    final rejected =
        RepositoryHelpers.rejectInvalidIds<void>({'eventId': eventId}) ??
        _rejectPatch(patch, eventId);
    if (rejected != null) return rejected;
    final ref = _eventRef(eventId);
    return _transact((tx) async {
      final event = _liveEvent(await tx.get(ref));
      if (event.status == EventStatus.cancelled) {
        throw _Halt(
          FirestoreError.failedPrecondition,
          '${ref.path}: iptal edilmiş etkinlik düzenlenemez',
        );
      }
      // Bitiş, yazım-sonrası başlangıçtan sonra olmalı (yalnızca biri
      // değişse de).
      final endError = FieldValidators.eventEnd(
        patch.endsAt ?? event.endsAt,
        startsAt: patch.startsAt ?? event.startsAt,
      );
      if (endError != null) {
        throw _Halt(
          FirestoreError.invalidArgument,
          'geçersiz alan: ${FirestoreFields.endsAt} (${endError.name})',
        );
      }
      // Yayındaki etkinliğin zamanı yalnızca başlamadan ve yeni başlangıç
      // gelecekteyken değişir (domain-model §2.7; Rules `canEditEvent`):
      // bitmiş etkinliğin bitişi ileri alınıp katılım / yoklama penceresi
      // yeniden açılamaz. Değeri aynı kalan alan değişiklik sayılmaz.
      final reschedules =
          !(patch.startsAt?.isAtSameMomentAs(event.startsAt) ?? true) ||
          !(patch.endsAt?.isAtSameMomentAs(event.endsAt) ?? true);
      if (event.status == EventStatus.published &&
          reschedules &&
          (FieldValidators.eventStart(event.startsAt, _clock) != null ||
              FieldValidators.eventStart(
                    patch.startsAt ?? event.startsAt,
                    _clock,
                  ) !=
                  null)) {
        throw _violation(FirestoreRuleCode.eventEnded);
      }
      // Kontenjan kayıtlı sayısının altına inemez (düzenleme sürerken biri
      // katılmış olabilir).
      final capacity = patch.capacity;
      if (capacity != null && capacity < event.goingCount) {
        throw _violation(FirestoreRuleCode.capacityFull);
      }
      tx.update(ref, {..._patchPayload(patch), ...BaseFieldsPayload.update()});
    });
  }

  @override
  Future<FirestoreResult<void>> publish(
    String eventId, {
    required String actorId,
  }) async {
    if (_rejectActor<void>(eventId, actorId) case final rejected?) {
      return rejected;
    }
    final ref = _eventRef(eventId);
    return _transact((tx) async {
      final event = _liveEvent(await tx.get(ref));
      _requireStatus(event, EventStatus.draft, ref);
      if (FieldValidators.eventStart(event.startsAt, _clock) != null) {
        throw _violation(FirestoreRuleCode.eventEnded);
      }
      tx.update(ref, {
        FirestoreFields.status: EventStatus.published.json,
        FirestoreFields.publishedAt: _firestore.serverTimestamp(),
        ...BaseFieldsPayload.update(),
      });
      // Günlük yalnızca ilk yayında: kimlik sabittir, yayından çekilip
      // yeniden yayınlanan etkinliğin ikinci kaydını Rules reddederdi.
      if (event.publishedAt == null) {
        _activity.addToTransaction(
          tx,
          _activityOf(
            ActivityKind.eventPublished,
            clubId: event.clubId,
            actorId: actorId,
            eventId: eventId,
          ),
        );
      }
    });
  }

  @override
  Future<FirestoreResult<void>> unpublish(String eventId) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({'eventId': eventId})
        case final rejected?) {
      return rejected;
    }
    final ref = _eventRef(eventId);
    return _transact((tx) async {
      final event = _liveEvent(await tx.get(ref));
      _requireStatus(event, EventStatus.published, ref);
      // K-F: kayıtlı varken taslağa alınamaz (bekleme listesi engel değil).
      if (!event.canUnpublish) {
        throw _violation(FirestoreRuleCode.eventHasRegistrations);
      }
      // `publishedAt` korunur (son yayın anı).
      tx.update(ref, {
        FirestoreFields.status: EventStatus.draft.json,
        ...BaseFieldsPayload.update(),
      });
    });
  }

  @override
  Future<FirestoreResult<void>> cancel(
    String eventId, {
    required String reason,
    required String actorId,
  }) async {
    final trimmed = reason.trim();
    final rejected =
        _rejectActor<void>(eventId, actorId) ??
        RepositoryHelpers.rejectInvalidFields<void>({
          FirestoreFields.cancelReason: FieldValidators.adminReason(trimmed),
        });
    if (rejected != null) return rejected;
    final ref = _eventRef(eventId);
    return _transact((tx) async {
      final event = _liveEvent(await tx.get(ref));
      _requireStatus(event, EventStatus.published, ref);
      // Katılım kayıtları ve sayaçlar değişmez (biletler "İptal" görünür).
      tx.update(ref, {
        FirestoreFields.status: EventStatus.cancelled.json,
        FirestoreFields.cancelReason: trimmed,
        ...BaseFieldsPayload.update(),
      });
      _activity.addToTransaction(
        tx,
        _activityOf(
          ActivityKind.eventCancelled,
          clubId: event.clubId,
          actorId: actorId,
          eventId: eventId,
        ),
      );
    });
  }

  @override
  Future<FirestoreResult<EventModel>> duplicate(
    String eventId, {
    required String createdBy,
    required String copyTitleSuffix,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<EventModel>({
          'eventId': eventId,
          'createdBy': createdBy,
        })
        case final rejected?) {
      return rejected;
    }
    switch (await getEvent(eventId)) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(data: final source):
        // Özel kapak kopyalanmaz (yol kaynağın klasörüne bağlıdır); durum,
        // sayaçlar, yayın anı ve iptal nedeni `create` ile sıfırdan kurulur.
        return create(
          EventDraft(
            title: _copyTitle(source.title, copyTitleSuffix),
            desc: source.desc,
            type: source.type,
            startsAt: source.startsAt.add(Limits.eventCopyShift),
            endsAt: source.endsAt.add(Limits.eventCopyShift),
            placeId: source.placeId,
            placeText: source.placeText,
            capacity: source.capacity,
            visibility: source.visibility,
            registrationOpen: source.registrationOpen,
            autoReminder: source.autoReminder,
            coverPalette: source.coverPalette,
            coverPattern: source.coverPattern,
          ),
          clubId: source.clubId,
          createdBy: createdBy,
          status: EventStatus.draft,
        );
    }
  }

  @override
  Future<FirestoreResult<void>> setRegistrationOpen(
    String eventId,
    bool open,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({'eventId': eventId})
        case final rejected?) {
      return rejected;
    }
    // Kör yazım: `updatedAt` servis tarafından eklenir.
    return _firestore.update(_eventRef(eventId), {
      FirestoreFields.registrationOpen: open,
    });
  }

  @override
  Future<FirestoreResult<void>> softDeleteEvent(
    String eventId, {
    required String actorId,
  }) async {
    if (_rejectActor<void>(eventId, actorId) case final rejected?) {
      return rejected;
    }
    final ref = _eventRef(eventId);
    return _transact((tx) async {
      // Yalnızca taslak kaldırılır (DLG-31); yayındaki etkinlik iptal edilir.
      _requireStatus(_liveEvent(await tx.get(ref)), EventStatus.draft, ref);
      tx.update(ref, SoftDelete.payload(actorId: actorId));
    });
  }

  @override
  Future<FirestoreResult<void>> restoreEvent(String eventId) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({'eventId': eventId})
        case final rejected?) {
      return rejected;
    }
    // Kör yazım: yalnızca silme alanları geri alınır.
    return _firestore.restore(_eventRef(eventId));
  }

  @override
  Future<MediaUpdateResult<String>> uploadCover(
    String eventId,
    Uint8List bytes, {
    required String contentType,
    required String clubId,
    required String uploaderId,
  }) async {
    // Ön denetim dosya gönderilmeden: yüklenen dosya silinemez (D-10).
    final invalid = RepositoryHelpers.rejectInvalidIds<void>({
      'eventId': eventId,
      'clubId': clubId,
      'uploaderId': uploaderId,
    });
    if (invalid case FirebaseFailure(:final error, :final message)) {
      return FirebaseFailure(MediaDocumentError(error), message: message);
    }
    final extension = StoragePaths.extensionByContentType[contentType];
    if (extension == null) {
      return const FirebaseFailure(MediaUploadError(StorageError.invalidType));
    }
    if (bytes.isEmpty) {
      return const FirebaseFailure(MediaUploadError(StorageError.noFile));
    }
    // Storage Rules `size < imageMaxBytes` ister: sınırın kendisi de ret.
    if (bytes.length >= Limits.imageMaxBytes) {
      return const FirebaseFailure(MediaUploadError(StorageError.sizeLimit));
    }

    // Her kapak yeni adla yüklenir (üzerine yazma yok).
    final upload = await _storage.upload(
      path: StoragePaths.eventCover(
        eventId,
        StoragePaths.newFileName(_clock, _random, extension),
      ),
      bytes: bytes,
      contentType: contentType,
      customMetadata: {
        _clubIdMetadata: clubId,
        _uploaderIdMetadata: uploaderId,
      },
    );
    switch (upload) {
      case FirebaseFailure(:final error, :final message):
        return FirebaseFailure(MediaUploadError(error), message: message);
      case FirebaseSuccess(data: final path):
        final written = await _firestore.update(_eventRef(eventId), {
          FirestoreFields.coverPath: path,
        });
        return switch (written) {
          FirebaseSuccess() => FirebaseSuccess(path),
          // Dosya yerinde kalır (D-10); `coverPath` eski değerindedir.
          FirebaseFailure(:final error, :final message) => FirebaseFailure(
            MediaDocumentError(error),
            message: message,
          ),
        };
    }
  }

  @override
  Future<FirestoreResult<EventModel>> getEvent(String eventId) async {
    if (RepositoryHelpers.rejectInvalidIds<EventModel>({'eventId': eventId})
        case final rejected?) {
      return rejected;
    }
    final ref = _eventRef(eventId);
    // Silinmiş belge `parseOrNull` içinde "bulunamadı" olur.
    return switch (RepositoryHelpers.parseOrNull(
      await _firestore.getDoc(ref),
      eventOf,
    )) {
      FirebaseSuccess(data: final event?) => FirebaseSuccess(event),
      FirebaseSuccess() => FirebaseFailure(
        FirestoreError.notFound,
        message: '${ref.path}: yok',
      ),
      FirebaseFailure(:final error, :final message, :final detail) =>
        FirebaseFailure(error, message: message, detail: detail),
    };
  }

  @override
  Future<FirestoreResult<List<EventModel>>> listPublicUpcoming({
    required DateTime fromUtc,
  }) async => RepositoryHelpers.parseAll(
    await _firestore.getList(
      _upcoming(
        _firestore
            .collection(FirestoreCollections.events)
            .where(
              FirestoreFields.visibility,
              isEqualTo: EventVisibility.public.json,
            ),
        fromUtc,
      ),
    ),
    eventOf,
  );

  @override
  Future<FirestoreResult<List<EventModel>>> listMembersUpcoming(
    String clubId, {
    required DateTime fromUtc,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<List<EventModel>>({'clubId': clubId})
        case final rejected?) {
      return rejected;
    }
    return RepositoryHelpers.parseAll(
      await _firestore.getList(
        _upcoming(
          _firestore
              .collection(FirestoreCollections.events)
              .where(FirestoreFields.clubId, isEqualTo: clubId)
              .where(
                FirestoreFields.visibility,
                isEqualTo: EventVisibility.membersOnly.json,
              ),
          fromUtc,
        ),
      ),
      eventOf,
    );
  }

  @override
  Future<FirestoreResult<PageResult<EventModel>>> listClubEvents(
    String clubId,
    PageRequest page, {
    bool includeDrafts = false,
    bool publicOnly = false,
  }) async {
    final rejected =
        RepositoryHelpers.rejectInvalidIds<PageResult<EventModel>>({
          'clubId': clubId,
        }) ??
        (includeDrafts && publicOnly
            ? RepositoryHelpers.invalidArgument<PageResult<EventModel>>(
                'listClubEvents: includeDrafts ve publicOnly birlikte '
                'verilemez',
              )
            : null);
    if (rejected != null) return rejected;
    // Rules süzgeç değildir: sorgu çağıranın görebildiği kümeyi kendisi
    // sınırlar (ziyaretçi `visibility`, üye `status` süzgecini taşır).
    var query = _firestore
        .collection(FirestoreCollections.events)
        .where(FirestoreFields.clubId, isEqualTo: clubId);
    if (publicOnly) {
      query = query.where(
        FirestoreFields.visibility,
        isEqualTo: EventVisibility.public.json,
      );
    }
    if (!includeDrafts) {
      query = query.where(FirestoreFields.status, whereIn: _listedStatuses);
    }
    return RepositoryHelpers.parsePage(
      await _firestore.getPage(
        query.notDeleted().orderBy(FirestoreFields.startsAt, descending: true),
        page,
      ),
      eventOf,
    );
  }

  @override
  Future<FirestoreResult<List<EventModel>>> getEvents(
    List<String> eventIds,
  ) async {
    final distinct = eventIds.toSet().toList();
    if (distinct.isEmpty) return const FirebaseSuccess([]);
    for (final eventId in distinct) {
      if (!RepositoryHelpers.isValidId(eventId)) {
        return RepositoryHelpers.invalidArgument('geçersiz kimlik: eventIds');
      }
    }
    final events = <EventModel>[];
    // Tekil okumalar (liste kuralı görünürlüğü belge başına kanıtlayamaz);
    // aynı anda en çok `whereInMax` okuma.
    for (
      var start = 0;
      start < distinct.length;
      start += RepositoryHelpers.whereInMax
    ) {
      final chunk = distinct.skip(start).take(RepositoryHelpers.whereInMax);
      final results = await Future.wait([
        for (final eventId in chunk) _firestore.getDoc(_eventRef(eventId)),
      ]);
      for (final result in results) {
        switch (result) {
          // Göremediği (taslağa çekilmiş, üyelikten çıkılan kulübün üyelere
          // özel etkinliği) ve var olmayan etkinlik sonuçta yer almaz.
          case FirebaseFailure(
            error: FirestoreError.permissionDenied || FirestoreError.notFound,
          ):
          case FirebaseSuccess(data: null):
            continue;
          case FirebaseFailure(:final error, :final message, :final detail):
            return FirebaseFailure(error, message: message, detail: detail);
          case FirebaseSuccess(data: final doc?):
            if (RepositoryHelpers.isSoftDeleted(doc)) continue;
            switch (RepositoryHelpers.parse(doc, eventOf)) {
              case FirebaseSuccess(:final data):
                events.add(data);
              case FirebaseFailure(:final error, :final message):
                return FirebaseFailure(error, message: message);
            }
        }
      }
    }
    return FirebaseSuccess(events);
  }

  /// [body] gövdesini transaction içinde çalıştırır. Gövde, yazım kuyruğa
  /// girmeden **önce** reddedebilir: `ConflictException` (iş kuralı) ya da
  /// [_Halt] (bulunamadı, ön koşul, ayrıştırılamadı, geçersiz girdi).
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

  /// [base] sorgusuna "yaklaşan etkinlik" süzgeçlerini ekler: yayında ya da
  /// iptal, silinmemiş, [fromUtc] anında ya da sonrasında başlayan; en yakın
  /// üstte, en çok `Limits.upcomingEventsFetchMax` belge.
  static Query<Json> _upcoming(Query<Json> base, DateTime fromUtc) => base
      .where(FirestoreFields.status, whereIn: _listedStatuses)
      .notDeleted()
      .where(
        FirestoreFields.startsAt,
        isGreaterThanOrEqualTo: Timestamp.fromDate(fromUtc.toUtc()),
      )
      .orderBy(FirestoreFields.startsAt)
      .limit(Limits.upcomingEventsFetchMax);

  /// [draft] taslağının alan kuralları (rules-spec §3.7 C): başlık, açıklama,
  /// mekân, kontenjan ve bitiş > başlangıç.
  static FirestoreResult<EventModel>? _rejectDraft(EventDraft draft) {
    final placeId = draft.placeId;
    final placeText = draft.placeText;
    return RepositoryHelpers.rejectInvalidFields<EventModel>({
      FirestoreFields.title: FieldValidators.eventTitle(draft.title),
      FirestoreFields.desc: FieldValidators.eventDesc(draft.desc),
      if (placeId != null)
        FirestoreFields.placeId: FieldValidators.placeId(placeId),
      if (placeText != null)
        FirestoreFields.placeText: FieldValidators.placeText(placeText),
      FirestoreFields.capacity: FieldValidators.capacity(draft.capacity),
      FirestoreFields.endsAt: FieldValidators.eventEnd(
        draft.endsAt,
        startsAt: draft.startsAt,
      ),
    });
  }

  /// [patch] yamasının belge okunmadan denetlenebilen kuralları: boş yama,
  /// aynı alan için değer + `clear…`, alan sınırları ve kapak yolunun
  /// [eventId] etkinliğinin kendi klasöründe olması (CD-47). Bitiş ↔
  /// başlangıç ve kontenjan ↔ kayıtlı sayısı belgeye bağlıdır; transaction
  /// içinde denetlenir.
  static FirestoreResult<void>? _rejectPatch(
    EventEditPatch patch,
    String eventId,
  ) {
    if (patch.isEmpty) {
      return RepositoryHelpers.invalidArgument('update: boş yama');
    }
    final title = patch.title;
    final desc = patch.desc;
    final placeId = patch.placeId;
    final placeText = patch.placeText;
    final capacity = patch.capacity;
    final coverPath = patch.coverPath;
    if ((placeId != null && patch.clearPlaceId) ||
        (placeText != null && patch.clearPlaceText) ||
        (capacity != null && patch.clearCapacity) ||
        (coverPath != null && patch.clearCoverPath)) {
      return RepositoryHelpers.invalidArgument(
        'update: aynı alan için hem değer hem clear… verilmiş',
      );
    }
    if (coverPath != null && !StoragePaths.isEventCover(coverPath, eventId)) {
      return RepositoryHelpers.invalidArgument(
        'geçersiz alan: ${FirestoreFields.coverPath} (yol etkinliğin '
        'klasöründe değil)',
      );
    }
    return RepositoryHelpers.rejectInvalidFields<void>({
      if (title != null)
        FirestoreFields.title: FieldValidators.eventTitle(title),
      if (desc != null) FirestoreFields.desc: FieldValidators.eventDesc(desc),
      if (placeId != null)
        FirestoreFields.placeId: FieldValidators.placeId(placeId),
      if (placeText != null)
        FirestoreFields.placeText: FieldValidators.placeText(placeText),
      if (capacity != null)
        FirestoreFields.capacity: FieldValidators.capacity(capacity),
    });
  }

  /// [patch] yamasının Firestore yükü: yalnızca verilen alanlar; boşaltılan
  /// alan açık `null` yazılır (anahtar kaldırılmaz — Rules bunu bekler).
  static Json _patchPayload(EventEditPatch patch) {
    final startsAt = patch.startsAt;
    final endsAt = patch.endsAt;
    return {
      FirestoreFields.title: ?patch.title,
      FirestoreFields.desc: ?patch.desc,
      FirestoreFields.type: ?patch.type?.json,
      if (startsAt != null)
        FirestoreFields.startsAt: Timestamp.fromDate(startsAt.toUtc()),
      if (endsAt != null)
        FirestoreFields.endsAt: Timestamp.fromDate(endsAt.toUtc()),
      if (patch.clearPlaceId)
        FirestoreFields.placeId: null
      else
        FirestoreFields.placeId: ?patch.placeId,
      if (patch.clearPlaceText)
        FirestoreFields.placeText: null
      else
        FirestoreFields.placeText: ?patch.placeText,
      if (patch.clearCapacity)
        FirestoreFields.capacity: null
      else
        FirestoreFields.capacity: ?patch.capacity,
      FirestoreFields.visibility: ?patch.visibility?.json,
      FirestoreFields.registrationOpen: ?patch.registrationOpen,
      FirestoreFields.autoReminder: ?patch.autoReminder,
      FirestoreFields.coverPalette: ?patch.coverPalette?.json,
      FirestoreFields.coverPattern: ?patch.coverPattern?.json,
      if (patch.clearCoverPath)
        FirestoreFields.coverPath: null
      else
        FirestoreFields.coverPath: ?patch.coverPath,
    };
  }

  /// Kopyanın başlığı: [title] + [suffix]. Toplam `Limits.eventTitleMax`
  /// sınırını aşıyorsa [title] sondan kısaltılır (vekil çift bölünmez, sondaki
  /// boşluk atılır); ek tek başına sınırı aşıyorsa sonuç da aşar ve `create`
  /// reddeder.
  static String _copyTitle(String title, String suffix) {
    final room = Limits.eventTitleMax - suffix.length;
    if (title.length <= room) return '$title$suffix';
    if (room <= 0) return suffix;
    final cut = _isHighSurrogate(title.codeUnitAt(room - 1)) ? room - 1 : room;
    return '${title.substring(0, cut).trimRight()}$suffix';
  }

  static bool _isHighSurrogate(int codeUnit) =>
      codeUnit >= _highSurrogateStart && codeUnit <= _highSurrogateEnd;

  /// Yayının ya da iptalin günlük kaydı. Kimlik sabittir
  /// (`FirestoreIds.eventActivity`): bir yöneticinin bir etkinlik için aynı
  /// türde tek kaydı olur (CD-137).
  static ActivityDraft _activityOf(
    ActivityKind kind, {
    required String clubId,
    required String actorId,
    required String eventId,
  }) => ActivityDraft(
    clubId: clubId,
    actorId: actorId,
    kind: kind,
    refs: ActivityRefsModel(eventId: eventId),
    id: FirestoreIds.eventActivity(clubId, actorId, kind.json, eventId),
  );

  /// Okunan etkinlik: belge yoksa ya da silinmişse [FirestoreError.notFound],
  /// ayrıştırılamıyorsa [FirestoreError.parse] ile işlemi durdurur.
  static EventModel _liveEvent(DocumentSnapshot<Json> snapshot) {
    final doc = FirestoreDoc.fromSnapshot(snapshot);
    if (doc == null || RepositoryHelpers.isSoftDeleted(doc)) {
      throw _Halt(FirestoreError.notFound, '${snapshot.reference.path}: yok');
    }
    return switch (RepositoryHelpers.parse(doc, eventOf)) {
      FirebaseSuccess(:final data) => data,
      FirebaseFailure(:final error, :final message) => throw _Halt(
        error,
        message,
      ),
    };
  }

  /// [event] [expected] durumunda değilse işlemi
  /// [FirestoreError.failedPrecondition] ile durdurur (durum makinesine
  /// aykırı geçiş — `docs/plans/T-22.md §6.6`).
  static void _requireStatus(
    EventModel event,
    EventStatus expected,
    DocumentReference<Json> ref,
  ) {
    if (event.status != expected) {
      throw _Halt(
        FirestoreError.failedPrecondition,
        '${ref.path}: durum ${event.status.json}, beklenen ${expected.json}',
      );
    }
  }

  /// [code] iş kuralının transaction içindeki reddi; kod başarısızlığın
  /// `detail` alanında taşınır.
  static ConflictException _violation(FirestoreRuleCode code) =>
      ConflictException(code, detail: FirestoreFailureDetail(code));

  /// [code] iş kuralının transaction dışındaki reddi ([_violation] ile aynı
  /// biçim: [FirestoreError.ruleViolation] + `detail`).
  static FirestoreResult<T> _ruleFailure<T>(FirestoreRuleCode code) =>
      FirebaseFailure(
        FirestoreError.ruleViolation,
        message: _violation(code).toString(),
        detail: FirestoreFailureDetail(code),
      );

  static FirestoreResult<T>? _rejectActor<T>(String eventId, String actorId) =>
      RepositoryHelpers.rejectInvalidIds<T>({
        'eventId': eventId,
        'actorId': actorId,
      });

  DocumentReference<Json> _eventRef(String eventId) =>
      _firestore.doc(FirestoreCollections.events, eventId);

  static const int _highSurrogateStart = 0xD800;
  static const int _highSurrogateEnd = 0xDBFF;
}

/// Transaction gövdesinin, yazım kuyruğa girmeden işlemi durdurduğu hata
/// (bulunamadı, ön koşul tutmadı, ayrıştırılamadı, geçersiz girdi). İş kuralı
/// reddi bunun yerine `ConflictException` ile bildirilir.
final class _Halt implements Exception {
  const _Halt(this.error, this.message);

  final FirestoreError error;
  final String? message;
}
