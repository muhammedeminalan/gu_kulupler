// `LocalReminderService` fake'i (PLAN §15.6, §16.3; CD-09): bildirim
// planlamaz; gerçek kuralla (yalnızca `going`, `none` ⇒ iptal, geçmiş an
// planlanmaz, rsvp başına tek plan) bellekte kaydeder.
//
//   final reminders = FakeLocalReminderService(clock);
//   await viewModel.setReminder(ReminderOption.oneHour);
//   final id = LocalReminderService.notificationId(rsvp.id);
//   expect(reminders.scheduled[id]?.triggerAtUtc, startsAt - 1 sa);
//   await viewModel.cancelRsvp();
//   expect(reminders.cancelled, [rsvp.id]);
//
//   // Uygulama açıkken hatırlatıcıya dokunma (`tappedPayloads`):
//   reminders.tap(LocalReminderService.payloadFor('e01'));
import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';

import 'fake_base.dart';

/// Planlanmış tek hatırlatıcı (fake kaydı; `FakeLocalReminderService.scheduled`).
typedef ScheduledReminder = ({
  String rsvpId,
  String eventId,
  DateTime triggerAtUtc,
  String payload,
});

final class FakeLocalReminderService extends FakeBase
    implements LocalReminderService {
  /// Saat verilirse geçmiş tetik anı planlanmaz (gerçek servis gibi).
  FakeLocalReminderService([this._clock]);

  final AppClock? _clock;

  /// Bildirim kimliği → plan (`LocalReminderService.notificationId`).
  final Map<int, ScheduledReminder> scheduled = <int, ScheduledReminder>{};

  /// İptal istenen rsvp kimlikleri, sırasıyla (`cancel`; `schedule` içindeki
  /// örtük iptaller dahil değildir).
  final List<String> cancelled = <String>[];

  /// `ensureChannel` en az bir kez çağrıldı mı?
  bool channelEnsured = false;

  /// `ensureChannel` ile verilen son yerelleştirme.
  AppLocalizations? l10n;

  /// `rescheduleAll` çağrı sayısı.
  int rescheduleCalls = 0;

  /// Son `rescheduleAll` çağrısına verilen etkinlik haritası (T-44 · D2-06).
  Map<String, EventModel> lastEvents = const {};

  /// `cancelAll` çağrı sayısı.
  int cancelAllCalls = 0;

  /// `initialLaunchPayload` sonucu (soğuk açılış senaryosu).
  String? launchPayload;

  final StreamController<String> _taps = StreamController<String>.broadcast(
    sync: true,
  );

  /// Uygulama açıkken [payload] yüklü hatırlatıcıya dokunma benzetimi
  /// (`tappedPayloads` dinleyicilerine iletilir).
  void tap(String payload) => _taps.add(payload);

  /// `tappedPayloads` akışının dinleyicisi var mı?
  bool get hasTapListener => _taps.hasListener;

  /// [rsvpId] için plan; yoksa `null`.
  ScheduledReminder? scheduledFor(String rsvpId) =>
      scheduled[LocalReminderService.notificationId(rsvpId)];

  @override
  Future<void> ensureChannel(AppLocalizations l10n) async {
    record('ensureChannel');
    _throwPending();
    channelEnsured = true;
    this.l10n = l10n;
  }

  @override
  Future<void> schedule({
    required RsvpModel rsvp,
    required EventModel event,
  }) async {
    record('schedule', [rsvp.id, event.id, rsvp.reminder]);
    _throwPending();
    final id = LocalReminderService.notificationId(rsvp.id);
    scheduled.remove(id);
    if (rsvp.status != RsvpStatus.going) return;
    final trigger = LocalReminderService.triggerAtUtc(rsvp: rsvp, event: event);
    if (trigger == null) return;
    final clock = _clock;
    if (clock != null && !trigger.isAfter(clock.nowUtc())) return;
    scheduled[id] = (
      rsvpId: rsvp.id,
      eventId: event.id,
      triggerAtUtc: trigger,
      payload: LocalReminderService.payloadFor(event.id),
    );
  }

  @override
  Future<void> cancel(String rsvpId) async {
    record('cancel', [rsvpId]);
    _throwPending();
    cancelled.add(rsvpId);
    scheduled.remove(LocalReminderService.notificationId(rsvpId));
  }

  @override
  Future<void> cancelAll() async {
    record('cancelAll');
    _throwPending();
    cancelAllCalls++;
    scheduled.clear();
  }

  @override
  Future<void> rescheduleAll({
    required List<RsvpModel> myGoing,
    required Map<String, EventModel> events,
    required UserSettingsModel settings,
  }) async {
    record('rescheduleAll', [myGoing.length]);
    _throwPending();
    rescheduleCalls++;
    lastEvents = Map.unmodifiable(events);
  }

  @override
  Stream<String> get tappedPayloads => _taps.stream;

  @override
  Future<String?> initialLaunchPayload() async {
    record('initialLaunchPayload');
    return launchPayload;
  }

  /// Bekleyen hata (`failNext`) varsa onu fırlatır (platform hatası
  /// benzetimi; ViewModel'in yakalaması sınanır).
  void _throwPending() {
    if (takeFailure() case final error?) {
      Error.throwWithStackTrace(error, StackTrace.current);
    }
  }

  @override
  void resetFake() {
    super.resetFake();
    scheduled.clear();
    cancelled.clear();
    channelEnsured = false;
    l10n = null;
    rescheduleCalls = 0;
    cancelAllCalls = 0;
    launchPayload = null;
  }
}
