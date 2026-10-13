import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/club_members_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/user_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';

/// CLB-06 davranışı: arama alanı, rol çipleri, sayfalama tetikleyicisi, satır
/// menüsü ve gezinme.
///
/// * Sayfalama: liste sonuna bir ekran boyundan az kaldığında sonraki sayfa
///   istenir (kaydırma dinleyicisi). Sayfa geldiğinde ya da süzgeç / arama
///   değiştiğinde liste hâlâ ekranı doldurmuyorsa istek yinelenir — arama,
///   okunmamış sayfalardaki üyeleri de böyle bulur. Okunamayan sayfa
///   kendiliğinden yeniden denenmez (kullanıcı yeniden kaydırınca denenir).
/// * Satır menüsü yalnızca yönetici bakışında çizilir (prototip
///   `screens-clubs.js:147`). Hedefi SHT-21 "Üye işlemleri"dir (T-33, bağlama
///   borcu W-20); o zamana kadar SHT-27 "Kullanıcı" açılır: profili gör /
///   engelle (DLG-13 → TST-09) / şikayet et (SHT-10 → DLG-12).
mixin ClubMembersViewMixin on ConsumerState<ClubMembersView> {
  /// Listenin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  /// Arama alanının denetleyicisi.
  final TextEditingController searchController = TextEditingController();

  ProviderSubscription<ClubMembersState>? _stateSubscription;

  /// Ekranın ViewModel'i.
  ClubMembersViewModel get viewModel =>
      ref.read(clubMembersViewModelProvider(widget.clubId).notifier);

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_loadMoreIfNearEnd);
    _stateSubscription = ref.listenManual(
      clubMembersViewModelProvider(widget.clubId),
      (previous, next) {
        // Görünen liste değişti (sayfa geldi, süzgeç / arama): ekran hâlâ
        // dolmuyorsa sıradaki sayfa istenir.
        final changed =
            previous == null ||
            previous.members.length != next.members.length ||
            previous.cursor != next.cursor ||
            previous.roleFilter != next.roleFilter ||
            previous.query != next.query;
        if (!changed || !next.wantsMore) return;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _loadMoreIfNearEnd(),
        );
      },
    );
  }

  @override
  void dispose() {
    _stateSubscription?.close();
    scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  /// Geri (`CLB-06.back`): önceki sayfa (CLB-03); yığın yoksa kulübün
  /// "Üyeler" sekmesi.
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      ClubDetailRoute(
        clubId: widget.clubId,
        tab: ClubDetailTab.members,
      ).go(context);
    }
  }

  /// Arama alanı (`CLB-06.search`).
  void onQueryChanged(String query) => viewModel.setQuery(query);

  /// Rol çipi (`CLB-06.filter.<id>`).
  void selectFilter(MemberRoleFilter filter) => viewModel.setRoleFilter(filter);

  /// "Yeniden dene" (`CLB-06.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Çek-yenile.
  Future<void> refresh() => viewModel.refresh();

  /// Üye satırı (`CLB-06.member.<userId>`) → CLB-07, kulüp bağlamıyla.
  void openProfile(String userId) {
    if (!mounted) return;
    ClubUserProfileRoute(userId: userId, clubId: widget.clubId).go(context);
  }

  /// Satır menüsü (`CLB-06.menu.<userId>`; yalnızca yönetici bakışında).
  Future<void> openMenu(MembershipModel membership) async {
    final userId = membership.userId;
    // TODO(T-33): yönetici menüsü SHT-21 `MemberActionsSheet` (profil / rol
    // değiştir / çıkar; W-20). O zamana kadar SHT-27 açılır.
    final action = await _feedback.showSheet<UserMenuAction>(
      SheetId.sht27,
      builder: (_) => UserMenuSheet(
        userId: userId,
        userName: ref
            .read(clubMembersViewModelProvider(widget.clubId))
            .nameOf(membership),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case UserMenuAction.viewProfile:
        openProfile(userId);
      case UserMenuAction.block:
        await viewModel.block(userId);
      case UserMenuAction.unblock:
        await viewModel.unblock(userId);
      case UserMenuAction.report:
        await _openReport(userId);
      case UserMenuAction.removeComment:
      case UserMenuAction.reportComment:
        // Yorum satırları yalnızca yorum menüsünde çizilir (T-20).
        break;
    }
  }

  /// "Kullanıcıyı şikayet et": SHT-10 → yazım → DLG-12 (→ "… engelle").
  Future<void> _openReport(String userId) async {
    final report = await _feedback.showSheet<ReportReasonResult>(
      SheetId.sht10,
      builder: (_) => ReportReasonSheet(
        target: viewModel.reportTargetOf(userId),
        onSubmit: viewModel.submitReport,
      ),
    );
    if (report == null || !mounted) return;
    await viewModel.showReportReceived(userId);
  }

  /// Liste sonuna bir ekran boyundan az kaldıysa sonraki sayfayı ister.
  void _loadMoreIfNearEnd() {
    if (!mounted || !scrollController.hasClients) return;
    if (!ref.read(clubMembersViewModelProvider(widget.clubId)).wantsMore) {
      return;
    }
    final position = scrollController.position;
    if (position.extentAfter < position.viewportDimension) {
      unawaited(viewModel.loadMore());
    }
  }
}
