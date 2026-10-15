import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/club_members_view.dart';
import 'package:gu_kulupler/product/mixin/manage_member_actions_mixin.dart';
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
///   `screens-clubs.js:147`): SHT-21 "Üye işlemleri" (profili gör / rolü
///   değiştir → SHT-22 → DLG-20 / üyelikten çıkar → DLG-19; W-20).
mixin ClubMembersViewMixin on ConsumerState<ClubMembersView> {
  /// Listenin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  /// Arama alanının denetleyicisi.
  final TextEditingController searchController = TextEditingController();

  ProviderSubscription<ClubMembersState>? _stateSubscription;

  /// Ekranın ViewModel'i.
  ClubMembersViewModel get viewModel =>
      ref.read(clubMembersViewModelProvider(widget.clubId).notifier);

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

  /// Üye satırı (`CLB-06.member.<userId>`) → CLB-07, CLB-06'nın altında
  /// (geri → üye listesi; K-69).
  void openProfile(String userId) {
    if (!mounted) return;
    ClubMembersUserProfileRoute(
      clubId: widget.clubId,
      userId: userId,
    ).go(context);
  }

  /// Satır menüsü (`CLB-06.menu.<userId>`; yalnızca yönetici bakışında):
  /// SHT-21 "Üye işlemleri" (W-20). Rol değiştirme ve çıkarma
  /// ViewModel'dedir; "Profili gör" CLB-07'yi açar.
  Future<void> openMenu(MembershipModel membership) async {
    final outcome = await viewModel.openMemberMenu(membership);
    if (!mounted || outcome != MemberMenuOutcome.viewProfile) return;
    openProfile(membership.userId);
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
