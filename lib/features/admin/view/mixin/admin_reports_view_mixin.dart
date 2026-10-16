import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/admin/provider/admin_reports_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_reports_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/report_target_preview.dart';
import 'package:gu_kulupler/features/admin/view/admin_reports_view.dart';
import 'package:gu_kulupler/features/admin/view/widget/report_detail_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/dialogs/suspend_club_dialog.dart';
import 'package:gu_kulupler/product/feedback/dialogs/suspend_user_dialog.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

/// ADM-04 bölmesinin davranışı: açılış sekmesi (`?reportsTab=`) ve grubu
/// (`?reportId=` → `AppDurations.postNavigationSheetDelay` sonra SHT-26),
/// sekme, süzgeç, çek-yenile, başa kaydırma, sayfalama, SHT-26 ve çözüm
/// akışları.
///
/// * Bölmeli geçiş admin kökündedir (`AdminViewMixin`); etkin sekmeye
///   yeniden dokunma (`scrollTopRequestProvider`) bölme sahnedeyse
///   ([AdminReportsView.active]) listeyi başa kaydırır.
/// * Satır → SHT-26 ([openGroup]); sheet eylemi ([onSheetAction]) →
///   gerekirse onay (DLG-29 içerik kaldır · DLG-30 kullanıcı askısı ·
///   DLG-28 kulüp askısı) → ViewModel yazımı; sheet yazım sürerken açık
///   kalır (düğme `loading`), başarıda kapanır (prototip `closeAllSheets`),
///   hatada açık kalır.
mixin AdminReportsViewMixin on ConsumerState<AdminReportsView> {
  /// Listenin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  Timer? _reportTimer;

  ProviderSubscription<AdminReportsState>? _stateSubscription;

  ProviderSubscription<int>? _scrollTopSubscription;

  /// Ekranın ViewModel'i.
  AdminReportsViewModel get viewModel =>
      ref.read(adminReportsViewModelProvider.notifier);

  AdminReportsState get _state => ref.read(adminReportsViewModelProvider);

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_loadMoreIfNearEnd);
    _stateSubscription = ref.listenManual(adminReportsViewModelProvider, (
      previous,
      next,
    ) {
      // Görünen liste değişti (sayfa geldi, sekme, süzgeç): ekran hâlâ
      // dolmuyorsa sıradaki sayfa istenir.
      final changed =
          previous == null ||
          previous.tab != next.tab ||
          previous.typeFilter != next.typeFilter ||
          previous.cursors != next.cursors;
      if (!changed || !next.hasMore) return;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadMoreIfNearEnd(),
      );
    });
    _scrollTopSubscription = ref.listenManual(
      scrollTopRequestProvider(GuTab.admin),
      (_, _) {
        if (widget.active) scrollToTop();
      },
    );
    _applyRouteTab();
    _scheduleReport();
  }

  @override
  void didUpdateWidget(AdminReportsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != oldWidget.tab) _applyRouteTab();
    if (widget.reportId != oldWidget.reportId) _scheduleReport();
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
    _reportTimer?.cancel();
    _stateSubscription?.close();
    _scrollTopSubscription?.close();
    scrollController.dispose();
    super.dispose();
  }

  /// Listeyi başa kaydırır (sekmeye yeniden dokunma).
  void scrollToTop() {
    if (!scrollController.hasClients) return;
    unawaited(
      scrollController.animateTo(
        0,
        duration: context.gu.duration(GuMotion.base),
        curve: GuMotion.easeStandard,
      ),
    );
  }

  /// Sekme (`ADM-04.tab.<name>`): liste başa döner.
  void selectTab(String name) {
    if (scrollController.hasClients) scrollController.jumpTo(0);
    viewModel.setTab(AdminReportsTab.values.byName(name));
  }

  /// Hedef türü süzgeci (`ADM-04.filter.<name>`).
  void selectFilter(ReportTargetFilter filter) =>
      viewModel.setTypeFilter(filter);

  /// "Yeniden dene" (`ADM-04.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Çek-yenile.
  Future<void> refresh() => viewModel.refresh();

  /// Satır (`ADM-04.row.<key>`) ve `?reportId=` açılışı: SHT-26 şikayet
  /// detayı; eylem seçimi [onSheetAction]'a gider.
  Future<void> openGroup(String key) async {
    final vm = viewModel;
    final group = await vm.openGroup(key);
    if (group == null || !mounted) return;
    var open = true;
    BuildContext? sheetContext;
    void close() {
      final sheet = sheetContext;
      if (open && sheet != null && sheet.mounted) sheet.pop();
    }

    await _feedback.showSheet<void>(
      SheetId.sht26,
      builder: (context) {
        sheetContext = context;
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(adminReportsViewModelProvider);
            final current = state.openGroupKey == key;
            return ReportDetailSheet(
              group: current ? state.detailGroup ?? group : group,
              preview: current ? state.targetPreview : null,
              reporters: state.reporters,
              pendingAction: state.pendingActions[key],
              onAction: (action) =>
                  unawaited(onSheetAction(key, action, close: close)),
            );
          },
        );
      },
    );
    open = false;
    if (mounted) vm.closeGroup(key);
  }

  /// SHT-26 eylemi: onay (gerekirse) → yazım; başarıda [close] (sheet).
  Future<void> onSheetAction(
    String key,
    ReportDetailAction action, {
    VoidCallback? close,
  }) async {
    final vm = viewModel;
    final preview = _state.targetPreview;
    final bool done;
    switch (action) {
      case ReportDetailAction.dismiss:
        done = await vm.dismiss(key);
      case ReportDetailAction.removeContent:
        final confirmed = await _feedback.showDialog<bool>(DialogId.dlg29);
        if (confirmed != true || !mounted) return;
        done = await vm.removeContent(key);
      case ReportDetailAction.suspendUser:
        final userId = preview?.suspendableUserId;
        if (userId == null) return;
        final reason = await SuspendUserDialog.show(
          _feedback,
          userName: _userName(preview),
          suspending: true,
        );
        if (reason == null || !mounted) return;
        done = await vm.suspendUser(key, userId: userId, reason: reason);
      case ReportDetailAction.suspendClub:
        final reason = await SuspendClubDialog.show(
          _feedback,
          clubName: preview?.club?.name ?? '',
          suspending: true,
        );
        if (reason == null || !mounted) return;
        done = await vm.suspendClub(key, reason: reason);
    }
    if (done && mounted) close?.call();
  }

  /// DLG-30 başlığındaki ad: gönderi / yorum yazarı ya da kullanıcı hedefi.
  String _userName(ReportTargetPreview? preview) {
    final user = preview?.user ?? preview?.author;
    if (user == null) return '';
    return user.isDeleted ? context.l10n.commonDeletedUser : user.name;
  }

  void _loadMoreIfNearEnd() {
    if (!mounted || !scrollController.hasClients || !_state.hasMore) return;
    final position = scrollController.position;
    if (position.extentAfter < position.viewportDimension) {
      unawaited(viewModel.loadMore());
    }
  }

  /// Rotadaki `?reportsTab=` sekmesini ilk kareden sonra uygular (yapım
  /// sırasında sağlayıcı değiştirilmez); boş değer hâli değiştirmez.
  void _applyRouteTab() {
    final tab = widget.tab;
    if (tab == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) viewModel.setTab(tab);
    });
  }

  /// `?reportId=` (bildirim `new_report`): geçiş bitince grubun SHT-26'sı.
  void _scheduleReport() {
    _reportTimer?.cancel();
    final key = widget.reportId;
    if (key == null || key.isEmpty) return;
    _reportTimer = Timer(
      AppDurations.postNavigationSheetDelay,
      () => unawaited(openGroup(key)),
    );
  }
}
