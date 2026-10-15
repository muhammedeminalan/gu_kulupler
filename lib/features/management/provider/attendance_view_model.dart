import 'dart:async';
import 'dart:math' as math;

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/attendance_csv.dart';
import 'package:gu_kulupler/features/management/provider/attendance_state.dart';
import 'package:gu_kulupler/features/management/provider/members_csv.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/mixin/manage_event_actions_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'attendance_view_model.g.dart';

/// MGT-06 "Katılımcılar ve yoklama" ViewModel'i (PLAN §12.6; prototip
/// `Attendance`, `screens-manage.js:121–139`). Etkinlik başına ayrı örnek
/// (family `clubId` + `eventId`).
///
/// * Okuma: kulüp + etkinlik tek seferlik; katılımcılar **canlı**
///   (`attendanceRepository.watchParticipants` — §10.6 #5, yalnızca ekran
///   açıkken; sağlayıcı kapanınca dinleyici kapanır). Kullanıcı belgeleri
///   toplu okunur (`userRepository.getUsers`).
/// * Yoklama penceresi (K-G) `EventModel.attendanceWindow` ile `appClock`'tan
///   hesaplanır ([AttendanceState.phase]); her yazımdan önce tazelenir.
///
/// | İşlem | Koruma | Yazım | Geri bildirim |
/// |---|---|---|---|
/// | [setAttended] | danışman TST-26 · kendi kaydı · pencere · çevrimdışı | iyimser anahtar → `markAttended` | `true` → TST-31 "Geri al" ([setAttended] `false`); hata → geri alınır + TST-24 / TST-X18 (pencere → bant) |
/// | [promote] | danışman · kontenjan dolu TST-X14 · çevrimdışı | `promote` (+ `waitlist_promoted`) | TST-X13; `capacityFull` TST-X14, `eventEnded` TST-X6 |
/// | [markAllAttended] | danışman · pencere · DLG-17 | `markAllAttended` (sıralı tekil Tx, [AttendanceState.bulkProgress]) | TST-31 "Tüm kayıtlılar" + "Geri al" (yazılanlar sırayla geri) |
/// | [toggleRegistration] | `ManageEventActionsMixin.setRegistrationOpen` | iyimser `registrationOpen` | TST-X15 |
/// | [exportCsv] | danışman TST-26 | — | paylaşım → TST-29 |
///
/// Danışman (Q-09) hiçbir yazımı yapamaz: TST-26 ([ensureWritable]).
///
/// Design: MGT-06
@riverpod
final class AttendanceViewModel extends _$AttendanceViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        ExternalLinkMixin,
        ManageEventActionsMixin {
  /// CSV'de iletişim belgelerinin aynı anda okunan parça boyu.
  static const int contactBatchSize = 10;

  StreamSubscription<FirestoreResult<List<RsvpModel>>>? _subscription;

  /// Süren tam okuma (ilk yükleme / "Yeniden dene").
  Future<void>? _loading;

  /// Akıştan en az bir başarılı olay geldi mi.
  bool _received = false;

  @override
  AttendanceState build(String clubId, String eventId) {
    ref
      ..onDispose(_cancel)
      ..listen(sessionViewModelProvider, (_, session) {
        final access = session.accessTo(clubId);
        if (access == state.access && session.uid == state.actorId) return;
        state = state.copyWith(
          access: access,
          actorId: session.uid,
          clearActorId: session.uid == null,
        );
      });
    // Okuma ilk karede başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_startLoad));
    final session = ref.read(sessionViewModelProvider);
    return AttendanceState(
      access: session.accessTo(clubId),
      actorId: session.uid,
      isFetching: true,
    );
  }

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// "Yeniden dene" (`MGT-06.retry`): iskeletle baştan okur ve yeniden
  /// dinler.
  Future<void> fetch() async {
    if (!ref.mounted || _loading != null) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _startLoad();
  }

  /// "Etkinlik değiştir" (`MGT-06.switchEvent`) menüsünün etkinlikleri:
  /// kulübün taslak olmayan, silinmemiş etkinlikleri, en yeni üstte
  /// (prototip `clubEvents`). Okunamazsa yalnızca açık etkinlik.
  Future<List<EventModel>> switchableEvents() async {
    final current = state.event;
    final result = await eventRepository.listClubEvents(
      clubId,
      const PageRequest(limit: Limits.upcomingEventsFetchMax),
    );
    final events = switch (result) {
      FirebaseSuccess(:final data) => [
        for (final e in data.items)
          if (!e.isDeleted && e.status != EventStatus.draft) e,
      ],
      FirebaseFailure(:final error) => () {
        AppLogger.warn('Kulüp etkinlikleri okunamadı: ${error.name}');
        return <EventModel>[];
      }(),
    };
    if (current != null && events.every((e) => e.id != current.id)) {
      events.add(current);
    }
    return events..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  }

  // ─────────────────────────────── gezinme ──────────────────────────────────

  /// Özet çipi (`MGT-06.summary.<id>`).
  void setSummary(AttendanceSummaryFilter summary) {
    if (!ref.mounted || summary == state.summary) return;
    state = state.copyWith(summary: summary);
  }

  /// Arama alanı (`MGT-06.search`): ad, Türkçe küçük harfle süzülür.
  void setQuery(String query) {
    if (!ref.mounted || query == state.query) return;
    state = state.copyWith(query: query);
  }

  // ───────────────────────────────── yazma ──────────────────────────────────

  /// Danışman bakışında yazan eyleme dokunuldu → TST-26.
  void onReadOnlyTap() => feedback.showToast(ToastId.tst26);

  /// Kontenjan dolu iken devre dışı "Kayıtlıya al"a dokunuldu → TST-X14.
  void onCapacityFullTap() => feedback.showToast(ToastId.tstX14);

  /// Yazan eylemden önce: danışmansa TST-26 ve `false`.
  bool ensureWritable() {
    if (!state.isReadOnly) return true;
    onReadOnlyTap();
    return false;
  }

  /// "Katıldı" anahtarı (`MGT-06.attended.<id>`): iyimser `going ↔
  /// attended` → `attendanceRepository.markAttended`. İşaretlemede TST-31
  /// "{ad} katıldı olarak işaretlendi." + "Geri al" (aynı yazımın tersi);
  /// kaldırmada toast yok. Yazılamazsa anahtar geri döner (TST-24 /
  /// TST-X18; pencere kapandıysa bant). Yazıldıysa `true`.
  Future<bool> setAttended(String userId, bool value) async {
    if (!ref.mounted) return false;
    final actorId = state.actorId;
    final rsvp = state.find(userId);
    if (actorId == null || rsvp == null || state.isOwn(userId)) return false;
    if (state.pendingIds.contains(userId) || state.isBulkRunning) return false;
    if (!ensureWritable() || !_windowOpen() || !ensureOnline()) return false;
    final from = value ? RsvpStatus.going : RsvpStatus.attended;
    if (rsvp.status != from) return false;
    final to = value ? RsvpStatus.attended : RsvpStatus.going;
    state = state.copyWith(
      marks: {...state.marks, userId: to},
      pendingIds: {...state.pendingIds, userId},
    );
    final result = await attendanceRepository.markAttended(
      eventId: eventId,
      userId: userId,
      actorId: actorId,
      attended: value,
    );
    if (!ref.mounted) return result is FirebaseSuccess;
    state = state.copyWith(pendingIds: {...state.pendingIds}..remove(userId));
    switch (result) {
      case FirebaseSuccess():
        _settle();
        if (value) {
          feedback.showToast(
            ToastId.tst31,
            params: ToastParams(name: state.nameOf(userId)),
            onAction: () => unawaited(setAttended(userId, false)),
          );
        }
        return true;
      case FirebaseFailure(:final error, :final detail, :final message):
        _unmark([userId]);
        _reportFailure(error, detail, message, 'Yoklama yazılamadı');
        return false;
    }
  }

  /// "Kayıtlıya al" (`MGT-06.promote.<id>`): kontenjan doluysa TST-X14
  /// (düğme de devre dışıdır); `attendanceRepository.promote` → TST-X13.
  /// Liste akıştan güncellenir (iyimser değil). Terfi ettiyse `true`.
  Future<bool> promote(String userId) async {
    if (!ref.mounted) return false;
    final actorId = state.actorId;
    if (actorId == null || state.pendingIds.contains(userId)) return false;
    if (!ensureWritable()) return false;
    if (state.isFull) {
      feedback.showToast(ToastId.tstX14);
      return false;
    }
    if (!ensureOnline()) return false;
    state = state.copyWith(pendingIds: {...state.pendingIds, userId});
    final result = await attendanceRepository.promote(
      eventId: eventId,
      userId: userId,
      actorId: actorId,
    );
    if (!ref.mounted) return result is FirebaseSuccess;
    state = state.copyWith(pendingIds: {...state.pendingIds}..remove(userId));
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(
          ToastId.tstX13,
          params: ToastParams(name: state.nameOf(userId)),
        );
        return true;
      case FirebaseFailure(:final error, :final detail, :final message):
        _reportFailure(error, detail, message, 'Terfi yazılamadı');
        return false;
    }
  }

  /// "Tüm kayıtlıları katıldı yap" (`MGT-06.markAll`): DLG-17 ("Tüm
  /// kayıtlılar ({n}) …") → `attendanceRepository.markAllAttended` (her kayıt
  /// ayrı transaction, sıralı; ilerleme [AttendanceState.bulkProgress]) →
  /// TST-31 ([allLabel] "Tüm kayıtlılar") + "Geri al" (yazılanlar sırayla
  /// `going`'e döner). Kendi kaydı kümeye girmez (CD-153). Yazım olduysa
  /// `true`.
  Future<bool> markAllAttended({required String allLabel}) async {
    if (!ref.mounted) return false;
    final actorId = state.actorId;
    if (actorId == null || state.isBulkRunning) return false;
    if (!ensureWritable() || !_windowOpen()) return false;
    final targets = [
      for (final r in state.registered)
        if (r.status == RsvpStatus.going && !state.isOwn(r.userId)) r.userId,
    ];
    if (targets.isEmpty) return false;
    final confirmed = await feedback.showDialog<bool>(
      DialogId.dlg17,
      params: {
        DialogParamKeys.kind: BulkActionKind.attendance,
        DialogParamKeys.count: state.registered.length,
      },
    );
    if (confirmed != true || !ref.mounted || !ensureOnline()) return false;
    state = state.copyWith(bulkProgress: (done: 0, total: targets.length));
    final result = await attendanceRepository.markAllAttended(
      eventId: eventId,
      clubId: clubId,
      actorId: actorId,
      onProgress: (done, total) {
        if (ref.mounted) {
          state = state.copyWith(bulkProgress: (done: done, total: total));
        }
      },
    );
    if (!ref.mounted) return result is FirebaseSuccess;
    state = state.copyWith(clearBulkProgress: true);
    switch (result) {
      case FirebaseSuccess(:final data):
        if (data.failed.isNotEmpty || data.conflicted.isNotEmpty) {
          AppLogger.warn(
            'Toplu yoklama: ${data.failed.length} yazılamadı, '
            '${data.conflicted.length} çakıştı',
          );
        }
        final succeeded = [...data.succeeded];
        if (succeeded.isEmpty) return false;
        feedback.showToast(
          ToastId.tst31,
          params: ToastParams(name: allLabel),
          onAction: () => unawaited(_undoBulk(succeeded)),
        );
        return true;
      case FirebaseFailure(:final error, :final detail, :final message):
        _reportFailure(error, detail, message, 'Toplu yoklama yazılamadı');
        return false;
    }
  }

  /// "Kayıtları aç / kapat" (`MGT-06.toggleRegistration`): ortak
  /// `ManageEventActionsMixin.setRegistrationOpen` → TST-X15.
  Future<bool> toggleRegistration() async {
    final event = state.event;
    if (!ref.mounted || event == null) return false;
    return setRegistrationOpen(event, open: !event.registrationOpen);
  }

  /// "Dışa aktar (CSV)" (`MGT-06.export`): bütün katılımcılar (bekleme
  /// listesi dahil) + e-postaları (`membershipRepository.readContact`, en çok
  /// [contactBatchSize] eşzamanlı; okunamayan boş) → [AttendanceCsv] →
  /// `fileService.writeTemp` → `shareService.shareFile` → TST-29.
  /// [statusLabel] durum adını verir (view). Paylaşım açıldıysa `true`.
  Future<bool> exportCsv(String Function(RsvpStatus status) statusLabel) async {
    if (!ref.mounted || state.isExporting || !ensureWritable()) return false;
    state = state.copyWith(isExporting: true);
    try {
      final rows = [...state.registered, ...state.waitlist];
      final emails = await _readEmails([for (final r in rows) r.userId]);
      if (!ref.mounted) return false;
      final text = AttendanceCsv.build([
        for (final r in rows)
          (
            name: state.nameOf(r.userId),
            email: emails[r.userId] ?? '',
            status: r.status,
            scannedAt: r.scannedAt,
          ),
      ], statusLabel);
      final path = await fileService.writeTemp(
        AttendanceCsv.fileName,
        MembersCsv.encode(text),
      );
      if (path == null) {
        AppLogger.warn('Katılımcı listesi dosyası yazılamadı ($eventId)');
        return false;
      }
      final shared = await shareService.shareFile(
        path,
        mimeType: MembersCsv.mimeType,
      );
      if (shared && ref.mounted) feedback.showToast(ToastId.tst29);
      return shared;
    } finally {
      if (ref.mounted) state = state.copyWith(isExporting: false);
    }
  }

  // ───────────────────────── ManageEventActionsMixin ────────────────────────

  @override
  SessionState? get eventSession =>
      ref.mounted ? ref.read(sessionViewModelProvider) : null;

  @override
  void onEventChanged(EventModel event) {
    if (!ref.mounted || event.id != eventId) return;
    state = state.copyWith(event: event);
  }

  @override
  void onEventListStale(String clubId) {
    if (ref.mounted) unawaited(_reloadEvent());
  }

  // ─────────────────────────────── yardımcılar ──────────────────────────────

  /// Pencereyi `appClock`'la tazeler; açıksa `true`.
  bool _windowOpen() {
    final event = state.event;
    if (event == null) return false;
    final phase = _phaseOf(event);
    if (phase != state.phase) state = state.copyWith(phase: phase);
    return phase.isWindowOpen;
  }

  AttendancePhase _phaseOf(EventModel event) {
    final now = appClock.nowUtc();
    if (event.attendanceWindow(appClock)) {
      return now.isBefore(event.startsAt)
          ? AttendancePhase.beforeStart
          : AttendancePhase.open;
    }
    return now.isBefore(event.startsAt)
        ? AttendancePhase.beforeWindow
        : AttendancePhase.closed;
  }

  /// [userIds]'in iyimser işaretlerini kaldırır (sunucu durumu görünür).
  void _unmark(Iterable<String> userIds) {
    final marks = {...state.marks};
    userIds.forEach(marks.remove);
    state = state.copyWith(marks: marks);
  }

  /// Akışın getirdiği durumla örtüşen, yazımı bitmiş işaretleri düşürür.
  void _settle() {
    if (state.marks.isEmpty) return;
    final server = {for (final r in state.rsvps) r.userId: r.status};
    final marks = {
      for (final MapEntry(:key, :value) in state.marks.entries)
        if (state.pendingIds.contains(key) || server[key] != value) key: value,
    };
    if (marks.length != state.marks.length) {
      state = state.copyWith(marks: marks);
    }
  }

  /// TST-31 "Geri al" (toplu): yazılanlar sırayla `going`'e döner (iyimser).
  Future<void> _undoBulk(List<String> userIds) async {
    if (!ref.mounted || !ensureOnline()) return;
    final actorId = state.actorId;
    if (actorId == null) return;
    state = state.copyWith(
      marks: {
        ...state.marks,
        for (final id in userIds) id: RsvpStatus.going,
      },
      pendingIds: {...state.pendingIds, ...userIds},
      bulkProgress: (done: 0, total: userIds.length),
    );
    final failed = <String>[];
    FirestoreError? lastError;
    for (final (index, userId) in userIds.indexed) {
      final result = await attendanceRepository.markAttended(
        eventId: eventId,
        userId: userId,
        actorId: actorId,
        attended: false,
      );
      if (result case FirebaseFailure(:final error)) {
        failed.add(userId);
        lastError = error;
      }
      if (!ref.mounted) return;
      state = state.copyWith(
        pendingIds: {...state.pendingIds}..remove(userId),
        bulkProgress: (done: index + 1, total: userIds.length),
      );
    }
    state = state.copyWith(clearBulkProgress: true);
    _unmark(failed);
    _settle();
    if (lastError != null) {
      AppLogger.warn('Toplu yoklama geri alınamadı: ${lastError.name}');
      if (!showWriteFailureToast(lastError)) {
        feedback.showToast(ToastId.tstX18);
      }
    }
  }

  /// Yazma hatası: pencere → bant (evre tazelenir); kontenjan → TST-X14;
  /// bitmiş etkinlik → TST-X6; ağ → TST-24, yetki → TST-X18; diğerleri
  /// günlüğe + TST-X18.
  void _reportFailure(
    FirestoreError error,
    Object? detail,
    String? message,
    String what,
  ) {
    AppLogger.warn('$what: ${error.name}', error: message);
    final code = detail is FirestoreFailureDetail ? detail.code : null;
    switch (code) {
      case FirestoreRuleCode.attendanceWindowClosed:
        final event = state.event;
        if (event != null) {
          state = state.copyWith(
            phase: appClock.nowUtc().isBefore(event.startsAt)
                ? AttendancePhase.beforeWindow
                : AttendancePhase.closed,
          );
        }
        return;
      case FirestoreRuleCode.capacityFull:
        feedback.showToast(ToastId.tstX14);
        return;
      case FirestoreRuleCode.eventEnded:
        feedback.showToast(ToastId.tstX6);
        return;
      case _:
        if (!showWriteFailureToast(error)) feedback.showToast(ToastId.tstX18);
    }
  }

  Future<void> _startLoad() {
    final running = _loading;
    if (running != null) return running;
    final future = _load().whenComplete(() => _loading = null);
    return _loading = future;
  }

  /// Kulüp + etkinlik okunur, katılımcılar dinlenmeye başlar. Etkinlik
  /// okunamazsa (ya da başka kulübün / silinmişse) hata görünümü.
  Future<void> _load() async {
    _cancel();
    final (club, event) = await (
      clubRepository.getClub(clubId),
      eventRepository.getEvent(eventId),
    ).wait;
    if (!ref.mounted) return;
    if (club case FirebaseFailure(:final error)) {
      AppLogger.warn('Yoklama: kulüp okunamadı: ${error.name}');
    }
    switch (event) {
      case FirebaseSuccess(:final data)
          when !data.isDeleted && data.clubId == clubId:
        state = state.copyWith(
          club: club.dataOrNull,
          event: data,
          phase: _phaseOf(data),
        );
        _received = false;
        _subscription = attendanceRepository
            .watchParticipants(eventId: eventId, clubId: clubId)
            .listen(_onParticipants);
      case FirebaseSuccess():
        state = state.copyWith(isFetching: false, isError: true);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Yoklama: etkinlik okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isFetching: false, isError: true);
    }
  }

  /// Etkinliği içerik kalarak yeniden okur (çakışma sonrası).
  Future<void> _reloadEvent() async {
    final result = await eventRepository.getEvent(eventId);
    if (!ref.mounted) return;
    if (result case FirebaseSuccess(:final data) when !data.isDeleted) {
      state = state.copyWith(event: data, phase: _phaseOf(data));
    }
  }

  /// Katılımcı olayı: silinmiş ve `cancelled` kayıtlar süzülür; yazımı
  /// bitmiş işaretler düşer; yeni kullanıcıların belgeleri okunur.
  void _onParticipants(FirestoreResult<List<RsvpModel>> result) {
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        _received = true;
        final rsvps = [
          for (final r in data)
            if (!r.isDeleted && r.status != RsvpStatus.cancelled) r,
        ];
        state = state.copyWith(
          rsvps: rsvps,
          isFetching: false,
          isError: false,
        );
        _settle();
        unawaited(_loadUsers([for (final r in rsvps) r.userId]));
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn('Katılımcılar okunamadı: ${error.name}', error: message);
        // İçerik varken gelen hata ekrandakini silmez.
        state = state.copyWith(isFetching: false, isError: !_received);
    }
  }

  /// [userIds] içinden belgesi henüz okunmamış olanlar; okunamazsa satırlar
  /// adsız kalır.
  Future<void> _loadUsers(List<String> userIds) async {
    final missing = [
      for (final id in userIds)
        if (!state.users.containsKey(id)) id,
    ];
    if (missing.isEmpty) return;
    final result = await userRepository.getUsers(missing);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(
          users: {...state.users, for (final u in data) u.uid: u},
        );
      case FirebaseFailure(:final error):
        AppLogger.warn('Katılımcı profilleri okunamadı: ${error.name}');
    }
  }

  /// [userIds] üyelerinin e-postaları, [contactBatchSize]'lık parçalarla;
  /// okunamayan (üye olmayan katılımcı) boş kalır.
  Future<Map<String, String>> _readEmails(List<String> userIds) async {
    final emails = <String, String>{};
    for (var start = 0; start < userIds.length; start += contactBatchSize) {
      final batch = userIds.sublist(
        start,
        math.min(start + contactBatchSize, userIds.length),
      );
      final results = await Future.wait([
        for (final id in batch) membershipRepository.readContact(clubId, id),
      ]);
      if (!ref.mounted) return emails;
      for (final (index, result) in results.indexed) {
        emails[batch[index]] = result.dataOrNull?.email.trim() ?? '';
      }
    }
    return emails;
  }

  void _cancel() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}
