import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/management/provider/attendance_state.dart';
import 'package:gu_kulupler/features/management/provider/attendance_view_model.dart';
import 'package:gu_kulupler/features/management/view/attendance_view.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

/// MGT-06 "⋮" menüsünde seçilen öğe.
enum AttendanceMenuAction {
  /// "Dışa aktar (CSV)" (`MGT-06.export`).
  export,

  /// "Tüm kayıtlıları katıldı yap" (`MGT-06.markAll`).
  markAll,

  /// "Kayıtları aç / kapat" (`MGT-06.toggleRegistration`).
  toggleRegistration,
}

/// MGT-06 davranışı: geri, etkinlik değiştir (açılır menü →
/// `AttendanceRoute`), QR tarayıcı (MGT-07), "⋮" menüsü (dışa aktar, tümünü
/// katıldı yap, kayıt aç / kapa), özet çipleri, arama, "Katıldı" anahtarı ve
/// "Kayıtlıya al". Yazımlar ViewModel'dedir; view yalnızca gezinir.
mixin AttendanceViewMixin on ConsumerState<AttendanceView> {
  /// Açılır menülerin saydam scrim'i (`MGT-06.scrim`, `ui.js:191`).
  static final Key scrimKey = GuKey.action('MGT-06.scrim');

  /// "Dışa aktar" menü öğesinin anahtarı (`MGT-06.export`).
  static final Key exportKey = GuKey.action('MGT-06.export');

  /// "Tüm kayıtlıları katıldı yap" menü öğesinin anahtarı (`MGT-06.markAll`).
  static final Key markAllKey = GuKey.action('MGT-06.markAll');

  /// "Kayıtları aç / kapat" menü öğesinin anahtarı
  /// (`MGT-06.toggleRegistration`).
  static final Key toggleRegistrationKey = GuKey.action(
    'MGT-06.toggleRegistration',
  );

  /// Etkinlik değiştir menüsünde [eventId] satırının anahtarı
  /// (`MGT-06.switchEvent.<id>`).
  static Key switchEventKeyOf(String eventId) =>
      GuKey.action('MGT-06.switchEvent.$eventId');

  /// [summary] çipinin anahtarı (`MGT-06.summary.<id>`).
  static Key summaryKeyOf(AttendanceSummaryFilter summary) => switch (summary) {
    AttendanceSummaryFilter.all => GuKey.action('MGT-06.summary.all'),
    AttendanceSummaryFilter.attended => GuKey.action(
      'MGT-06.summary.attended',
    ),
    AttendanceSummaryFilter.absent => GuKey.action('MGT-06.summary.absent'),
    AttendanceSummaryFilter.waitlist => GuKey.action(
      'MGT-06.summary.waitlist',
    ),
  };

  /// [summary] çipinin adı (sayıdan önce).
  static String summaryLabel(
    AppLocalizations l10n,
    AttendanceSummaryFilter summary,
  ) => switch (summary) {
    AttendanceSummaryFilter.all => l10n.attendanceRegistered,
    AttendanceSummaryFilter.attended => l10n.statusAttended,
    AttendanceSummaryFilter.absent => l10n.attendanceAbsent,
    AttendanceSummaryFilter.waitlist => l10n.statusWaitlist,
  };

  /// Arama alanının denetleyicisi.
  final TextEditingController searchController = TextEditingController();

  /// Ekranın ViewModel'i.
  AttendanceViewModel get viewModel => ref.read(
    attendanceViewModelProvider(widget.clubId, widget.eventId).notifier,
  );

  AttendanceState get _state =>
      ref.read(attendanceViewModelProvider(widget.clubId, widget.eventId));

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /// Geri (`MGT-06.back`): önceki sayfa; yığın yoksa etkinlik yönetimi
  /// (MGT-04).
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      ManageEventsRoute(clubId: widget.clubId).go(context);
    }
  }

  /// "Yeniden dene" (`MGT-06.retry`).
  Future<void> retry() => viewModel.fetch();

  /// QR tarayıcı (`MGT-06.scan`) → MGT-07.
  void openScan() =>
      ScanRoute(clubId: widget.clubId, eventId: widget.eventId).go(context);

  /// Etkinlik değiştir (`MGT-06.switchEvent`): kulübün etkinlikleri açılır
  /// menüde (seçili olan işaretli) → seçilenin katılımcıları.
  Future<void> switchEvent() async {
    final events = await viewModel.switchableEvents();
    if (!mounted || events.isEmpty) return;
    final eventId = await _feedback.showMenu<String>(
      scrimKey: scrimKey,
      items: [
        for (final e in events)
          GuPopMenuItem(
            key: switchEventKeyOf(e.id),
            label: e.title,
            selected: e.id == widget.eventId,
            value: e.id,
          ),
      ],
    );
    if (eventId == null || eventId == widget.eventId || !mounted) return;
    AttendanceRoute(clubId: widget.clubId, eventId: eventId).go(context);
  }

  /// "⋮" (`MGT-06.menu`): dışa aktar · tümünü katıldı yap · kayıt aç / kapa
  /// (yazanlar danışmanda devre dışı — prototip `disabled=${readOnly}`).
  Future<void> openMenu() async {
    final l10n = context.l10n;
    final state = _state;
    final open = state.event?.registrationOpen ?? true;
    final action = await _feedback.showMenu<AttendanceMenuAction>(
      scrimKey: scrimKey,
      items: [
        GuPopMenuItem(
          key: exportKey,
          label: l10n.mgtMembersExport,
          icon: GuIcons.download,
          value: AttendanceMenuAction.export,
        ),
        GuPopMenuItem(
          key: markAllKey,
          label: l10n.attendanceMarkAll,
          icon: GuIcons.checkCheck,
          disabled: !state.canMark,
          value: AttendanceMenuAction.markAll,
        ),
        GuPopMenuItem(
          key: toggleRegistrationKey,
          label: open ? l10n.attendanceCloseReg : l10n.attendanceOpenReg,
          icon: open ? GuIcons.lock : GuIcons.lockOpen,
          disabled: state.isReadOnly,
          value: AttendanceMenuAction.toggleRegistration,
        ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case AttendanceMenuAction.export:
        await exportCsv();
      case AttendanceMenuAction.markAll:
        await viewModel.markAllAttended(
          allLabel: context.l10n.attendanceAllRegistered,
        );
      case AttendanceMenuAction.toggleRegistration:
        await viewModel.toggleRegistration();
    }
  }

  /// CSV dışa aktarma → paylaşım → TST-29 (danışman → TST-26).
  Future<bool> exportCsv() {
    final l10n = context.l10n;
    return viewModel.exportCsv(
      (status) => switch (status) {
        RsvpStatus.attended => l10n.statusAttended,
        RsvpStatus.waitlist => l10n.statusWaitlist,
        RsvpStatus.going ||
        RsvpStatus.cancelled => l10n.attendanceRegisteredOne,
      },
    );
  }

  /// Özet çipi (`MGT-06.summary.<id>`).
  void selectSummary(AttendanceSummaryFilter summary) =>
      viewModel.setSummary(summary);

  /// Arama alanı (`MGT-06.search`).
  void onQueryChanged(String query) => viewModel.setQuery(query);

  /// "Katıldı" anahtarı (`MGT-06.attended.<id>`).
  void toggleAttended(String userId, bool value) =>
      unawaited(viewModel.setAttended(userId, value));

  /// "Kayıtlıya al" (`MGT-06.promote.<id>`).
  void promote(String userId) => unawaited(viewModel.promote(userId));

  /// Danışman bakışında devre dışı yazma eylemi → TST-26.
  void onReadOnly() => viewModel.onReadOnlyTap();

  /// Kontenjan dolu iken "Kayıtlıya al" → TST-X14 (danışmanda TST-26).
  void onPromoteDisabled() =>
      _state.isReadOnly ? onReadOnly() : viewModel.onCapacityFullTap();
}
