import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/event_calendar_mixin.dart';
import 'package:gu_kulupler/features/events/provider/ticket_state.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ticket_view_model.g.dart';

/// EVT-03 "Bilet" ekranının ViewModel'i (PLAN §12.6; prototip `S['EVT-03']`,
/// `screens-events.js:74–87`).
///
/// * **Canlı veri** (PLAN §10.6 #4): kullanıcının katılım kaydı
///   (`rsvpRepository.watchMine`) yalnızca ekran açıkken dinlenir;
///   ViewModel kapanınca abonelik iptal edilir. Etkinlik ve kulüp bir kez
///   okunur.
/// * Yönetici bileti okutunca (`going → attended` geçişi akışta görülünce)
///   TST-15 gösterilir; QR bulanıklaşır, rozet "Okutuldu" olur.
/// * Etkinlik yok / silinmiş / görünmüyor → [TicketViewState.isNotFound]
///   (SYS-04). Kayıt yok ya da bekleme listesinde →
///   [TicketViewState.hasNoTicket] (view EVT-02'ye döner).
///
/// | İşlem | Koruma | Yazım | Geri bildirim |
/// |---|---|---|---|
/// | [leave] | DLG-14 onayı → çevrimdışı TST-24 | `rsvpRepository.cancel` + `localReminderService.cancel` | TST-42; bitmiş etkinlik TST-X6 |
/// | `addToCalendar` | — | yok (`EventCalendarMixin`) | TST-36 / DLG-32 / TST-35 |
///
/// Design: EVT-03
@riverpod
final class TicketViewModel extends _$TicketViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        ExternalLinkMixin,
        EventCalendarMixin {
  StreamSubscription<FirestoreResult<RsvpModel?>>? _subscription;

  @override
  TicketViewState build(String eventId) {
    ref.onDispose(_cancel);
    // Okuma ilk karede başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_start));
    return const TicketViewState(isFetching: true);
  }

  String? get _uid =>
      ref.mounted ? ref.read(sessionViewModelProvider).uid : null;

  /// "Yeniden dene": etkinliği yeniden okur ve kaydı yeniden dinler.
  Future<void> fetch() async {
    if (!ref.mounted) return;
    state = state.copyWith(
      isFetching: true,
      isError: false,
      isNotFound: false,
      hasNoTicket: false,
    );
    await _start();
  }

  /// "Vazgeç" (`EVT-03.leave`): DLG-14 onayı → `rsvpRepository.cancel` →
  /// yerel hatırlatıcı iptali + TST-42. `true` → vazgeçildi (view önceki
  /// sayfaya döner). Bitmiş etkinlikte TST-X6 (W-81 (b)).
  Future<bool> leave() async {
    final uid = _uid;
    final rsvp = state.rsvp;
    if (uid == null || rsvp == null || state.isLeaving) return false;
    final confirmed = await feedback.showDialog<bool>(DialogId.dlg14);
    if (!(confirmed ?? false) || !ensureOnline()) return false;
    if (ref.mounted) state = state.copyWith(isLeaving: true);
    final result = await rsvpRepository.cancel(eventId: eventId, userId: uid);
    if (ref.mounted) state = state.copyWith(isLeaving: false);
    switch (result) {
      case FirebaseSuccess():
        await localReminderService.cancel(rsvp.id);
        feedback.showToast(ToastId.tst42);
        return true;
      case FirebaseFailure(
        error: FirestoreError.ruleViolation,
        detail: FirestoreFailureDetail(code: FirestoreRuleCode.eventEnded),
      ):
        feedback.showToast(ToastId.tstX6);
        return false;
      case FirebaseFailure(:final error, :final message):
        if (!showWriteFailureToast(error)) {
          AppLogger.warn(
            'Katılımdan vazgeçilemedi: ${error.name}',
            error: message,
          );
        }
        return false;
    }
  }

  // ───────────────────────────────── okuma ──────────────────────────────────

  Future<void> _start() async {
    if (!ref.mounted) return;
    _cancel();
    final uid = _uid;
    if (uid == null) {
      state = state.copyWith(isFetching: false, isNotFound: true);
      return;
    }
    final result = await eventRepository.getEvent(eventId);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data) when !data.isDeleted:
        state = state.copyWith(event: data);
        unawaited(_loadClub(data.clubId));
        _subscription = rsvpRepository
            .watchMine(eventId: eventId, userId: uid)
            .listen(_onRsvp);
      case FirebaseSuccess():
      case FirebaseFailure(
        error: FirestoreError.permissionDenied || FirestoreError.notFound,
      ):
        state = state.copyWith(isFetching: false, isNotFound: true);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn('Etkinlik okunamadı: ${error.name}', error: message);
        state = state.copyWith(
          isFetching: false,
          isError: state.event == null,
        );
    }
  }

  Future<void> _loadClub(String clubId) async {
    final result = await clubRepository.getClub(clubId);
    if (!ref.mounted) return;
    if (result case FirebaseSuccess(:final data)) {
      state = state.copyWith(club: data);
    }
  }

  /// Kayıt olayı. Bilet yoksa (kayıt yok / silinmiş / bekleme listesi)
  /// [TicketViewState.hasNoTicket]; `going → attended` geçişinde TST-15.
  void _onRsvp(FirestoreResult<RsvpModel?> event) {
    if (!ref.mounted) return;
    switch (event) {
      case FirebaseSuccess(:final data):
        if (data == null ||
            data.isDeleted ||
            data.status == RsvpStatus.waitlist) {
          state = state.copyWith(
            clearRsvp: true,
            isFetching: false,
            isError: false,
            hasNoTicket: true,
          );
          return;
        }
        final previous = state.rsvp?.status;
        state = state.copyWith(
          rsvp: data,
          isFetching: false,
          isError: false,
          hasNoTicket: false,
        );
        if (previous == RsvpStatus.going &&
            data.status == RsvpStatus.attended) {
          feedback.showToast(ToastId.tst15);
        }
      case FirebaseFailure(error: FirestoreError.permissionDenied):
        state = state.copyWith(isFetching: false, isNotFound: true);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn('Bilet okunamadı: ${error.name}', error: message);
        // İçerik varken gelen hata ekranda kalanı silmez.
        state = state.copyWith(
          isFetching: false,
          isError: state.rsvp == null,
        );
    }
  }

  void _cancel() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}
