import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/management/provider/activity_log_state.dart';
import 'package:gu_kulupler/features/management/provider/activity_log_view_model.dart';
import 'package:gu_kulupler/features/management/view/activity_log_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';

/// MGT-10 davranışı: geri, kulüp değiştirme, tür grubu çipleri, sayfalama
/// tetikleyicisi, çek-yenile ve satır hedefleri.
///
/// * Sayfalama: liste sonuna bir ekran boyundan az kaldığında sonraki sayfa
///   istenir (kaydırma dinleyicisi). Sayfa geldiğinde ya da süzgeç
///   değiştiğinde liste hâlâ ekranı doldurmuyorsa istek yinelenir. Okunamayan
///   sayfa kendiliğinden yeniden denenmez (kullanıcı yeniden kaydırınca).
/// * Çip değişince liste başa döner.
/// * Satır (`MGT-10.row.<id>`) → `ActivityLogViewModel.targetOf`: etkinlik →
///   EVT-02, gönderi → FED-02, başvuru türleri → MGT-02, hedef kullanıcı →
///   CLB-07, diğerleri → MGT-09; bulunamayan hedef bir yere gitmez.
/// * Kulüp değiştir (`MGT-10.switchClub`, birden çok kulüp yönetende) →
///   SHT-18 → seçilen kulübün MGT-01'i (prototip SHT-18 varsayılanı).
mixin ActivityLogViewMixin on ConsumerState<ActivityLogView> {
  /// Listenin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  ProviderSubscription<ActivityLogState>? _stateSubscription;

  ActivityLogViewModelProvider get _provider =>
      activityLogViewModelProvider(widget.clubId);

  /// Ekranın ViewModel'i.
  ActivityLogViewModel get viewModel => ref.read(_provider.notifier);

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_loadMoreIfNearEnd);
    _stateSubscription = ref.listenManual(_provider, (previous, next) {
      // Görünen liste değişti (sayfa geldi, süzgeç): ekran hâlâ dolmuyorsa
      // sıradaki sayfa istenir.
      final changed =
          previous == null ||
          previous.entries.length != next.entries.length ||
          previous.cursor != next.cursor ||
          previous.category != next.category;
      if (!changed || !next.wantsMore) return;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadMoreIfNearEnd(),
      );
    });
  }

  @override
  void dispose() {
    _stateSubscription?.close();
    scrollController.dispose();
    super.dispose();
  }

  /// Geri (`MGT-10.back`): önceki sayfa (MGT-01); yığın yoksa panel.
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      ManageRoute(clubId: widget.clubId).go(context);
    }
  }

  /// Kulüp değiştir (`MGT-10.switchClub`) → SHT-18 → seçilen kulübün
  /// yönetim paneli (MGT-01).
  Future<void> switchClub() async {
    await ref
        .read(feedbackServiceProvider)
        .showSheet<String>(
          SheetId.sht18,
          builder: (_) => ManagedClubPickerSheet(
            selectedClubId: widget.clubId,
            onSelect: _openPanel,
          ),
        );
  }

  void _openPanel(String clubId) {
    if (!mounted) return;
    ManageRoute(clubId: clubId).go(context);
  }

  /// Tür grubu çipi (`MGT-10.filter.<id>`; `null` → "Tümü"): liste başa
  /// döner.
  void selectCategory(ActivityCategory? category) {
    if (scrollController.hasClients) scrollController.jumpTo(0);
    unawaited(viewModel.setCategory(category));
  }

  /// "Yeniden dene" (`MGT-10.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Çek-yenile.
  Future<void> refresh() => viewModel.refresh();

  /// Satır (`MGT-10.row.<id>`) → kaydın hedefi.
  void openEntry(ActivityModel entry) {
    if (!mounted) return;
    final target = viewModel.targetOf(entry);
    final id = target.id;
    switch (target.kind) {
      case ActivityLogTargetKind.event when id != null:
        EventDetailRoute(eventId: id).go(context);
      case ActivityLogTargetKind.post when id != null:
        PostDetailRoute(clubId: widget.clubId, postId: id).go(context);
      case ActivityLogTargetKind.profile when id != null:
        ClubUserProfileRoute(userId: id, clubId: widget.clubId).go(context);
      case ActivityLogTargetKind.applications:
        ManageApplicationsRoute(clubId: widget.clubId).go(context);
      case ActivityLogTargetKind.settings:
        ClubSettingsRoute(clubId: widget.clubId).go(context);
      case ActivityLogTargetKind.event:
      case ActivityLogTargetKind.post:
      case ActivityLogTargetKind.profile:
      case ActivityLogTargetKind.none:
        break;
    }
  }

  /// Liste sonuna bir ekran boyundan az kaldıysa sonraki sayfayı ister.
  void _loadMoreIfNearEnd() {
    if (!mounted || !scrollController.hasClients) return;
    if (!ref.read(_provider).wantsMore) return;
    final position = scrollController.position;
    if (position.extentAfter < position.viewportDimension) {
      unawaited(viewModel.loadMore());
    }
  }
}
