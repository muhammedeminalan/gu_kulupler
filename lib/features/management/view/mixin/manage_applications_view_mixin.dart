import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_applications_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_applications_view_model.dart';
import 'package:gu_kulupler/features/management/view/manage_applications_view.dart';
import 'package:gu_kulupler/features/management/view/widget/application_detail_sheet.dart';
import 'package:gu_kulupler/features/management/view/widget/reject_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';

/// MGT-02 davranışı: sekme, arama, sıralama, seçim kipi, satır eylemleri
/// (SHT-19 detay, SHT-20 ret nedeni), sayfalama tetikleyicisi, açılış
/// parametreleri ve gezinme.
///
/// * Açılış: [ManageApplicationsView.tab] ilk sekmeyi seçer;
///   [ManageApplicationsView.applicantId] verilmişse
///   `AppDurations.postNavigationSheetDelay` sonra o başvuranın SHT-19'u
///   açılır (W-28; başvuru yoksa "Bu başvuru artık yok").
/// * SHT-19 / SHT-20 yalnızca sorar (`pop` değeri); yazımı ViewModel yapar.
/// * Sayfalama: liste sonuna bir ekran boyundan az kalınca sonraki sayfa
///   (CLB-06 ile aynı kalıp).
mixin ManageApplicationsViewMixin on ConsumerState<ManageApplicationsView> {
  /// Listenin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  /// Arama alanının denetleyicisi.
  final TextEditingController searchController = TextEditingController();

  Timer? _applicantTimer;

  ProviderSubscription<ManageApplicationsState>? _stateSubscription;

  /// Ekranın ViewModel'i.
  ManageApplicationsViewModel get viewModel =>
      ref.read(manageApplicationsViewModelProvider(widget.clubId).notifier);

  ManageApplicationsState get _state =>
      ref.read(manageApplicationsViewModelProvider(widget.clubId));

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_loadMoreIfNearEnd);
    _stateSubscription = ref.listenManual(
      manageApplicationsViewModelProvider(widget.clubId),
      (previous, next) {
        final changed =
            previous == null ||
            previous.tab != next.tab ||
            previous.cursors != next.cursors ||
            previous.query != next.query;
        if (!changed || !next.hasMore) return;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _loadMoreIfNearEnd(),
        );
      },
    );
    final tab = widget.tab;
    if (tab != null && tab != ApplicationsTab.pending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) viewModel.setTab(tab);
      });
    }
    final applicantId = widget.applicantId;
    if (applicantId != null && applicantId.isNotEmpty) {
      _applicantTimer = Timer(
        AppDurations.postNavigationSheetDelay,
        () => unawaited(openDetail(applicantId)),
      );
    }
  }

  @override
  void dispose() {
    _applicantTimer?.cancel();
    _stateSubscription?.close();
    scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  /// Geri (`MGT-02.back`): önceki sayfa (MGT-01); yığın yoksa panel.
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      ManageRoute(clubId: widget.clubId).go(context);
    }
  }

  /// Kulüp değiştir (`MGT-02.switchClub`): SHT-18 → seçilen kulübün
  /// başvuruları.
  Future<void> switchClub() => _feedback.showSheet<String>(
    SheetId.sht18,
    builder: (_) => ManagedClubPickerSheet(
      selectedClubId: widget.clubId,
      onSelect: _openClub,
    ),
  );

  void _openClub(String clubId) {
    if (!mounted || clubId == widget.clubId) return;
    ManageApplicationsRoute(clubId: clubId).go(context);
  }

  /// "Yeniden dene" (`MGT-02.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Çek-yenile.
  Future<void> refresh() => viewModel.refresh();

  /// Sekme (`MGT-02.tab.<id>`).
  void selectTab(ApplicationsTab tab) => viewModel.setTab(tab);

  /// Arama alanı (`MGT-02.search`).
  void onQueryChanged(String query) => viewModel.setQuery(query);

  /// Sıralama (`MGT-02.sort`).
  void toggleSort() => viewModel.toggleSort();

  /// Seçim: uzun basış, onay kutusu (`MGT-02.select.<id>`) ya da seçim
  /// kipinde satır.
  void toggleSelect(String userId) => viewModel.toggleSelect(userId);

  /// "Hepsini seç" (`MGT-02.selectAll`).
  void selectAll() => viewModel.selectAll();

  /// Seçim çubuğunu kapat (`MGT-02.cancelSelect`).
  void cancelSelect() => viewModel.clearSelection();

  /// Toplu onay (`MGT-02.bulkApprove`): DLG-17 → TST-27.
  Future<void> bulkApprove() => viewModel.bulkApprove();

  /// Toplu ret (`MGT-02.bulkReject`): DLG-17 → TST-28.
  Future<void> bulkReject() => viewModel.bulkReject();

  /// "Başvuruları aç" (`MGT-02.toggleOpen`) → TST-54.
  Future<void> openApplications() => viewModel.openApplications();

  /// Danışman bakışında devre dışı yazma eylemi → TST-26.
  void onReadOnly() => viewModel.onReadOnlyTap();

  /// Satır onay düğmesi (`MGT-02.approve.<id>`) → TST-27 (çakışma DLG-18).
  Future<void> approve(String userId) => viewModel.approve(userId);

  /// Satır ret düğmesi (`MGT-02.reject.<id>`) ve SHT-19 "Reddet": SHT-20 →
  /// seçilen neden + açıklama → TST-28.
  Future<void> reject(String userId) async {
    if (!viewModel.ensureWritable()) return;
    final application = _state.find(userId);
    if (application == null) return;
    final decision = await _feedback.showSheet<RejectDecision>(
      SheetId.sht20,
      builder: (_) =>
          RejectReasonSheet(applicantName: _state.nameOf(application)),
    );
    if (decision == null || !mounted) return;
    final (reason, note) = decision;
    await viewModel.reject(userId, reason, note ?? '');
  }

  /// Satır (`MGT-02.row.<id>`) ve W-28 açılışı: SHT-19 başvuru detayı →
  /// seçilen eylem.
  Future<void> openDetail(String userId) async {
    final vm = viewModel;
    final application = await vm.resolveApplication(userId);
    if (!mounted) return;
    if (application != null) await vm.loadContact(userId);
    if (!mounted) return;
    final state = _state;
    final user = state.users[userId];
    final avatar = ref.userAvatarImage(user);
    final canUndo =
        application != null &&
        state.canUndo(
          application,
          ref.read(sessionViewModelProvider).uid,
          ref.read(appClockProvider).nowUtc(),
        );
    final action = await _feedback.showSheet<ApplicationDetailAction>(
      SheetId.sht19,
      builder: (_) => ApplicationDetailSheet(
        application: application,
        contact: state.contacts[userId],
        user: user,
        avatarImage: avatar,
        readOnly: state.isReadOnly,
        canUndo: canUndo,
        onReadOnlyTap: vm.onReadOnlyTap,
        onCopyEmail: () => unawaited(vm.copyEmail(userId)),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case ApplicationDetailAction.approve:
        await vm.approve(userId);
      case ApplicationDetailAction.reject:
        await reject(userId);
      case ApplicationDetailAction.undo:
        await vm.undoDecision(userId);
      case ApplicationDetailAction.profile:
        ClubUserProfileRoute(userId: userId, clubId: widget.clubId).go(context);
    }
  }

  /// Satıra dokunma: seçim kipinde seçim, değilse SHT-19.
  void onRowTap(String userId) {
    if (_state.selecting) {
      toggleSelect(userId);
    } else {
      unawaited(openDetail(userId));
    }
  }

  void _loadMoreIfNearEnd() {
    if (!mounted || !scrollController.hasClients || !_state.hasMore) return;
    final position = scrollController.position;
    if (position.extentAfter < position.viewportDimension) {
      unawaited(viewModel.loadMore());
    }
  }
}
