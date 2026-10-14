// `EventRepository` fake'i (PLAN §16.3): etkinlikleri bellekte tutar.
//
//   final events = FakeEventRepository(clock)..put(EventModelFixtures.e01);
//   await events.publish('e22', actorId: 'u_burak');
//   expect(events.membersUpcomingQueries, ['c01']);
//
// Gerçek repository + Security Rules'un birlikte verdiği sonuçları izler
// (docs/plans/T-22.md §6):
// - alan doğrulaması gerçek `FieldValidators` ile yapılır (`invalidArgument`);
// - durum makinesi: `draft → published` (başlangıç gelecekte, değilse
//   `ruleViolation(eventEnded)`), `published → draft` yalnızca `goingCount ==
//   0` iken (K-F, değilse `ruleViolation(eventHasRegistrations)`),
//   `published → cancelled`; aykırı geçiş `failedPrecondition`. Kontenjan
//   kayıtlı sayısının altına inemez (`ruleViolation(capacityFull)`); yayındaki
//   etkinliğin zamanı yalnızca başlamadan ve yeni başlangıç gelecekteyken
//   değişir (`ruleViolation(eventEnded)`); yalnızca taslak soft delete edilir
//   (D-10);
// - **olmayan** etkinliğin okuması ve işlemli yazımı `permissionDenied`'dır
//   (üretimde kural böyle döner — ekran `notFound` ile aynı sayar); silinmiş
//   etkinlik `notFound`. Rules'un reddettiği **kör** yazımlar
//   (`setRegistrationOpen` iptal / silinmiş etkinlikte, silinmemiş etkinliği
//   geri yükleme) `permissionDenied`;
// - sayaçlara yalnızca katılım fake'i dokunur ([bumpCounters]); yayın / iptal
//   günlüğü ve bildirim yazılmaz (gerçekte günlük asıl yazımla aynı işlemde);
// - kapak yükleme (`uploadCover`) gerçek sırayı izler: ön denetim (kimlik →
//   `MediaDocumentError(invalidArgument)`; tür / boş / sınır →
//   `MediaUploadError`) → "yükleme" ([coverUploads]) → `coverPath`.
//   `failNext(StorageError.x)` yüklemeyi keser; `failNext(FirestoreError.x)`
//   dosyayı yükler ama `coverPath` yazılmaz (`MediaDocumentError(x)` — dosya
//   yetim kalır).
// Çağıranın rolü (yönetici, üye, ziyaretçi) burada bilinmez: yetki reddini
// test `failNext(FirestoreError.permissionDenied)` ile kurar; liste
// sorgularının görünürlük süzgeci sorgunun kendisidir (Rules süzgeç değildir).
import 'dart:typed_data';

import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';
import 'fake_pager.dart';

/// `uploadCover` ile "yüklenen" tek kapak: hedef etkinlik, üst verideki kulüp
/// ve yükleyen (`customMetadata.clubId` / `.uploaderId`), içerik türü ve yol.
typedef FakeCoverUpload = ({
  String eventId,
  String clubId,
  String uploaderId,
  String contentType,
  String path,
});

/// `update` çağrısı: hedef etkinlik ve yama (yazılmışsa).
typedef FakeEventPatch = ({String eventId, EventEditPatch patch});

final class FakeEventRepository extends FakeBase implements EventRepository {
  /// "Şu an" [_clock] saatidir (yayın koşulu, zaman alanları).
  FakeEventRepository(this._clock);

  final AppClock _clock;

  /// `events/{eventId}` belgeleri (silinmişler dahil). Test ön veriyi [put]
  /// ile yazar.
  final Map<String, EventModel> events = <String, EventModel>{};

  /// `listMembersUpcoming` ile sorgulanan kulüpler, çağrı sırasıyla (EVT-01
  /// üye olunan her kulüp için ayrı sorgu).
  final List<String> membersUpcomingQueries = <String>[];

  /// `create` / `createDraft` / `duplicate` ile yazılan etkinlikler, sırayla.
  final List<EventModel> created = <EventModel>[];

  /// `update` ile **yazılan** yamalar, sırayla.
  final List<FakeEventPatch> patches = <FakeEventPatch>[];

  /// `uploadCover` ile yüklenen kapaklar (`coverPath` yazılamayanlar dahil).
  final List<FakeCoverUpload> coverUploads = <FakeCoverUpload>[];

  /// Yeni etkinlik kimliği buradan alınır; boşsa `e_fake_N` üretilir.
  final List<String> newEventIdQueue = <String>[];

  final FakePager _pager = FakePager();
  int _generated = 0;
  int _coverSerial = 0;

  /// [event] belgesini yazar (varsa üzerine).
  void put(EventModel event) => events[event.id] = event;

  /// Katılım fake'inin sayaç yazımı (kayıtla aynı işlemde): üç sayaç
  /// verilen deltalar kadar oynar, `updatedAt` yenilenir. Etkinlik yoksa
  /// hiçbir şey yapmaz.
  void bumpCounters(
    String eventId, {
    int going = 0,
    int waitlist = 0,
    int attended = 0,
  }) {
    final event = events[eventId];
    if (event == null) return;
    events[eventId] = event.copyWith(
      goingCount: event.goingCount + going,
      waitlistCount: event.waitlistCount + waitlist,
      attendedCount: event.attendedCount + attended,
      updatedAt: _clock.nowUtc(),
    );
  }

  @override
  Future<FirestoreResult<EventModel>> createDraft(
    EventDraft draft, {
    required String clubId,
    required String createdBy,
  }) async {
    record('createDraft', [draft, clubId, createdBy]);
    return _create(draft, clubId, createdBy, EventStatus.draft);
  }

  @override
  Future<FirestoreResult<EventModel>> create(
    EventDraft draft, {
    required String clubId,
    required String createdBy,
    required EventStatus status,
  }) async {
    record('create', [draft, clubId, createdBy, status]);
    return _create(draft, clubId, createdBy, status);
  }

  @override
  Future<FirestoreResult<void>> update(
    String eventId,
    EventEditPatch patch,
  ) async {
    record('update', [eventId, patch]);
    if (_rejected<void>([eventId]) case final failure?) return failure;
    if (!_patchOk(patch, eventId)) return _invalid();
    final event = events[eventId];
    if (_unreadable<void>(event) case final failure?) return failure;
    if (event!.status == EventStatus.cancelled) return _precondition();
    final startsAt = patch.startsAt ?? event.startsAt;
    final endsAt = patch.endsAt ?? event.endsAt;
    if (FieldValidators.eventEnd(endsAt, startsAt: startsAt) != null) {
      return _invalid();
    }
    // Yayındaki etkinliğin zamanı yalnızca başlamadan ve yeni başlangıç
    // gelecekteyken değişir (domain-model §2.7).
    final reschedules =
        !startsAt.isAtSameMomentAs(event.startsAt) ||
        !endsAt.isAtSameMomentAs(event.endsAt);
    if (event.status == EventStatus.published &&
        reschedules &&
        (FieldValidators.eventStart(event.startsAt, _clock) != null ||
            FieldValidators.eventStart(startsAt, _clock) != null)) {
      return _violation(FirestoreRuleCode.eventEnded);
    }
    final capacity = patch.capacity;
    if (capacity != null && capacity < event.goingCount) {
      return _violation(FirestoreRuleCode.capacityFull);
    }
    events[eventId] = event.copyWith(
      title: patch.title,
      desc: patch.desc,
      type: patch.type,
      startsAt: patch.startsAt,
      endsAt: patch.endsAt,
      placeId: patch.placeId,
      placeText: patch.placeText,
      capacity: patch.capacity,
      visibility: patch.visibility,
      registrationOpen: patch.registrationOpen,
      autoReminder: patch.autoReminder,
      coverPalette: patch.coverPalette,
      coverPattern: patch.coverPattern,
      coverPath: patch.coverPath,
      clearPlaceId: patch.clearPlaceId,
      clearPlaceText: patch.clearPlaceText,
      clearCapacity: patch.clearCapacity,
      clearCoverPath: patch.clearCoverPath,
      updatedAt: _clock.nowUtc(),
    );
    patches.add((eventId: eventId, patch: patch));
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> publish(
    String eventId, {
    required String actorId,
  }) async {
    record('publish', [eventId, actorId]);
    if (_rejected<void>([eventId, actorId]) case final failure?) {
      return failure;
    }
    final event = events[eventId];
    if (_unreadable<void>(event) case final failure?) return failure;
    if (event!.status != EventStatus.draft) return _precondition();
    if (FieldValidators.eventStart(event.startsAt, _clock) != null) {
      return _violation(FirestoreRuleCode.eventEnded);
    }
    final now = _clock.nowUtc();
    events[eventId] = event.copyWith(
      status: EventStatus.published,
      publishedAt: now,
      updatedAt: now,
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> unpublish(String eventId) async {
    record('unpublish', [eventId]);
    if (_rejected<void>([eventId]) case final failure?) return failure;
    final event = events[eventId];
    if (_unreadable<void>(event) case final failure?) return failure;
    if (event!.status != EventStatus.published) return _precondition();
    // K-F: kayıtlı varken taslağa alınamaz (bekleme listesi engel değil);
    // `publishedAt` korunur.
    if (!event.canUnpublish) {
      return _violation(FirestoreRuleCode.eventHasRegistrations);
    }
    events[eventId] = event.copyWith(
      status: EventStatus.draft,
      updatedAt: _clock.nowUtc(),
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> cancel(
    String eventId, {
    required String reason,
    required String actorId,
  }) async {
    record('cancel', [eventId, reason, actorId]);
    if (_rejected<void>([eventId, actorId]) case final failure?) {
      return failure;
    }
    final trimmed = reason.trim();
    if (FieldValidators.adminReason(trimmed) != null) return _invalid();
    final event = events[eventId];
    if (_unreadable<void>(event) case final failure?) return failure;
    if (event!.status != EventStatus.published) return _precondition();
    // Katılım kayıtları ve sayaçlar değişmez.
    events[eventId] = event.copyWith(
      status: EventStatus.cancelled,
      cancelReason: trimmed,
      updatedAt: _clock.nowUtc(),
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<EventModel>> duplicate(
    String eventId, {
    required String createdBy,
    required String copyTitleSuffix,
  }) async {
    record('duplicate', [eventId, createdBy, copyTitleSuffix]);
    if (_rejected<EventModel>([eventId, createdBy]) case final failure?) {
      return failure;
    }
    final source = events[eventId];
    if (_unreadable<EventModel>(source) case final failure?) return failure;
    // Özel kapak, durum, sayaçlar ve iptal nedeni kopyalanmaz.
    return _create(
      EventDraft(
        title: _copyTitle(source!.title, copyTitleSuffix),
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
      source.clubId,
      createdBy,
      EventStatus.draft,
    );
  }

  @override
  Future<FirestoreResult<void>> setRegistrationOpen(
    String eventId,
    bool open,
  ) async {
    record('setRegistrationOpen', [eventId, open]);
    if (_rejected<void>([eventId]) case final failure?) return failure;
    final event = events[eventId];
    // Kör yazım: iptal / silinmiş / olmayan etkinlikte kural reddeder.
    if (event == null ||
        event.isDeleted ||
        event.status == EventStatus.cancelled) {
      return _denied();
    }
    events[eventId] = event.copyWith(
      registrationOpen: open,
      updatedAt: _clock.nowUtc(),
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> softDeleteEvent(
    String eventId, {
    required String actorId,
  }) async {
    record('softDeleteEvent', [eventId, actorId]);
    if (_rejected<void>([eventId, actorId]) case final failure?) {
      return failure;
    }
    final event = events[eventId];
    if (_unreadable<void>(event) case final failure?) return failure;
    // Yalnızca taslak kaldırılır (DLG-31); yayındaki etkinlik iptal edilir.
    if (event!.status != EventStatus.draft) return _precondition();
    final now = _clock.nowUtc();
    events[eventId] = event.copyWith(
      isDeleted: true,
      deletedAt: now,
      deletedBy: actorId,
      updatedAt: now,
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> restoreEvent(String eventId) async {
    record('restoreEvent', [eventId]);
    if (_rejected<void>([eventId]) case final failure?) return failure;
    final event = events[eventId];
    if (event == null ||
        !event.isDeleted ||
        event.status != EventStatus.draft) {
      return _denied();
    }
    events[eventId] = event.copyWith(
      isDeleted: false,
      clearDeletedAt: true,
      clearDeletedBy: true,
      updatedAt: _clock.nowUtc(),
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<MediaUpdateResult<String>> uploadCover(
    String eventId,
    Uint8List bytes, {
    required String contentType,
    required String clubId,
    required String uploaderId,
  }) async {
    record('uploadCover', [eventId, bytes.length, contentType, clubId]);
    final injected = takeFailure();
    // Ön denetim dosya "gönderilmeden" (gerçek repository ile aynı sıra).
    if (![eventId, clubId, uploaderId].every(RepositoryHelpers.isValidId)) {
      return const FirebaseFailure(
        MediaDocumentError(FirestoreError.invalidArgument),
      );
    }
    final extension = StoragePaths.extensionByContentType[contentType];
    if (extension == null) return _uploadFailure(StorageError.invalidType);
    if (bytes.isEmpty) return _uploadFailure(StorageError.noFile);
    if (bytes.length >= Limits.imageMaxBytes) {
      return _uploadFailure(StorageError.sizeLimit);
    }
    if (injected is StorageError) return _uploadFailure(injected);
    final path = StoragePaths.eventCover(eventId, _nextFileName(extension));
    coverUploads.add((
      eventId: eventId,
      clubId: clubId,
      uploaderId: uploaderId,
      contentType: contentType,
      path: path,
    ));
    // Dosya yüklendi; `coverPath` yazımı (içerik dalı) düşerse dosya yetim
    // kalır (D-10).
    if (injected != null) {
      return FirebaseFailure(
        MediaDocumentError(
          injected is FirestoreError ? injected : FirestoreError.unknown,
        ),
      );
    }
    final event = events[eventId];
    if (event == null ||
        event.isDeleted ||
        event.status == EventStatus.cancelled) {
      return const FirebaseFailure(
        MediaDocumentError(FirestoreError.permissionDenied),
      );
    }
    events[eventId] = event.copyWith(
      coverPath: path,
      updatedAt: _clock.nowUtc(),
    );
    return FirebaseSuccess(path);
  }

  @override
  Future<FirestoreResult<EventModel>> getEvent(String eventId) async {
    record('getEvent', [eventId]);
    if (_rejected<EventModel>([eventId]) case final failure?) return failure;
    final event = events[eventId];
    if (_unreadable<EventModel>(event) case final failure?) return failure;
    return FirebaseSuccess(event!);
  }

  @override
  Future<FirestoreResult<List<EventModel>>> listPublicUpcoming({
    required DateTime fromUtc,
  }) async {
    record('listPublicUpcoming', [fromUtc]);
    if (_rejected<List<EventModel>>(const []) case final failure?) {
      return failure;
    }
    return FirebaseSuccess(
      _upcoming(
        (event) => event.visibility == EventVisibility.public,
        fromUtc,
      ),
    );
  }

  @override
  Future<FirestoreResult<List<EventModel>>> listMembersUpcoming(
    String clubId, {
    required DateTime fromUtc,
  }) async {
    record('listMembersUpcoming', [clubId, fromUtc]);
    if (_rejected<List<EventModel>>([clubId]) case final failure?) {
      return failure;
    }
    membersUpcomingQueries.add(clubId);
    return FirebaseSuccess(
      _upcoming(
        (event) =>
            event.clubId == clubId &&
            event.visibility == EventVisibility.membersOnly,
        fromUtc,
      ),
    );
  }

  @override
  Future<FirestoreResult<PageResult<EventModel>>> listClubEvents(
    String clubId,
    PageRequest page, {
    bool includeDrafts = false,
    bool publicOnly = false,
  }) async {
    record('listClubEvents', [clubId, page, includeDrafts, publicOnly]);
    if (_rejected<PageResult<EventModel>>([clubId]) case final failure?) {
      return failure;
    }
    if (includeDrafts && publicOnly) return _invalid();
    final listed = [
      for (final event in events.values)
        if (event.clubId == clubId &&
            !event.isDeleted &&
            (includeDrafts || _listed(event)) &&
            (!publicOnly || event.visibility == EventVisibility.public))
          event,
    ]..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return FirebaseSuccess(_pager.slice(listed, page));
  }

  @override
  Future<FirestoreResult<List<EventModel>>> getEvents(
    List<String> eventIds,
  ) async {
    record('getEvents', [eventIds]);
    if (_rejected<List<EventModel>>(eventIds) case final failure?) {
      return failure;
    }
    // Girdi sırası, tekilleştirilmiş; olmayan ve silinmiş etkinlik atlanır.
    return FirebaseSuccess([
      for (final eventId in eventIds.toSet())
        if (events[eventId] case final event? when !event.isDeleted) event,
    ]);
  }

  FirestoreResult<EventModel> _create(
    EventDraft draft,
    String clubId,
    String createdBy,
    EventStatus status,
  ) {
    if (_rejected<EventModel>([clubId, createdBy]) case final failure?) {
      return failure;
    }
    if (status == EventStatus.cancelled || !_draftOk(draft)) return _invalid();
    final published = status == EventStatus.published;
    if (published &&
        FieldValidators.eventStart(draft.startsAt, _clock) != null) {
      return _violation(FirestoreRuleCode.eventEnded);
    }
    final now = _clock.nowUtc();
    final id = newEventIdQueue.isEmpty
        ? 'e_fake_${++_generated}'
        : newEventIdQueue.removeAt(0);
    final event = EventModel(
      id: id,
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
      coverPalette: draft.coverPalette,
      coverPattern: draft.coverPattern,
      registrationOpen: draft.registrationOpen,
      autoReminder: draft.autoReminder,
      publishedAt: published ? now : null,
      createdAt: now,
      updatedAt: now,
    );
    events[id] = event;
    created.add(event);
    return FirebaseSuccess(event);
  }

  /// Yaklaşan liste: süzgeç + yayında / iptal, silinmemiş, [fromUtc] anında
  /// ya da sonrasında başlayan; en yakın üstte, en çok
  /// `Limits.upcomingEventsFetchMax`.
  List<EventModel> _upcoming(
    bool Function(EventModel event) where,
    DateTime fromUtc,
  ) {
    final upcoming = [
      for (final event in events.values)
        if (where(event) &&
            _listed(event) &&
            !event.isDeleted &&
            !event.startsAt.isBefore(fromUtc))
          event,
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return upcoming.take(Limits.upcomingEventsFetchMax).toList();
  }

  /// Liste sorgularının durum süzgeci (taslak yalnızca yönetime görünür).
  static bool _listed(EventModel event) =>
      event.status == EventStatus.published ||
      event.status == EventStatus.cancelled;

  /// Taslağın alan kuralları (gerçek repository ile aynı doğrulayıcılar).
  static bool _draftOk(EventDraft draft) {
    final placeId = draft.placeId;
    final placeText = draft.placeText;
    return FieldValidators.eventTitle(draft.title) == null &&
        FieldValidators.eventDesc(draft.desc) == null &&
        (placeId == null || FieldValidators.placeId(placeId) == null) &&
        (placeText == null || FieldValidators.placeText(placeText) == null) &&
        FieldValidators.capacity(draft.capacity) == null &&
        FieldValidators.eventEnd(draft.endsAt, startsAt: draft.startsAt) ==
            null;
  }

  /// Yamanın belge okunmadan denetlenen kuralları (boş yama, değer +
  /// `clear…`, alan sınırları, kapağın etkinliğin kendi klasöründe olması).
  static bool _patchOk(EventEditPatch patch, String eventId) {
    final title = patch.title;
    final desc = patch.desc;
    final placeId = patch.placeId;
    final placeText = patch.placeText;
    final capacity = patch.capacity;
    final coverPath = patch.coverPath;
    return !patch.isEmpty &&
        !(placeId != null && patch.clearPlaceId) &&
        !(placeText != null && patch.clearPlaceText) &&
        !(capacity != null && patch.clearCapacity) &&
        !(coverPath != null && patch.clearCoverPath) &&
        (coverPath == null || StoragePaths.isEventCover(coverPath, eventId)) &&
        (title == null || FieldValidators.eventTitle(title) == null) &&
        (desc == null || FieldValidators.eventDesc(desc) == null) &&
        (placeId == null || FieldValidators.placeId(placeId) == null) &&
        (placeText == null || FieldValidators.placeText(placeText) == null) &&
        (capacity == null || FieldValidators.capacity(capacity) == null);
  }

  /// Kopyanın başlığı: kaynak + ek, toplam `Limits.eventTitleMax` sınırına
  /// sığacak şekilde kaynak sondan kısaltılır.
  static String _copyTitle(String title, String suffix) {
    final room = Limits.eventTitleMax - suffix.length;
    if (title.length <= room) return '$title$suffix';
    if (room <= 0) return suffix;
    return '${title.substring(0, room).trimRight()}$suffix';
  }

  /// `StoragePaths.newFileName` şemasında, her çağrıda farklı dosya adı.
  String _nextFileName(String extension) {
    final serial = (++_coverSerial).toRadixString(16).padLeft(16, '0');
    return '20261014T090000Z_$serial.$extension';
  }

  /// Okunan etkinliğin ortak ön koşulu: olmayan etkinlik okunamaz
  /// (`permissionDenied`), silinmiş etkinlik `notFound`.
  static FirestoreResult<T>? _unreadable<T>(EventModel? event) {
    if (event == null) return _denied();
    if (event.isDeleted) return const FirebaseFailure(FirestoreError.notFound);
    return null;
  }

  static MediaUpdateResult<String> _uploadFailure(StorageError error) =>
      FirebaseFailure(MediaUploadError(error));

  static FirestoreResult<T> _violation<T>(FirestoreRuleCode code) =>
      FirebaseFailure(
        FirestoreError.ruleViolation,
        detail: FirestoreFailureDetail(code),
      );

  static FirestoreResult<T> _precondition<T>() =>
      const FirebaseFailure(FirestoreError.failedPrecondition);

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
