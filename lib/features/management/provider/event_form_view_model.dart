import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/event_form_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_events_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_view_model.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/format/time_of_day_value.dart';
import 'package:gu_kulupler/product/mixin/form_validation_mixin.dart';
import 'package:gu_kulupler/product/mixin/permission_prompt_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'event_form_view_model.g.dart';

/// MGT-05 "Etkinlik oluştur" / "Etkinliği düzenle" ekranının ViewModel'i
/// (PLAN §12.6; prototip `S['MGT-05']`, `screens-manage.js:87–116`). Aile
/// `clubId` + `editEventId` (`EventFormRoute` / `EventEditRoute` — CD-54).
///
/// * **Açılış:** yeni etkinlikte form prototip varsayılanlarıyla (bugün + 7
///   gün 18:00–20:00 Istanbul, Sosyal, 40 kişi, herkese açık, hatırlatıcı
///   açık, kulübün paleti × dağ deseni) hemen çizilir; düzenlemede etkinlik
///   okunur ([loadForEdit]). Kulüp ve kulübün etkinlikleri (çakışma bandı)
///   arka planda gelir.
/// * **Adımlar:** [next] yalnızca o adımın alanlarını doğrular (prototip
///   `validate`); yazımda tüm alanlar doğrulanır, hata varsa ilk hatalı adıma
///   dönülür.
/// * **Yazım sırası (K-18, CD-47):** belge kimliği önce — yeni etkinlikte
///   `createDraft`, sonra özel kapak `uploadCover`, en son durum geçişi
///   (`managementRepository.publishEvent` / `unpublishEvent`). Düzenlemede
///   yalnızca değişen alanlar yazılır (`EventEditPatch`). Yarıda kalan
///   yazımda ilerleme korunur: yeniden denemede taslak yeniden oluşturulmaz,
///   yüklenmiş kapak yeniden yüklenmez.
/// * **Zaman kilidi (W-82):** yayındaki etkinlik başlamışsa başlangıç / bitiş
///   değişmez ve yazılmaz.
///
/// | İşlem | Koruma | Yazım | Geri bildirim |
/// |---|---|---|---|
/// | [saveDraft] | doğrulama · danışman TST-26 · çevrimdışı TST-24 · K-F | `createDraft` / `update` → `uploadCover` (→ `unpublishEvent`) | TST-13 / TST-X19 |
/// | [saveChanges] | aynı | `createDraft` / `update` → `uploadCover` | TST-13 / TST-21 (yayında) / TST-X9 |
/// | [publish] | aynı + yayında başlangıç gelecekte | `createDraft` / `update` → `uploadCover` → `publishEvent` | TST-30 "Görüntüle" |
///
/// Design: MGT-05
@riverpod
final class EventFormViewModel extends _$EventFormViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        FormValidationMixin<EventField>,
        PermissionPromptMixin {
  static const Set<StorageError> _networkUploadErrors = {
    StorageError.retryLimitExceeded,
    StorageError.timeout,
  };

  bool _isPicking = false;

  /// Kapak elle değişti mi (kulüp paleti sonradan gelince ezilmez).
  bool _coverTouched = false;

  @override
  EventFormState build({required String clubId, String? editEventId}) {
    // Okumalar ilk karede başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_start));
    if (editEventId != null) return const EventFormState(isLoading: true);
    final startsAt = appClock
        .istanbulStartOfDay(appClock.nowUtc())
        .add(_defaultStartOffset);
    return EventFormState(
      startsAt: startsAt,
      endsAt: startsAt.add(EventFormState.defaultDuration),
    );
  }

  static const Duration _defaultStartOffset = Duration(
    days: EventFormState.defaultLeadDays,
    hours: EventFormState.defaultStartHour,
  );

  // ──────────────────────────────── adımlar ─────────────────────────────────

  /// "Devam" (`MGT-05.next`): o adımın alanları geçerliyse sonraki adım.
  void next() {
    if (_isLocked || state.step.isLast) return;
    if (!_validateStep(state.step)) return;
    state = state.copyWith(
      step: EventFormStep.values[state.step.index + 1],
    );
  }

  /// "Geri" (`MGT-05.back`): önceki adım (hatalar korunur).
  void back() {
    if (_isLocked || state.step == EventFormStep.basics) return;
    state = state.copyWith(
      step: EventFormStep.values[state.step.index - 1],
    );
  }

  // ───────────────────────────────── alanlar ────────────────────────────────

  /// Ad (`MGT-05.title`); `Limits.eventTitleMax`'te kesilir.
  void setTitle(String title) {
    final value = _clamped(title, Limits.eventTitleMax);
    if (_isLocked || value == state.title) return;
    state = _edited(state.copyWith(title: value), const [EventField.title]);
  }

  /// Açıklama (`MGT-05.desc`); `Limits.eventDescMax`'te kesilir.
  void setDesc(String desc) {
    final value = _clamped(desc, Limits.eventDescMax);
    if (_isLocked || value == state.desc) return;
    state = _edited(state.copyWith(desc: value), const [EventField.desc]);
  }

  /// Tür çipi (`MGT-05.type.<json>`).
  void setType(EventType type) {
    if (_isLocked || type == state.type) return;
    state = _edited(state.copyWith(type: type), const [EventField.type]);
  }

  /// Başlangıç günü (SHT-28 sonucu, takvim günü): saat korunur.
  void setStartDate(DateTime day) => _setStart(_withDay(state.startsAt, day));

  /// Başlangıç saati (SHT-29 sonucu): gün korunur.
  void setStartTime(TimeOfDayValue time) =>
      _setStart(_withTime(state.startsAt, time));

  /// Bitiş günü (SHT-28 sonucu): saat korunur.
  void setEndDate(DateTime day) => _setEnd(_withDay(state.endsAt, day));

  /// Bitiş saati (SHT-29 sonucu): gün korunur.
  void setEndTime(TimeOfDayValue time) =>
      _setEnd(_withTime(state.endsAt, time));

  /// Mekân (SHT-30 sonucu): tablodaki [placeId] **ya da** serbest
  /// [placeText] (`Limits.placeTextMax`'te kesilir).
  void setPlace({String? placeId, String? placeText}) {
    if (_isLocked) return;
    final text = _clamped((placeText ?? '').trim(), Limits.placeTextMax);
    if (placeId == null && text.isEmpty) return;
    state = _edited(
      placeId != null
          ? state.copyWith(placeId: placeId, placeText: '')
          : state.copyWith(clearPlaceId: true, placeText: text),
      const [EventField.place],
    );
  }

  /// Kontenjan (`MGT-05.capacity.minus` / `.plus`); `null` → sınırsız.
  /// Değer 1 – `EventFormState.capacityMax` aralığına kırpılır.
  void setCapacity(int? value) {
    if (_isLocked) return;
    if (value == null) {
      setUnlimited(value: true);
      return;
    }
    final capacity = value.clamp(1, EventFormState.capacityMax);
    if (!state.isUnlimited && capacity == state.capacity) return;
    state = _edited(
      state.copyWith(capacity: capacity, isUnlimited: false),
      const [EventField.capacity],
    );
  }

  /// "Sınırsız" anahtarı (`MGT-05.unlimited`); kapanınca önceki değer döner.
  void setUnlimited({required bool value}) {
    if (_isLocked || value == state.isUnlimited) return;
    state = _edited(
      state.copyWith(isUnlimited: value),
      const [EventField.capacity],
    );
  }

  /// Görünürlük (`MGT-05.visibility.*`).
  void setVisibility(EventVisibility visibility) {
    if (_isLocked || visibility == state.visibility) return;
    state = state.copyWith(visibility: visibility, isDirty: true);
  }

  /// Otomatik hatırlatıcı (`MGT-05.autoReminder`).
  void setAutoReminder({required bool value}) {
    if (_isLocked || value == state.autoReminder) return;
    state = state.copyWith(autoReminder: value, isDirty: true);
  }

  /// SHT-31 şablonu (`SHT-31.use`): [palette] × [pattern]; özel kapak
  /// (seçilmiş ya da yüklenmiş) bırakılır — dosya silinmez (D-10). Desen
  /// tohumu etkinlik kimliğinden türer (Rules), yazılmaz.
  void setCoverTemplate(ClubPalette palette, ClubPattern pattern) {
    if (_isLocked) return;
    _coverTouched = true;
    if (palette == state.coverPalette &&
        pattern == state.coverPattern &&
        state.coverPath == null &&
        state.pendingCover == null) {
      return;
    }
    state = state.copyWith(
      coverPalette: palette,
      coverPattern: pattern,
      clearCoverPath: true,
      clearPendingCover: true,
      isDirty: true,
      isSubmitError: false,
    );
  }

  /// SHT-31 "Galeriden seç" → SHT-16 [source]: görsel seçtirir; yükleme
  /// kaydetme / yayın anındadır (belge kimliğinden sonra — CD-47). Vazgeçme
  /// durumu değiştirmez; işlenemeyen görsel hata bandı değil günlüğe düşer
  /// (seçicinin kendi uyarıları `PermissionPromptMixin`'dedir).
  Future<void> pickCover(MediaSource source) async {
    if (_isPicking || _isLocked) return;
    _isPicking = true;
    try {
      final result = await pickImage(source);
      if (!ref.mounted) return;
      switch (result) {
        case ImagePickSuccess(:final image):
          _coverTouched = true;
          state = state.copyWith(
            pendingCover: image,
            isDirty: true,
            isSubmitError: false,
          );
        case ImagePickCancelled():
          break;
        case ImagePickFailure(:final error):
          AppLogger.warn('Etkinlik kapağı seçilemedi: ${error.name}');
      }
    } finally {
      _isPicking = false;
    }
  }

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// Düzenlenecek etkinliği okur ve formu doldurur; hata görünümündeki
  /// "Yeniden dene" (`MGT-05.retry`). Başka kulübün, iptal edilmiş ya da
  /// silinmiş etkinliği düzenlenemez (hata görünümü).
  Future<void> loadForEdit() async {
    final eventId = editEventId;
    if (eventId == null || !ref.mounted) return;
    state = state.copyWith(isLoading: true, isError: false);
    final result = await eventRepository.getEvent(eventId);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data)
          when data.clubId == clubId && data.status != EventStatus.cancelled:
        _coverTouched = true;
        final capacity = data.capacity;
        state = EventFormState(
          step: state.step,
          original: data,
          club: state.club,
          clubEvents: state.clubEvents,
          title: data.title,
          desc: data.desc,
          type: data.type,
          startsAt: data.startsAt,
          endsAt: data.endsAt,
          placeId: data.placeId,
          placeText: data.placeId == null ? data.placeText ?? '' : '',
          capacity: capacity ?? EventFormState.defaultCapacity,
          isUnlimited: capacity == null,
          visibility: data.visibility,
          autoReminder: data.autoReminder,
          coverPalette: data.coverPalette,
          coverPattern: data.coverPattern,
          coverPath: data.coverPath,
          timeLocked: _isTimeLocked(data),
        );
      case FirebaseSuccess(:final data):
        AppLogger.warn(
          'Düzenlenemeyen etkinlik: $eventId (${data.status.name})',
        );
        state = state.copyWith(isLoading: false, isError: true);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Düzenlenecek etkinlik okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isLoading: false, isError: true);
    }
  }

  // ─────────────────────────────── doğrulama ────────────────────────────────

  /// Tüm alanları doğrular; hata varsa ilk hatalı alanın adımına döner.
  /// [forPublish] → yayın koşulları da (başlangıç gelecekte, mekân zorunlu).
  /// Taslak kaydında mekân aranmaz (`EventDraft`: isteğe bağlı) — yalnızca
  /// yayındaki etkinlikte.
  bool validate({bool forPublish = false}) {
    final errors = _errors(
      EventField.values,
      forPublish: forPublish,
      requirePlace: forPublish || state.isPublished,
    );
    final first = firstErrorField(errors, EventField.values);
    state = state.copyWith(errors: errors, step: first?.step);
    return errors.isEmpty;
  }

  // ───────────────────────────────── yazım ──────────────────────────────────

  /// "Taslak olarak kaydet" (`MGT-05.saveDraft`): yeni / taslak etkinlikte
  /// içerik kaydedilir (TST-13); yayındaki etkinlikte içerik kaydedilip
  /// taslağa alınır (TST-X19) — yalnızca kayıtlı yokken (K-F).
  Future<EventFormOutcome> saveDraft() => _submit(
    state.isPublished ? _Transition.unpublish : _Transition.none,
  );

  /// DLG-25 "Kaydet": içerik kaydedilir, durum değişmez — taslak TST-13,
  /// yayındaki etkinlik TST-21; değişiklik yoksa TST-X9.
  Future<EventFormOutcome> saveChanges() => _submit(_Transition.none);

  /// "Yayınla" (`MGT-05.publish`, DLG-22 onayından sonra): içerik kaydedilir
  /// ve taslak yayınlanır; [notify] → üyelere `event_new` bildirimi. Yayındaki
  /// etkinlikte "Kaydet" olarak çalışır ([saveChanges]). [onView] TST-30'un
  /// "Görüntüle" eylemidir (etkinlik kimliğiyle).
  Future<EventFormOutcome> publish({
    required bool notify,
    void Function(String eventId)? onView,
  }) => state.isPublished
      ? _submit(_Transition.none)
      : _submit(_Transition.publish, notify: notify, onView: onView);

  /// DLG-22 "{n} üyeye bildirim gönder" sayısı (CD-38): yayıncı hariç aktif
  /// üyeler ∪ herkese açıksa kulüp kategorisiyle ilgi eşleşen kullanıcılar
  /// (≤ `Limits.eventNewInterestFanOutMax`) —
  /// `recipientResolver.estimateEventNew`. Kulüp okunmadıysa / tahmin
  /// okunamazsa kulübün üye sayısı (prototip `clubMembers(club.id).length`).
  Future<int> estimateRecipients() async {
    final club = state.club;
    final uid = ref.read(sessionViewModelProvider).uid;
    final startsAt = state.startsAt;
    final endsAt = state.endsAt;
    final fallback = club?.memberCount ?? 0;
    if (club == null || uid == null || startsAt == null || endsAt == null) {
      return fallback;
    }
    final event = EventModel(
      id: state.original?.id ?? '',
      clubId: clubId,
      title: state.title.trim(),
      type: state.type ?? EventType.social,
      startsAt: startsAt,
      endsAt: endsAt,
      coverPalette: state.coverPalette,
      coverPattern: state.coverPattern,
      createdBy: uid,
      visibility: state.visibility,
    );
    final result = await recipientResolver.estimateEventNew(event, club);
    switch (result) {
      case FirebaseSuccess(:final data):
        return data;
      case FirebaseFailure(:final error):
        AppLogger.warn('DLG-22 alıcı tahmini okunamadı: ${error.name}');
        return fallback;
    }
  }

  // ────────────────────────────────── iç ────────────────────────────────────

  /// Gönderim sürerken / düzenleme okunurken form değişmez.
  bool get _isLocked =>
      !ref.mounted || state.isSubmitting || state.isLoading || state.isError;

  Future<void> _start() async {
    if (!ref.mounted) return;
    await Future.wait<void>([
      if (editEventId != null) loadForEdit(),
      _loadClub(),
      _loadClubEvents(),
    ]);
  }

  Future<void> _loadClub() async {
    final result = await clubRepository.getClub(clubId, forceRefresh: true);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(
          club: data,
          // Yeni etkinliğin kapağı kulübün paletiyle açılır (prototip
          // `club.palette`), kullanıcı değiştirmediyse.
          coverPalette: _coverTouched || editEventId != null
              ? null
              : data.palette,
        );
      case FirebaseFailure(:final error):
        AppLogger.warn('Etkinlik formu: kulüp okunamadı: ${error.name}');
    }
  }

  Future<void> _loadClubEvents() async {
    final result = await eventRepository.listClubEvents(
      clubId,
      const PageRequest(limit: Limits.upcomingEventsFetchMax),
      includeDrafts: true,
    );
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(clubEvents: data.items);
      case FirebaseFailure(:final error):
        // Çakışma bandı yalnızca bilgilendirir: okunamazsa çizilmez.
        AppLogger.warn('Etkinlik formu: etkinlikler okunamadı: ${error.name}');
    }
  }

  bool _isTimeLocked(EventModel event) =>
      event.status == EventStatus.published &&
      !event.startsAt.isAfter(appClock.nowUtc());

  void _setStart(DateTime? startsAt) {
    if (_isLocked || state.timeLocked || startsAt == null) return;
    final endsAt = state.endsAt;
    state = _edited(
      state.copyWith(
        startsAt: startsAt,
        endsAt: endsAt == null || !startsAt.isBefore(endsAt)
            ? startsAt.add(EventFormState.defaultDuration)
            : null,
      ),
      const [EventField.startsAt, EventField.endsAt],
    );
  }

  void _setEnd(DateTime? endsAt) {
    if (_isLocked || state.timeLocked || endsAt == null) return;
    state = _edited(
      state.copyWith(endsAt: endsAt),
      const [EventField.endsAt],
    );
  }

  /// [current] anının Istanbul saatini koruyarak takvim günü [day] olan an;
  /// [current] yoksa günün varsayılan başlangıç saati.
  static DateTime _withDay(DateTime? current, DateTime day) {
    final wall = current?.toUtc().add(Limits.istanbulUtcOffset);
    return DateTime.utc(
      day.year,
      day.month,
      day.day,
      wall?.hour ?? EventFormState.defaultStartHour,
      wall?.minute ?? 0,
    ).subtract(Limits.istanbulUtcOffset);
  }

  /// [current] anının Istanbul gününü koruyarak saati [time] olan an.
  static DateTime? _withTime(DateTime? current, TimeOfDayValue time) {
    if (current == null) return null;
    final wall = current.toUtc().add(Limits.istanbulUtcOffset);
    return DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      time.hour,
      time.minute,
    ).subtract(Limits.istanbulUtcOffset);
  }

  bool _validateStep(EventFormStep step) {
    final fields = [
      for (final field in EventField.values)
        if (field.step == step) field,
    ];
    // "Devam" mekânı her zaman ister (prototip `validate`).
    final errors = _errors(fields, forPublish: false, requirePlace: true);
    state = state.copyWith(errors: errors);
    return errors.isEmpty;
  }

  /// [fields] alanlarının hataları (prototip `validate`,
  /// `screens-manage.js:94`).
  Map<EventField, FormFieldError> _errors(
    List<EventField> fields, {
    required bool forPublish,
    required bool requirePlace,
  }) {
    final startsAt = state.startsAt;
    final endsAt = state.endsAt;
    return validateFields({
      if (fields.contains(EventField.title))
        EventField.title: () => fromFieldError(
          FieldValidators.eventTitle(state.title.trim()),
        ),
      if (fields.contains(EventField.type))
        EventField.type: () =>
            state.type == null ? FormFieldError.required : null,
      if (fields.contains(EventField.startsAt))
        EventField.startsAt: () {
          if (startsAt == null) return FormFieldError.required;
          if (!_mustStartInFuture(forPublish: forPublish)) return null;
          return fromFieldError(FieldValidators.eventStart(startsAt, appClock));
        },
      if (fields.contains(EventField.endsAt))
        EventField.endsAt: () {
          if (endsAt == null) return FormFieldError.required;
          if (startsAt == null) return null;
          return FieldValidators.eventEnd(endsAt, startsAt: startsAt) == null
              ? null
              : FormFieldError.endBeforeStart;
        },
      if (requirePlace && fields.contains(EventField.place))
        EventField.place: () =>
            state.placeId == null && state.placeText.trim().isEmpty
            ? FormFieldError.required
            : null,
      if (fields.contains(EventField.capacity))
        EventField.capacity: () =>
            FieldValidators.capacity(
                  state.capacityValue,
                  goingCount: state.goingCount,
                ) ==
                null
            ? null
            : FormFieldError.capacityBelowGoing,
    });
  }

  /// Başlangıç gelecekte olmalı mı: kilitli zaman denetlenmez; yeni
  /// etkinlikte (prototip `!editing`), yayında ve yayın anında evet.
  bool _mustStartInFuture({required bool forPublish}) {
    if (state.timeLocked) return false;
    return forPublish || editEventId == null || state.isPublished;
  }

  Future<EventFormOutcome> _submit(
    _Transition transition, {
    bool notify = false,
    void Function(String eventId)? onView,
  }) async {
    if (_isLocked) return EventFormOutcome.ignored;
    if (!validate(forPublish: transition == _Transition.publish)) {
      return EventFormOutcome.invalid;
    }
    final session = ref.read(sessionViewModelProvider);
    final uid = session.uid;
    if (uid == null) return EventFormOutcome.ignored;
    // Prototip `app.guard(clubId)`: danışman salt okunurdur.
    if (session.accessTo(clubId) == ClubAccess.advisor) {
      feedback.showToast(ToastId.tst26);
      return EventFormOutcome.blocked;
    }
    // K-F: kayıtlısı olan etkinlik taslağa alınamaz (düğme de kapalıdır).
    if (transition == _Transition.unpublish && !state.canUnpublish) {
      return EventFormOutcome.blocked;
    }
    if (!ensureOnline()) return EventFormOutcome.blocked;

    final original = state.original;
    final patch = original == null ? null : _patchOf(state, original);
    if (transition == _Transition.none &&
        original != null &&
        (patch?.isEmpty ?? true) &&
        state.pendingCover == null) {
      feedback.showToast(ToastId.tstX9);
      state = state.copyWith(isDirty: false);
      return EventFormOutcome.ignored;
    }

    state = state.copyWith(isSubmitting: true, isSubmitError: false);
    final event = await _writeContent(uid, original, patch);
    if (event == null) return EventFormOutcome.failed;
    if (!await _uploadPendingCover(uid, event.id)) {
      return EventFormOutcome.failed;
    }

    switch (transition) {
      case _Transition.publish:
        final result = await managementRepository.publishEvent(
          event.id,
          clubId: clubId,
          actorId: uid,
          notifyMembers: notify,
        );
        if (result case FirebaseFailure(
          :final error,
          :final message,
          :final detail,
        )) {
          return _writeFailed(error, message, detail);
        }
        _done(event.copyWith(status: EventStatus.published));
        feedback.showToast(
          ToastId.tst30,
          onAction: onView == null ? null : () => onView(event.id),
        );
        return EventFormOutcome.published;
      case _Transition.unpublish:
        final result = await managementRepository.unpublishEvent(event.id);
        if (result case FirebaseFailure(
          :final error,
          :final message,
          :final detail,
        )) {
          return _writeFailed(error, message, detail);
        }
        _done(event.copyWith(status: EventStatus.draft));
        feedback.showToast(ToastId.tstX19);
        return EventFormOutcome.unpublished;
      case _Transition.none:
        _done(event);
        feedback.showToast(
          event.status == EventStatus.published ? ToastId.tst21 : ToastId.tst13,
        );
        return EventFormOutcome.saved;
    }
  }

  /// İçeriği yazar ve belgedeki güncel modeli döner; başarısızsa bildirir ve
  /// `null`. Yeni etkinlikte `createDraft` (kimlik alınır), var olanda
  /// yalnızca değişen alanlar (`update`; yama boşsa yazım yok).
  Future<EventModel?> _writeContent(
    String uid,
    EventModel? original,
    EventEditPatch? patch,
  ) async {
    final form = state;
    if (original == null) {
      final result = await eventRepository.createDraft(
        _draftOf(form),
        clubId: clubId,
        createdBy: uid,
      );
      switch (result) {
        case FirebaseSuccess(:final data):
          if (ref.mounted) state = state.copyWith(original: data);
          return data;
        case FirebaseFailure(:final error, :final message, :final detail):
          _writeFailed(error, message, detail);
          return null;
      }
    }
    if (patch == null || patch.isEmpty) return original;
    final result = await eventRepository.update(original.id, patch);
    if (result case FirebaseFailure(
      :final error,
      :final message,
      :final detail,
    )) {
      _writeFailed(error, message, detail);
      return null;
    }
    final updated = _applied(original, patch);
    if (ref.mounted) state = state.copyWith(original: updated);
    return updated;
  }

  /// Seçilmiş özel kapağı [eventId] klasörüne yükler; başarısızsa bildirir
  /// ve `false` (taslak yerinde kalır, yeniden denemede yalnızca kapak).
  Future<bool> _uploadPendingCover(String uid, String eventId) async {
    final cover = state.pendingCover;
    if (cover == null) return true;
    if (ref.mounted) state = state.copyWith(isCoverUploading: true);
    final result = await eventRepository.uploadCover(
      eventId,
      cover.bytes,
      contentType: cover.contentType,
      clubId: clubId,
      uploaderId: uid,
    );
    switch (result) {
      case FirebaseSuccess(:final data):
        if (ref.mounted) {
          state = state.copyWith(
            coverPath: data,
            clearPendingCover: true,
            isCoverUploading: false,
            original: state.original?.copyWith(coverPath: data),
          );
        }
        return true;
      case FirebaseFailure(:final error, :final message):
        _uploadFailed(error, message);
        return false;
    }
  }

  void _done(EventModel event) {
    if (!ref.mounted) return;
    state = state.copyWith(
      original: event,
      isSubmitting: false,
      isDirty: false,
      errors: const {},
    );
    _refreshLists();
  }

  /// Yazımdan sonra yaşayan MGT-04 listesi ve MGT-01 paneli (yaklaşan
  /// etkinlikler, sayaç) içerik kalarak yenilenir: dönüş `go` ile aynı
  /// sayfaya olduğundan ekranlar yeniden kurulmaz.
  void _refreshLists() {
    final events = manageEventsViewModelProvider(clubId);
    if (ref.exists(events)) unawaited(ref.read(events.notifier).refresh());
    final panel = manageViewModelProvider(clubId);
    if (ref.exists(panel)) unawaited(ref.read(panel.notifier).refresh());
  }

  /// Yazım hatası: kontenjan / zaman kuralı alana; ağ → TST-24, yetki yok →
  /// TST-X18; diğerleri hata bandı.
  EventFormOutcome _writeFailed(
    FirestoreError error,
    String? message,
    Object? detail,
  ) {
    final code = detail is FirestoreFailureDetail ? detail.code : null;
    final field = switch (code) {
      FirestoreRuleCode.capacityFull => EventField.capacity,
      FirestoreRuleCode.eventEnded => EventField.startsAt,
      _ => null,
    };
    if (field != null) {
      if (ref.mounted) {
        state = state.copyWith(
          isSubmitting: false,
          isCoverUploading: false,
          step: field.step,
          errors: {
            ...state.errors,
            field: field == EventField.capacity
                ? FormFieldError.capacityBelowGoing
                : FormFieldError.limitExceeded,
          },
        );
      }
      return EventFormOutcome.failed;
    }
    final shown = showWriteFailureToast(error);
    if (!shown) {
      AppLogger.warn('Etkinlik yazılamadı: ${error.name}', error: message);
    }
    if (ref.mounted) {
      state = state.copyWith(
        isSubmitting: false,
        isCoverUploading: false,
        isSubmitError: !shown,
      );
    }
    return EventFormOutcome.failed;
  }

  /// Kapak yükleme hatası: bağlantı → TST-24, Storage reddi → TST-X18;
  /// diğerleri hata bandı.
  void _uploadFailed(MediaUpdateError error, String? message) {
    final storage = error.storage;
    final firestore = error.firestore;
    var shown = true;
    if (_networkUploadErrors.contains(storage) ||
        WriteGuardMixin.networkErrors.contains(firestore)) {
      feedback.showToast(ToastId.tst24);
    } else if (storage == StorageError.unauthorized ||
        firestore == FirestoreError.permissionDenied) {
      feedback.showToast(ToastId.tstX18);
    } else {
      shown = false;
      AppLogger.warn('Etkinlik kapağı yüklenemedi: $error', error: message);
    }
    if (ref.mounted) {
      state = state.copyWith(
        isSubmitting: false,
        isCoverUploading: false,
        isSubmitError: !shown,
      );
    }
  }

  /// [form] alanlarından yeni etkinlik taslağı.
  static EventDraft _draftOf(EventFormState form) {
    final placeText = form.placeText.trim();
    return EventDraft(
      title: form.title.trim(),
      desc: form.desc.trim(),
      type: form.type ?? EventType.social,
      startsAt: form.startsAt!,
      endsAt: form.endsAt!,
      placeId: form.placeId,
      placeText: form.placeId == null && placeText.isNotEmpty
          ? placeText
          : null,
      capacity: form.capacityValue,
      visibility: form.visibility,
      autoReminder: form.autoReminder,
      coverPalette: form.coverPalette,
      coverPattern: form.coverPattern,
    );
  }

  /// [form] ile [original] arasındaki fark: yalnızca değişen alanlar. Kilitli
  /// zaman (W-82) yazılmaz; şablona dönülmüşse özel kapak bırakılır.
  static EventEditPatch _patchOf(EventFormState form, EventModel original) {
    final title = form.title.trim();
    final desc = form.desc.trim();
    final startsAt = form.startsAt;
    final endsAt = form.endsAt;
    final placeId = form.placeId;
    final placeText = form.placeText.trim();
    final capacity = form.capacityValue;
    final timeChanged =
        !form.timeLocked &&
        startsAt != null &&
        endsAt != null &&
        (!startsAt.isAtSameMomentAs(original.startsAt) ||
            !endsAt.isAtSameMomentAs(original.endsAt));
    final placeIdChanged = placeId != null && placeId != original.placeId;
    final placeTextChanged =
        placeId == null && placeText != (original.placeText ?? '');
    return EventEditPatch(
      title: title == original.title ? null : title,
      desc: desc == original.desc ? null : desc,
      type: form.type == original.type ? null : form.type,
      startsAt: timeChanged ? startsAt : null,
      endsAt: timeChanged ? endsAt : null,
      placeId: placeIdChanged ? placeId : null,
      clearPlaceText: placeIdChanged && original.placeText != null,
      placeText: placeTextChanged ? placeText : null,
      clearPlaceId: placeTextChanged && original.placeId != null,
      capacity: capacity != original.capacity ? capacity : null,
      clearCapacity: capacity == null && original.capacity != null,
      visibility: form.visibility == original.visibility
          ? null
          : form.visibility,
      autoReminder: form.autoReminder == original.autoReminder
          ? null
          : form.autoReminder,
      coverPalette: form.coverPalette == original.coverPalette
          ? null
          : form.coverPalette,
      coverPattern: form.coverPattern == original.coverPattern
          ? null
          : form.coverPattern,
      clearCoverPath: form.coverPath == null && original.coverPath != null,
    );
  }

  /// [patch] yazıldıktan sonraki model (yeniden denemede fark doğru kalsın).
  static EventModel _applied(EventModel original, EventEditPatch patch) =>
      original.copyWith(
        title: patch.title,
        desc: patch.desc,
        type: patch.type,
        startsAt: patch.startsAt,
        endsAt: patch.endsAt,
        placeId: patch.placeId,
        placeText: patch.placeText,
        capacity: patch.capacity,
        visibility: patch.visibility,
        autoReminder: patch.autoReminder,
        coverPalette: patch.coverPalette,
        coverPattern: patch.coverPattern,
        clearPlaceId: patch.clearPlaceId,
        clearPlaceText: patch.clearPlaceText,
        clearCapacity: patch.clearCapacity,
        clearCoverPath: patch.clearCoverPath,
      );

  /// Düzenleme sonrası ortak güncelleme: form kirlenir, [fields] alanlarının
  /// hatası ve eski gönderim hatası silinir.
  static EventFormState _edited(
    EventFormState next,
    List<EventField> fields,
  ) => next.copyWith(
    isDirty: true,
    isSubmitError: false,
    errors: {
      for (final entry in next.errors.entries)
        if (!fields.contains(entry.key)) entry.key: entry.value,
    },
  );

  /// [text] metninin [max] karakterle sınırlı hali; vekil çiftin ortasından
  /// kesilmez.
  static String _clamped(String text, int max) {
    if (text.length <= max) return text;
    final end = _isHighSurrogate(text.codeUnitAt(max - 1)) ? max - 1 : max;
    return text.substring(0, end);
  }

  static bool _isHighSurrogate(int unit) => (unit & 0xFC00) == 0xD800;
}

/// Yazımın ardından istenen durum geçişi.
enum _Transition {
  /// Durum değişmez (içerik kaydı).
  none,

  /// Taslak → yayında (DLG-22).
  publish,

  /// Yayında → taslak (K-F).
  unpublish,
}
