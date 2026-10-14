import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/management/provider/manage_events_view_model.dart';
import 'package:gu_kulupler/features/management/view/manage_events_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/mixin/manage_event_actions_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';

/// MGT-04 davranışı: sekmeler (açılış `?tab=`), satır → EVT-02, "⋮" →
/// SHT-23 (yazım ViewModel'deki ortak `ManageEventActionsMixin`'de; view
/// yalnızca gezinir), "Etkinlik" FAB → MGT-05, kulüp değiştir ve geri.
mixin ManageEventsViewMixin on ConsumerState<ManageEventsView> {
  /// Ekranın ViewModel'i.
  ManageEventsViewModel get viewModel =>
      ref.read(manageEventsViewModelProvider(widget.clubId).notifier);

  @override
  void initState() {
    super.initState();
    _applyRouteTab();
  }

  @override
  void didUpdateWidget(covariant ManageEventsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) _applyRouteTab();
  }

  /// Rotadaki sekme (`?tab=`) ilk karenin ardından seçilir: sağlayıcı
  /// ağaç kurulurken değiştirilemez.
  void _applyRouteTab() {
    final tab = widget.tab;
    if (tab == null) return;
    unawaited(
      Future<void>.microtask(() {
        if (mounted) viewModel.setTab(tab);
      }),
    );
  }

  /// Geri (`MGT-04.back`): önceki sayfa; yığın yoksa panel (MGT-01).
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      ManageRoute(clubId: widget.clubId).go(context);
    }
  }

  /// Kulüp değiştir (`MGT-04.switchClub`): SHT-18 → seçilen kulübün
  /// etkinlikleri.
  Future<void> switchClub() => ref
      .read(feedbackServiceProvider)
      .showSheet<String>(
        SheetId.sht18,
        builder: (_) => ManagedClubPickerSheet(
          selectedClubId: widget.clubId,
          onSelect: _openClub,
        ),
      );

  void _openClub(String clubId) {
    if (!mounted || clubId == widget.clubId) return;
    ManageEventsRoute(clubId: clubId).go(context);
  }

  /// "Yeniden dene" (`MGT-04.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Çek-yenile.
  Future<void> refresh() => viewModel.refresh();

  /// Sekme (`MGT-04.tab.<name>`).
  void selectTab(String name) =>
      viewModel.setTab(ManageEventsTab.values.byName(name));

  /// Satır (`MGT-04.event.<id>`) → EVT-02.
  void openEvent(String eventId) =>
      EventDetailRoute(eventId: eventId).go(context);

  /// "Etkinlik" (`MGT-04.create`) → MGT-05 (danışman → TST-26).
  void createEvent() {
    if (!viewModel.ensureWritable()) return;
    EventFormRoute(clubId: widget.clubId).go(context);
  }

  /// "⋮" (`MGT-04.menu.<id>`): SHT-23 → yazan satırlar ViewModel'de;
  /// düzenle / kopya → MGT-05, katılımcılar / yoklama → MGT-06 / 07.
  Future<void> openMenu(EventModel event) async {
    final l10n = context.l10n;
    final outcome = await viewModel.openMenu(event, (
      copySuffix: l10n.eventCopySuffix,
      draftLabel: l10n.statusDraft,
    ));
    if (!mounted) return;
    switch (outcome.next) {
      case ManageEventNext.edit:
        EventEditRoute(
          clubId: widget.clubId,
          eventId: outcome.eventId,
        ).go(context);
      case ManageEventNext.attendees:
        // TODO(T-35): `AttendeesRoute(clubId:, eventId:)` (MGT-06).
        break;
      case ManageEventNext.scan:
        // TODO(T-35): `ScanRoute(clubId:, eventId:)` (MGT-07).
        break;
      case ManageEventNext.none || ManageEventNext.removed:
        break;
    }
  }
}
