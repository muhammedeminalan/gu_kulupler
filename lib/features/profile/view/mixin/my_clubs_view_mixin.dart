import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/profile/provider/my_clubs_state.dart';
import 'package:gu_kulupler/features/profile/provider/my_clubs_view_model.dart';
import 'package:gu_kulupler/features/profile/view/my_clubs_view.dart';
import 'package:gu_kulupler/features/profile/view/widget/my_club_menu.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';

/// PRF-03 davranışı: açılış sekmesi (`?tab=`), sekmeler, satır menüsü ve
/// gezinme.
///
/// * Gezinme `go` ile (guard'lı rotalar; sekme değiştirir — Q-20 (A)):
///   satır → aktif / ayrılınmış / iptal edilmiş üyelikte CLB-03, bekleyen /
///   reddedilen / çıkarılan başvuruda CLB-05 (prototip `open`,
///   `screens-profile.js:43`); "Etkinlikleri keşfet" → CLB-01 (prototip
///   `switchTab('clubs')`); geri önceki sayfa (yığın yoksa PRF-01).
/// * Dialog ve toast'lar ViewModel'dedir; menü (`PRF-03.menu.<id>`) burada
///   açılır, seçilen öğe ViewModel'e iletilir.
mixin MyClubsViewMixin on ConsumerState<MyClubsView> {
  /// Listenin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  /// Ekranın ViewModel'i.
  MyClubsViewModel get viewModel => ref.read(myClubsViewModelProvider.notifier);

  @override
  void initState() {
    super.initState();
    _applyRouteTab();
  }

  @override
  void didUpdateWidget(MyClubsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != oldWidget.tab) _applyRouteTab();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  /// Geri (`PRF-03.back`): önceki sayfa; yığın yoksa PRF-01.
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      const ProfileRoute().go(context);
    }
  }

  /// Sekme (`PRF-03.tab.<id>`): liste başa döner.
  void selectTab(MyClubsTab tab) {
    if (scrollController.hasClients) scrollController.jumpTo(0);
    viewModel.setTab(tab);
  }

  /// "Yeniden dene" (`PRF-03.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Çek-yenile.
  Future<void> refresh() => viewModel.refresh();

  /// Satır (`PRF-03.row.<clubId>`, menü "Aç").
  void openClub(MembershipModel membership) {
    if (!mounted) return;
    final clubId = membership.clubId;
    switch (membership.status) {
      case MembershipStatus.pending ||
          MembershipStatus.rejected ||
          MembershipStatus.removed:
        ClubApplicationRoute(clubId: clubId).go(context);
      case MembershipStatus.active ||
          MembershipStatus.left ||
          MembershipStatus.cancelled:
        ClubDetailRoute(clubId: clubId).go(context);
    }
  }

  /// "Diğer" (`PRF-03.menu.<clubId>`): açılır menü → seçilen eylem.
  Future<void> openMenu(MyClubEntry entry) async {
    final (membership, _) = entry;
    final action = await ref
        .read(feedbackServiceProvider)
        .showMenu<MyClubMenuAction>(
          scrimKey: MyClubMenu.scrimKey,
          items: MyClubMenu.items(context.l10n, membership),
        );
    if (action == null || !mounted) return;
    final clubId = membership.clubId;
    switch (action) {
      case MyClubMenuAction.open:
        openClub(membership);
      case MyClubMenuAction.leave:
        final outcome = await viewModel.leave(clubId);
        if (!mounted || outcome != MyClubLeaveOutcome.transferRequested) {
          return;
        }
        // DLG-09 "Başkanlığı devret" → SHT-25 → DLG-21 (W-14).
        await viewModel.transferPresidencyForLeave(clubId);
      case MyClubMenuAction.cancel:
        unawaited(viewModel.cancelApplication(clubId));
      case MyClubMenuAction.reapply:
        final formats = AppDateFormats(
          Localizations.localeOf(context),
          ref.read(appClockProvider),
        );
        if (viewModel.reapply(clubId, formatDate: formats.date)) {
          ClubApplicationRoute(clubId: clubId).go(context);
        }
    }
  }

  /// "Etkinlikleri keşfet" (`PRF-03.discover`) → CLB-01.
  void discover() {
    if (!mounted) return;
    const ClubsRoute().go(context);
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
