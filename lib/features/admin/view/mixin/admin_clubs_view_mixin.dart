import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/admin/provider/admin_clubs_view_model.dart';
import 'package:gu_kulupler/features/admin/view/admin_clubs_view.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_club_menu.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_segment_bar.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/president_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialogs/suspend_club_dialog.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';

/// ADM-02 davranışı: açılış sekmesi (`?tab=`), sekme, arama, çek-yenile,
/// satır menüsü ve gezinme.
///
/// * Gezinme `go` ile (guard'lı rotalar): satır ve menü "Görüntüle" → CLB-03
///   (Kulüpler yığını; Q-20 — ADM-01 en aktif kulüp emsali); "Düzenle" →
///   ADM-03 düzenleme; "Kulüp oluştur" → ADM-03; bölmeli geçiş "Genel" →
///   ADM-01 (prototip `nav.replace`). Şikayetler / Kullanıcılar sahip
///   task'larında bağlanır (T-40 W-46, T-41 W-47).
/// * "Askıya al" / "Etkinleştir" → DLG-28 → ViewModel (TST-50); "Başkanı
///   değiştir" → SHT-25 atama kipi → ViewModel (TST-49).
mixin AdminClubsViewMixin on ConsumerState<AdminClubsView> {
  /// Listenin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  /// Ekranın ViewModel'i.
  AdminClubsViewModel get viewModel =>
      ref.read(adminClubsViewModelProvider.notifier);

  @override
  void initState() {
    super.initState();
    _applyRouteTab();
  }

  @override
  void didUpdateWidget(AdminClubsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != oldWidget.tab) _applyRouteTab();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  /// Bölmeli geçiş (`ADM-02.seg.<hedef>`); kendi seçeneği etkisizdir.
  void openSegment(String screenId) {
    switch (screenId) {
      case AdminSegmentBar.overview:
        const AdminRoute().go(context);
      case AdminSegmentBar.reports:
        openReports();
      case AdminSegmentBar.users:
        openUsers();
    }
  }

  /// "Şikayetler" bölmesi → ADM-04.
  void openReports() => const AdminReportsRoute().go(context);

  /// "Kullanıcılar" bölmesi → ADM-05.
  void openUsers() => const AdminUsersRoute().go(context);

  /// Sekme (`ADM-02.tab.<name>`): liste başa döner.
  void selectTab(String name) {
    if (scrollController.hasClients) scrollController.jumpTo(0);
    viewModel.setTab(AdminClubsTab.values.byName(name));
  }

  /// Arama (`ADM-02.search`).
  void search(String query) => viewModel.setQuery(query);

  /// "Yeniden dene" (`ADM-02.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Çek-yenile.
  Future<void> refresh() => viewModel.refresh();

  /// Satır (`ADM-02.row.<id>`) / menü "Görüntüle" → CLB-03.
  void openClub(String clubId) {
    if (!mounted) return;
    ClubDetailRoute(clubId: clubId).go(context);
  }

  /// "Kulüp oluştur" (`ADM-02.create`) → ADM-03.
  void createClub() => const AdminClubFormRoute().go(context);

  /// "Diğer" (`ADM-02.menu.<id>`): açılır menü → seçilen eylem.
  Future<void> openMenu(ClubModel club) async {
    final action = await ref
        .read(feedbackServiceProvider)
        .showMenu<AdminClubMenuAction>(
          scrimKey: AdminClubMenu.scrimKey,
          items: AdminClubMenu.items(context.l10n, club),
        );
    if (action == null || !mounted) return;
    switch (action) {
      case AdminClubMenuAction.view:
        openClub(club.id);
      case AdminClubMenuAction.edit:
        AdminClubEditRoute(clubId: club.id).go(context);
      case AdminClubMenuAction.president:
        await changePresident(club);
      case AdminClubMenuAction.suspend:
        await toggleSuspend(club);
    }
  }

  /// "Askıya al" / "Etkinleştir" → DLG-28 → yazım (TST-50).
  Future<void> toggleSuspend(ClubModel club) async {
    final suspending = !club.isSuspended;
    final reason = await SuspendClubDialog.show(
      ref.read(feedbackServiceProvider),
      clubName: club.name,
      suspending: suspending,
    );
    if (reason == null || !mounted) return;
    if (suspending) {
      unawaited(viewModel.suspend(club.id, reason));
    } else {
      unawaited(viewModel.activate(club.id));
    }
  }

  /// "Başkanı değiştir" → SHT-25 (atama kipi) → yazım (TST-49).
  Future<void> changePresident(ClubModel club) async {
    final users = await viewModel.presidentCandidates(club.id);
    if (users == null || !mounted) return;
    final userId = await ref
        .read(feedbackServiceProvider)
        .showSheet<String>(
          SheetId.sht25,
          builder: (_) => PresidentPickerSheet(
            mode: PresidentPickerMode.assign,
            candidates: [
              for (final user in users) PresidentCandidate.fromUser(user),
            ],
          ),
        );
    if (userId == null || !mounted) return;
    for (final user in users) {
      if (user.uid == userId) {
        unawaited(viewModel.assignPresident(club.id, user));
        return;
      }
    }
  }

  /// Rotadaki `?tab=` sekmesini ilk kareden sonra uygular (yapım sırasında
  /// sağlayıcı değiştirilmez).
  void _applyRouteTab() {
    final tab = widget.tab;
    if (tab == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) viewModel.setTab(tab);
    });
  }
}
