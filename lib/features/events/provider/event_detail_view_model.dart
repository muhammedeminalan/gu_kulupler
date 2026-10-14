import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show VoidCallback;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/event_calendar_mixin.dart';
import 'package:gu_kulupler/features/events/provider/event_detail_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/share_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/mixin/manage_event_actions_mixin.dart';
import 'package:gu_kulupler/product/mixin/report_received_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'event_detail_view_model.g.dart';

/// EVT-02 "Etkinlik" ekranının ViewModel'i (etkinlik başına bir örnek; PLAN
/// §12.6, prototip `S['EVT-02']`, `screens-events.js:37–75`).
///
/// * Etkinlik, kulüp ve kullanıcının kaydı açılışta okunur (canlı dinleme
///   yok — bilet canlılığı `TicketViewModel`'dedir); erişim kipi oturumdan
///   canlı gelir.
/// * Okuma sonuçları (CD-57): etkinlik okunamıyor (`permissionDenied` —
///   üyelere özel, taslak) → TST-X18 + [EventDetailState.isDenied] (view
///   Etkinlikler sekmesine döner); yok / silinmiş, kulübü yok ya da askıda →
///   [EventDetailState.isNotFound] (SYS-04).
/// * Katılım transaction'lıdır ve iyimser değildir ([EventDetailState
///   .isActing]); kontenjan yarışı sunucuda çözülür: yeni katılım kontenjan
///   doluyken **ya da** önde bekleyen varken bekleme listesine düşer
///   (`EventModel.joinsWaitlist`, W-81 (a)). Hatırlatıcı tercihi iyimserdir.
/// * Sheet açma ve gezinme view'dadır; dialog ve toast'lar buradan.
///
/// | İşlem | Koruma | Yazım | Geri bildirim |
/// |---|---|---|---|
/// | [join] | çevrimdışı TST-24 | `rsvpRepository.join` → hatırlatıcı planı | `going` TST-41 ("Biletini göster") · `waitlist` TST-43 `{n}` · kapalı TST-X2 · bitti TST-X6 · yetki TST-X18 |
/// | [joinWaitlist] | çevrimdışı TST-24 → DLG-15 | [join] (1 saat önce) | TST-43 |
/// | [cancelRsvp] | bitti TST-X6 (W-81 (b)) → DLG-14 → çevrimdışı | `rsvpRepository.cancel` → plan iptali | TST-42 |
/// | [setReminder] | kayıt yok TST-X7 · çevrimdışı | iyimser `setReminder` → plan / iptal | TST-37 (hata → geri alınır) |
/// | `addToCalendar` | — | `EventCalendarMixin`: `.ics` → paylaşım · Google Takvim (DLG-32) · kopyala | TST-36 · TST-35 |
/// | [share] | — | SHT-15 seçimi | TST-35 · DLG-32 · sistem paylaşımı |
/// | [submitReport] → [showReportReceived] | çevrimdışı | `reportRepository.report` | DLG-12 |
/// | [openManageMenu] (yönetici "⋮") | `ManageEventActionsMixin` | SHT-23 satırları (MGT-04 ile ortak) | TST-13 · TST-X19 · TST-48 · TST-45 |
///
/// Design: EVT-02, DLG-14, DLG-15, DLG-16
@riverpod
final class EventDetailViewModel extends _$EventDetailViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        ExternalLinkMixin,
        EventCalendarMixin,
        ReportReceivedMixin,
        ManageEventActionsMixin {
  /// Etkinliğin olmadığını söyleyen okuma hataları (→ SYS-04).
  static const Set<FirestoreError> _missingErrors = {
    FirestoreError.notFound,
    FirestoreError.parse,
  };

  /// DLG-16'nın bu oturumda gösterildiği etkinlikler (prototip
  /// `shownCancelled`, `screens-events.js:38`).
  static final Set<String> _cancelledNoticeShown = <String>{};

  /// Testler arasında DLG-16 kaydını sıfırlar.
  @visibleForTesting
  static void resetCancelledNotices() => _cancelledNoticeShown.clear();

  bool _isLoading = false;

  @override
  EventDetailState build(String eventId) {
    ref.listen(sessionViewModelProvider, (_, session) {
      final clubId = state.event?.clubId;
      if (clubId == null) return;
      final access = session.accessTo(clubId);
      if (access != state.access) state = state.copyWith(access: access);
    });
    // İlk okuma ilk karede başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    return const EventDetailState(isFetching: true);
  }

  String? get _uid =>
      ref.mounted ? ref.read(sessionViewModelProvider).uid : null;

  /// Şikayet hedefi: bu etkinlik (SHT-10; `targetClubId` = kulübü).
  ReportTarget? get reportTarget {
    final event = state.event;
    if (event == null) return null;
    return (type: ReportTargetType.event, id: eventId, clubId: event.clubId);
  }

  /// Etkinliğin paylaşım bağlantısı (`AppConstants.shareBaseUrl` + yol;
  /// SHT-15, SHT-14 "Bağlantıyı kopyala").
  String shareUrl() => EventLinks.share(eventId);

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// Etkinliği yeniden okur — hata görünümündeki "Yeniden dene".
  Future<void> fetch() async {
    if (!ref.mounted || _isLoading) return;
    state = state.copyWith(isFetching: true, isError: false, isNotFound: false);
    await _load();
  }

  /// Görünen etkinliği iskeletsiz yeniler (kayıt ve sayaçlar). Okunamazsa
  /// eldeki içerik kalır.
  Future<void> refresh() async {
    if (!ref.mounted || _isLoading || state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true);
    await _load();
  }

  // ─────────────────────────────── katılım ──────────────────────────────────

  /// SHT-12 "Katılımı onayla" (`EVT-02.join`) ya da DLG-15 onayı sonrası:
  /// [reminder] tercihiyle kayıt. Sonuç kayıtlıysa yerel hatırlatıcı
  /// planlanır ve TST-41 gösterilir ([onTicket] — "Biletini göster" →
  /// EVT-03); bekleme listesindeyse sıra katılımdan hemen sonra okunan
  /// `events.waitlistCount`'tur (W-76) → TST-43.
  Future<EventJoinOutcome> join(
    ReminderOption reminder, {
    VoidCallback? onTicket,
  }) async {
    final uid = _uid;
    final event = state.event;
    if (uid == null || event == null || state.isActing) {
      return EventJoinOutcome.failed;
    }
    if (!ensureOnline()) return EventJoinOutcome.failed;
    state = state.copyWith(isActing: true);
    final result = await rsvpRepository.join(
      eventId: eventId,
      clubId: event.clubId,
      userId: uid,
      reminder: reminder,
    );
    switch (result) {
      case FirebaseSuccess(:final data):
        // Sayaçlar ve sıra sunucudan; okunamazsa yerel ±1.
        final fresh = (await eventRepository.getEvent(eventId)).dataOrNull;
        final updated = fresh ?? _counted(event, data.status, 1);
        final isWaitlist = data.status == RsvpStatus.waitlist;
        if (ref.mounted) {
          state = state.copyWith(
            event: updated,
            rsvp: data,
            isActing: false,
            waitlistPosition: isWaitlist ? updated.waitlistCount : null,
            clearWaitlistPosition: !isWaitlist,
          );
        }
        if (isWaitlist) {
          feedback.showToast(
            ToastId.tst43,
            params: ToastParams(n: updated.waitlistCount),
          );
          return EventJoinOutcome.waitlist;
        }
        await localReminderService.schedule(rsvp: data, event: updated);
        feedback.showToast(ToastId.tst41, onAction: onTicket);
        return EventJoinOutcome.going;
      case FirebaseFailure(:final error, :final detail, :final message):
        if (ref.mounted) state = state.copyWith(isActing: false);
        _showRsvpFailure(error, detail, message, 'Katılım yazılamadı');
        return EventJoinOutcome.failed;
    }
  }

  /// "Katıl" (`EVT-02.join`) girişi: çevrimdışıysa TST-24 ve `false` (view
  /// SHT-12'yi açmaz — prototip `app.requireOnline() && openSheet`).
  bool ensureCanJoin() =>
      state.event != null && !state.isActing && ensureOnline();

  /// SHT-12 çakışma uyarısı: kullanıcının bu etkinlikle zamanı çakışan başka
  /// bir kaydı (`going` / `attended`; bekleme listesi sayılmaz) var mı
  /// (`sheets.js:62`)? Okunamazsa `false`.
  Future<bool> hasConflict() async {
    final uid = _uid;
    final event = state.event;
    if (uid == null || event == null) return false;
    final mine = await rsvpRepository.listMine(uid);
    final otherIds = [
      for (final rsvp in mine.dataOrNull ?? const <RsvpModel>[])
        if (rsvp.eventId != eventId &&
            (rsvp.status == RsvpStatus.going ||
                rsvp.status == RsvpStatus.attended))
          rsvp.eventId,
    ];
    if (otherIds.isEmpty) return false;
    final others = await eventRepository.getEvents(otherIds);
    return (others.dataOrNull ?? const <EventModel>[]).any(
      (other) =>
          other.status != EventStatus.cancelled &&
          other.startsAt.isBefore(event.endsAt) &&
          other.endsAt.isAfter(event.startsAt),
    );
  }

  /// "Bekleme listesine katıl" (`EVT-02.waitlist`): çevrimdışıysa TST-24;
  /// DLG-15 (şu an bekleyen sayısıyla) onaylanırsa [join] — hatırlatıcı
  /// 1 saat önce (`dialogs.js:31`).
  Future<EventJoinOutcome> joinWaitlist() async {
    final event = state.event;
    if (event == null || state.isActing) return EventJoinOutcome.failed;
    if (!ensureOnline()) return EventJoinOutcome.failed;
    final confirmed =
        await feedback.showDialog<bool>(
          DialogId.dlg15,
          params: {DialogParamKeys.n: event.waitlistCount},
        ) ??
        false;
    if (!confirmed || !ref.mounted) return EventJoinOutcome.failed;
    return join(ReminderOption.oneHour);
  }

  /// "Vazgeç" / "Ayrıl" (`EVT-02.leave`): etkinlik bittiyse TST-X6 (W-81
  /// (b)); DLG-14 (bekleme listesinde ayrı metin) onaylanırsa kayıt iptal
  /// edilir, yerel hatırlatıcı planı kaldırılır → TST-42. `true` → vazgeçildi.
  Future<bool> cancelRsvp() async {
    final uid = _uid;
    final event = state.event;
    final rsvp = state.activeRsvp;
    if (uid == null || event == null || rsvp == null || state.isActing) {
      return false;
    }
    if (!event.endsAt.isAfter(appClock.nowUtc())) {
      feedback.showToast(ToastId.tstX6);
      return false;
    }
    final isWaitlist = rsvp.status == RsvpStatus.waitlist;
    final confirmed =
        await feedback.showDialog<bool>(
          DialogId.dlg14,
          params: {DialogParamKeys.waitlist: isWaitlist},
        ) ??
        false;
    if (!confirmed || !ref.mounted || !ensureOnline()) return false;
    state = state.copyWith(isActing: true);
    final result = await rsvpRepository.cancel(eventId: eventId, userId: uid);
    switch (result) {
      case FirebaseSuccess():
        if (ref.mounted) {
          final current = state.event ?? event;
          state = state.copyWith(
            event: _counted(current, rsvp.status, -1),
            rsvp: rsvp.copyWith(status: RsvpStatus.cancelled),
            isActing: false,
            clearWaitlistPosition: true,
          );
        }
        await localReminderService.cancel(rsvp.id);
        feedback.showToast(ToastId.tst42);
        return true;
      case FirebaseFailure(:final error, :final detail, :final message):
        if (ref.mounted) state = state.copyWith(isActing: false);
        _showRsvpFailure(error, detail, message, 'Katılımdan vazgeçilemedi');
        return false;
    }
  }

  /// "Kayıtlar kapalı" (`EVT-02.join`, devre dışı) → TST-X2.
  void showRegistrationClosed() => feedback.showToast(ToastId.tstX2);

  /// "Etkinlik sona erdi" (`EVT-02.ended`, devre dışı) → TST-X6.
  void showEnded() => feedback.showToast(ToastId.tstX6);

  /// Katılım satırı (`EVT-02.attendeesPreview`, yönetici olmayan) → TST-X8.
  void showAttendeeCount() {
    final count = state.event?.goingCount ?? 0;
    feedback.showToast(ToastId.tstX8, params: ToastParams(count: count));
  }

  // ───────────────────────────── hatırlatıcı ────────────────────────────────

  /// Hatırlatıcı satırı (`EVT-02.reminder`, `EVT-02.menu.reminder`): kayıt
  /// yoksa TST-X7 ve `false` (view SHT-13'ü açmaz).
  bool ensureCanSetReminder() {
    if (state.activeRsvp != null) return true;
    feedback.showToast(ToastId.tstX7);
    return false;
  }

  /// SHT-13 seçimi: tercih iyimser yazılır (`rsvpRepository.setReminder`);
  /// başarıda yerel bildirim planlanır ([option] `none` → plan iptal) →
  /// TST-37. Yazılamazsa önceki tercih geri gelir.
  Future<bool> setReminder(ReminderOption option) async {
    final uid = _uid;
    final event = state.event;
    final rsvp = state.activeRsvp;
    if (uid == null || event == null) return false;
    if (rsvp == null) {
      feedback.showToast(ToastId.tstX7);
      return false;
    }
    if (rsvp.reminder == option) return true;
    if (!ensureOnline()) return false;
    final updated = rsvp.copyWith(reminder: option);
    state = state.copyWith(rsvp: updated);
    final result = await rsvpRepository.setReminder(
      eventId: eventId,
      userId: uid,
      reminder: option,
    );
    switch (result) {
      case FirebaseSuccess():
        if (option == ReminderOption.none) {
          await localReminderService.cancel(rsvp.id);
        } else {
          await localReminderService.schedule(rsvp: updated, event: event);
        }
        feedback.showToast(
          ToastId.tst37,
          params: ToastParams(off: option == ReminderOption.none),
        );
        return true;
      case FirebaseFailure(:final error, :final detail, :final message):
        if (ref.mounted && state.rsvp == updated) {
          state = state.copyWith(rsvp: rsvp);
        }
        _showRsvpFailure(error, detail, message, 'Hatırlatıcı yazılamadı');
        return false;
    }
  }

  // ─────────────────────────── takvim · paylaşım ────────────────────────────

  /// "Yol tarifi" (`EVT-02.directions`) → harita araması, DLG-32 onayıyla.
  Future<void> openDirections(String place) async {
    if (place.trim().isEmpty) return;
    await openExternalLink(directionsUri(place));
  }

  /// SHT-15 seçimi (`EVT-02.share`, `EVT-02.menu.share`).
  Future<void> share(ShareChoice choice) async {
    final event = state.event;
    if (event == null) return;
    final url = shareUrl();
    switch (choice) {
      case ShareChoice.copyLink:
        if (await shareService.copyText(url)) {
          feedback.showToast(ToastId.tst35);
        }
      case ShareChoice.whatsapp:
        await openExternalLink(ShareLinks.whatsApp(url));
      case ShareChoice.email:
        await openExternalLink(ShareLinks.email(event.title));
      case ShareChoice.other:
        await shareService.shareText(url, subject: event.title);
    }
  }

  // ──────────────────────────────── şikayet ─────────────────────────────────

  /// SHT-10 gönderimi (`EVT-02.report`, `EVT-02.menu.report`).
  Future<bool> submitReport(ReportReasonResult report) =>
      sendReport(reporterId: _uid, report: report);

  /// DLG-12 "Şikayetin alındı" (etkinlik şikayetinde engellenecek kişi yok).
  Future<void> showReportReceived() async {
    await showReportReceivedDialog();
  }

  // ───────────────────────────── yönetim (W-27) ─────────────────────────────

  /// Yönetici "⋮" (`EVT-02.menu`): SHT-23 → `ManageEventActionsMixin`
  /// (MGT-04 ile ortak). Gezinme (düzenle, kopya, katılımcılar, yoklama,
  /// silinen taslaktan çıkış) view'a döner.
  Future<ManageEventOutcome> openManageMenu(ManageEventTexts texts) async {
    final event = state.event;
    if (event == null || !state.canManage) {
      return (next: ManageEventNext.none, eventId: eventId);
    }
    return openEventMenu(event, texts);
  }

  @override
  SessionState? get eventSession =>
      ref.mounted ? ref.read(sessionViewModelProvider) : null;

  @override
  void onEventChanged(EventModel event) => _replaceEvent(event);

  @override
  void onEventRestored(EventModel event) => _replaceEvent(event);

  @override
  void onEventListStale(String clubId) {
    if (ref.mounted) unawaited(refresh());
  }

  void _replaceEvent(EventModel event) {
    if (!ref.mounted || event.id != eventId) return;
    state = state.copyWith(event: event);
  }

  // ─────────────────────────────── DLG-16 ───────────────────────────────────

  /// İptal edilmiş etkinlik açıldı: DLG-16 bu oturumda bu etkinlik için
  /// gösterilmediyse ya da [force] (iptal bildiriminden — `?showCancelled=`)
  /// verildiyse gösterilir. `true` → "Benzer etkinlikleri gör" seçildi (view
  /// Etkinlikler sekmesine döner).
  Future<bool> showCancelledNotice({bool force = false}) async {
    final event = state.event;
    if (event == null || event.status != EventStatus.cancelled) return false;
    if (!_cancelledNoticeShown.add(eventId) && !force) return false;
    final ok = await feedback.showDialog<bool>(
      DialogId.dlg16,
      params: {
        DialogParamKeys.event: event.title,
        if (event.cancelReason case final String reason)
          DialogParamKeys.reason: reason,
      },
    );
    return ok == false;
  }

  // ──────────────────────────────── adresler ────────────────────────────────

  /// [place] için harita araması (`www.google.com/maps/search/?api=1&query=`).
  static Uri directionsUri(String place) => Uri(
    scheme: _https,
    host: _mapsHost,
    path: _mapsPath,
    queryParameters: {'api': '1', 'query': place},
  );

  static const String _https = 'https';
  static const String _mapsHost = 'www.google.com';
  static const String _mapsPath = '/maps/search/';

  // ────────────────────────────────── iç ────────────────────────────────────

  /// Etkinliği, kulübü ve kullanıcının kaydını okur.
  Future<void> _load() async {
    if (!ref.mounted || _isLoading) return;
    _isLoading = true;
    try {
      final eventResult = await eventRepository.getEvent(eventId);
      if (!ref.mounted) return;
      final EventModel event;
      switch (eventResult) {
        case FirebaseSuccess(:final data) when !data.isDeleted:
          event = data;
        case FirebaseSuccess():
          _markNotFound();
          return;
        case FirebaseFailure(error: FirestoreError.permissionDenied):
          // CD-57: üyelere özel / taslak etkinliğe derin bağlantı.
          feedback.showToast(ToastId.tstX18);
          state = state.copyWith(
            isFetching: false,
            isRefreshing: false,
            isDenied: true,
          );
          return;
        case FirebaseFailure(:final error) when _missingErrors.contains(error):
          _markNotFound();
          return;
        case FirebaseFailure(:final error, :final message):
          AppLogger.warn('Etkinlik okunamadı: ${error.name}', error: message);
          state = state.copyWith(
            isFetching: false,
            isRefreshing: false,
            isError: state.event == null,
          );
          return;
      }
      final uid = _uid;
      final (clubResult, rsvpResult) = await (
        clubRepository.getClub(event.clubId),
        uid == null
            ? Future<FirestoreResult<RsvpModel?>>.value(
                const FirebaseSuccess(null),
              )
            : rsvpRepository.getMine(eventId: eventId, userId: uid),
      ).wait;
      if (!ref.mounted) return;
      final session = ref.read(sessionViewModelProvider);
      switch (clubResult) {
        case FirebaseSuccess(:final data)
            when data.isDeleted || (data.isSuspended && !session.isSuperAdmin):
          // Prototip: kulübü yok ya da askıda → SYS-04 (`screens-events.js:40`).
          _markNotFound();
          return;
        case FirebaseFailure(:final error) when _missingErrors.contains(error):
          _markNotFound();
          return;
        case FirebaseFailure(:final error, :final message):
          AppLogger.warn(
            'Etkinlik: kulüp okunamadı: ${error.name}',
            error: message,
          );
          state = state.copyWith(
            isFetching: false,
            isRefreshing: false,
            isError: state.event == null,
          );
          return;
        case FirebaseSuccess():
          break;
      }
      // Kayıt okunamazsa eldeki kalır (ilk açılışta "katılmadı" görünür).
      var rsvp = state.rsvp;
      switch (rsvpResult) {
        case FirebaseSuccess(:final data):
          rsvp = data;
        case FirebaseFailure(:final error):
          AppLogger.warn('Etkinlik: katılım kaydı okunamadı: ${error.name}');
      }
      state = state.copyWith(
        event: event,
        club: clubResult.dataOrNull,
        rsvp: rsvp,
        clearRsvp: rsvp == null,
        access: session.accessTo(event.clubId),
        isFetching: false,
        isRefreshing: false,
        isError: false,
        isNotFound: false,
      );
    } finally {
      _isLoading = false;
    }
  }

  void _markNotFound() {
    state = state.copyWith(
      isFetching: false,
      isRefreshing: false,
      isNotFound: true,
    );
  }

  /// [event] sayaçlarının [status] kaydı için [delta] kadar değişmiş kopyası
  /// (sunucudan okunamadığında yerel karşılık).
  static EventModel _counted(EventModel event, RsvpStatus status, int delta) =>
      switch (status) {
        RsvpStatus.going || RsvpStatus.attended => event.copyWith(
          goingCount: math.max(0, event.goingCount + delta),
        ),
        RsvpStatus.waitlist => event.copyWith(
          waitlistCount: math.max(0, event.waitlistCount + delta),
        ),
        RsvpStatus.cancelled => event,
      };

  /// Katılım yazımının bildirimi: kayıt kapalı TST-X2 · bitti TST-X6 ·
  /// kayıt yok TST-X7 · ağ TST-24 · yetki TST-X18; zaten kayıtlı / yok →
  /// ekran yenilenir; kalanı günlüğe.
  void _showRsvpFailure(
    FirestoreError error,
    Object? detail,
    String? message,
    String what,
  ) {
    final rule =
        error == FirestoreError.ruleViolation &&
            detail is FirestoreFailureDetail
        ? detail.code
        : null;
    switch (rule) {
      case FirestoreRuleCode.registrationClosed:
        feedback.showToast(ToastId.tstX2);
        unawaited(refresh());
        return;
      case FirestoreRuleCode.eventEnded:
        feedback.showToast(ToastId.tstX6);
        unawaited(refresh());
        return;
      case FirestoreRuleCode.notMember:
        feedback.showToast(ToastId.tstX7);
        unawaited(refresh());
        return;
      case _:
        break;
    }
    if (showWriteFailureToast(error)) return;
    AppLogger.warn('$what: ${error.name}', error: message);
    if (error == FirestoreError.conflict ||
        error == FirestoreError.notFound ||
        error == FirestoreError.failedPrecondition) {
      unawaited(refresh());
    }
  }
}
