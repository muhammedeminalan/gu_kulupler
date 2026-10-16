import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/features/admin/provider/admin_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_view_model.dart';
import 'package:gu_kulupler/features/admin/view/admin_overview_view.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

/// ADM-01 genel bakış bölmesinin davranışı: başa kaydırma, dönem çipi,
/// çek-yenile ve bölme / ekran açma.
///
/// * Etkin sekmeye yeniden dokunma (`scrollTopRequestProvider`, PLAN §13.2)
///   bölme sahnedeyse ([AdminOverviewView.active]) içeriği başa kaydırır.
/// * En aktif kulüp satırı CLB-03'ü `go` ile açar: Kulüpler sekmesinin
///   yığınında kurulur, Admin yığını değişmez (Q-20 = A, navigation.md §4).
/// * Göstergeler ve bekleyen işler admin kökünde bölme değiştirir
///   ([AdminOverviewView.onOpen]; kullanıcı kararı 2026-10-16): Kulüpler /
///   askıdaki kulüpler → ADM-02 (askıdakiler sekmesi; W-45), şikayetler →
///   ADM-04 (W-46), kullanıcılar → ADM-05 (W-47).
mixin AdminOverviewViewMixin on ConsumerState<AdminOverviewView> {
  /// İçeriğin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  ProviderSubscription<int>? _scrollTopSubscription;

  /// Bölmenin ViewModel'i.
  AdminViewModel get viewModel => ref.read(adminViewModelProvider.notifier);

  Duration get _scrollDuration =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : GuMotion.base;

  @override
  void initState() {
    super.initState();
    _scrollTopSubscription = ref.listenManual(
      scrollTopRequestProvider(GuTab.admin),
      (_, _) {
        if (widget.active) scrollToTop();
      },
    );
  }

  @override
  void didUpdateWidget(AdminOverviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Bölme yeniden seçildi: öteki bölmenin yazımı (SHT-26 askı / çözüm,
    // ADM-02 askı, başkan) burada bayat kalmasın — içerik kalarak yeniden
    // okunur (çek-yenile gibi; ilk seçimde ViewModel zaten okur). Yaşam
    // döngüsünde sağlayıcı değişmez: kare sonunda.
    if (widget.active && !oldWidget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) unawaited(viewModel.refresh());
      });
    }
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

  /// "Aktif kulüp" (`ADM-01.kpi.clubs`) → Kulüpler bölmesi.
  void openClubs() => widget.onOpen(AdminTab.clubs);

  /// "Askıdaki kulüp" (`ADM-01.kpi.suspended`, `ADM-01.task.suspended`) →
  /// Kulüpler bölmesi, askıdakiler sekmesi.
  void openSuspendedClubs() =>
      widget.onOpen(AdminTab.clubs, clubsTab: AdminClubsTab.suspended);

  /// "Açık şikayet" (`ADM-01.kpi.reports`, `ADM-01.task.reports`) →
  /// Şikayetler bölmesi.
  void openReports() => widget.onOpen(AdminTab.reports);

  /// "Toplam kullanıcı" (`ADM-01.kpi.users`) → Kullanıcılar bölmesi.
  void openUsers() => widget.onOpen(AdminTab.users);

  /// En aktif kulüp satırı (`ADM-01.topClub.<id>`) → CLB-03.
  void openClub(String clubId) => ClubDetailRoute(clubId: clubId).go(context);
}
