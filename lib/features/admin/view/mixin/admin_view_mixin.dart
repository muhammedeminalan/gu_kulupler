import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/features/admin/provider/admin_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_view_model.dart';
import 'package:gu_kulupler/features/admin/view/admin_view.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_segment_bar.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

/// ADM-01 davranışı: başa kaydırma, dönem çipi, çek-yenile ve gezinme.
///
/// * Etkin sekmeye yeniden dokunma (`scrollTopRequestProvider`, PLAN §13.2)
///   içeriği başa kaydırır.
/// * En aktif kulüp satırı CLB-03'ü `go` ile açar: Kulüpler sekmesinin
///   yığınında kurulur, Admin yığını değişmez (Q-20 = A, navigation.md §4).
/// * Admin alt ekranları (prototip `nav.replace`) `go` ile açılır: Kulüpler
///   / askıdaki kulüpler → ADM-02 (`?tab=suspended`; T-39, W-45). Şikayetler
///   → ADM-04 (T-40, W-46), kullanıcılar → ADM-05 (T-41, W-47) sahip
///   task'larında bağlanır.
mixin AdminViewMixin on ConsumerState<AdminView> {
  /// İçeriğin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  ProviderSubscription<int>? _scrollTopSubscription;

  /// Ekranın ViewModel'i.
  AdminViewModel get viewModel => ref.read(adminViewModelProvider.notifier);

  Duration get _scrollDuration =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : GuMotion.base;

  @override
  void initState() {
    super.initState();
    _scrollTopSubscription = ref.listenManual(
      scrollTopRequestProvider(GuTab.admin),
      (_, _) => scrollToTop(),
    );
  }

  @override
  void dispose() {
    _scrollTopSubscription?.close();
    scrollController.dispose();
    super.dispose();
  }

  /// İçeriği başa kaydırır.
  void scrollToTop() {
    if (!scrollController.hasClients) return;
    unawaited(
      scrollController.animateTo(
        0,
        duration: _scrollDuration,
        curve: GuMotion.easeStandard,
      ),
    );
  }

  /// Çek-yenile.
  Future<void> refresh() => viewModel.refresh();

  /// Hata görünümündeki "Yeniden dene" (`ADM-01.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Dönem çipi (`ADM-01.range.<id>`).
  void selectRange(AdminRange range) => unawaited(viewModel.selectRange(range));

  /// Bölmeli geçiş (`ADM-01.seg.<hedef>`); kendi seçeneği etkisizdir.
  void openSegment(String screenId) {
    switch (screenId) {
      case AdminSegmentBar.clubs:
        openClubs();
      case AdminSegmentBar.reports:
        openReports();
      case AdminSegmentBar.users:
        openUsers();
    }
  }

  /// "Aktif kulüp" (`ADM-01.kpi.clubs`) / "Kulüpler" bölmesi → ADM-02.
  void openClubs() => const AdminClubsRoute().go(context);

  /// "Askıdaki kulüp" (`ADM-01.kpi.suspended`, `ADM-01.task.suspended`) →
  /// ADM-02 askıdakiler sekmesi.
  void openSuspendedClubs() =>
      const AdminClubsRoute(tab: AdminClubsTab.suspended).go(context);

  /// "Açık şikayet" (`ADM-01.kpi.reports`, `ADM-01.task.reports`) /
  /// "Şikayetler" bölmesi → ADM-04.
  void openReports() => const AdminReportsRoute().go(context);

  /// "Toplam kullanıcı" (`ADM-01.kpi.users`) / "Kullanıcılar" bölmesi →
  /// ADM-05.
  void openUsers() => const AdminUsersRoute().go(context);

  /// En aktif kulüp satırı (`ADM-01.topClub.<id>`) → CLB-03.
  void openClub(String clubId) => ClubDetailRoute(clubId: clubId).go(context);
}
