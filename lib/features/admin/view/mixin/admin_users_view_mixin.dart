import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/admin/provider/admin_users_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_users_view_model.dart';
import 'package:gu_kulupler/features/admin/view/admin_users_view.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_user_menu.dart';
import 'package:gu_kulupler/product/feedback/dialogs/suspend_user_dialog.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

/// ADM-05 bölmesinin davranışı: açılış süzgeci (`?filter=`), arama, süzgeç,
/// çek-yenile, başa kaydırma, sayfalama, satır menüsü ve gezinme.
///
/// * Gezinme `go` ile (guard'lı rotalar): satır ve menü "Profili gör" →
///   CLB-07 (`AdminUserProfileRoute`, admin kökünün alt sayfası; geri → bu
///   bölme). Bölmeli geçiş admin kökündedir (`AdminViewMixin`); etkin
///   sekmeye yeniden dokunma (`scrollTopRequestProvider`) bölme sahnedeyse
///   ([AdminUsersView.active]) listeyi başa kaydırır.
/// * "Askıya al" / "Askıyı kaldır" → DLG-30 → ViewModel (TST-52); kendi
///   satırında öğe yoktur (W-101 b).
/// * Liste sonuna yaklaşınca (ya da süzülen liste ekranı doldurmuyorsa) ad
///   kipinin sıradaki sayfası istenir.
mixin AdminUsersViewMixin on ConsumerState<AdminUsersView> {
  /// Listenin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  ProviderSubscription<AdminUsersState>? _stateSubscription;

  ProviderSubscription<int>? _scrollTopSubscription;

  /// Ekranın ViewModel'i.
  AdminUsersViewModel get viewModel =>
      ref.read(adminUsersViewModelProvider.notifier);

  AdminUsersState get _state => ref.read(adminUsersViewModelProvider);

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_loadMoreIfNearEnd);
    _stateSubscription = ref.listenManual(adminUsersViewModelProvider, (
      previous,
      next,
    ) {
      // Görünen liste değişti (sayfa geldi, süzgeç): ekran hâlâ dolmuyorsa
      // sıradaki sayfa istenir.
      final changed =
          previous == null ||
          previous.filter != next.filter ||
          previous.users.length != next.users.length;
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
    _applyRouteFilter();
  }

  @override
  void didUpdateWidget(AdminUsersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filter != oldWidget.filter) _applyRouteFilter();
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

  /// Arama (`ADM-05.search`).
  void search(String query) => viewModel.setQuery(query);

  /// Süzgeç (`ADM-05.filter.<name>`): liste başa döner.
  void selectFilter(AdminUsersFilter filter) {
    if (scrollController.hasClients) scrollController.jumpTo(0);
    viewModel.setFilter(filter);
  }

  /// "Yeniden dene" (`ADM-05.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Çek-yenile.
  Future<void> refresh() => viewModel.refresh();

  /// Satır (`ADM-05.row.<id>`) / menü "Profili gör" → CLB-07.
  void openUser(String userId) {
    if (!mounted) return;
    AdminUserProfileRoute(userId: userId).go(context);
  }

  /// "Diğer" (`ADM-05.menu.<id>`): açılır menü → seçilen eylem.
  Future<void> openMenu(UserModel user) async {
    final action = await ref
        .read(feedbackServiceProvider)
        .showMenu<AdminUserMenuAction>(
          scrimKey: AdminUserMenu.scrimKey,
          items: AdminUserMenu.items(
            context.l10n,
            user,
            self: viewModel.isSelf(user.uid),
          ),
        );
    if (action == null || !mounted) return;
    switch (action) {
      case AdminUserMenuAction.profile:
        openUser(user.uid);
      case AdminUserMenuAction.suspend:
        await toggleSuspend(user);
    }
  }

  /// "Askıya al" / "Askıyı kaldır" → DLG-30 → yazım (TST-52).
  Future<void> toggleSuspend(UserModel user) async {
    if (viewModel.isSelf(user.uid)) return;
    final suspending = user.status != UserStatus.suspended;
    final reason = await SuspendUserDialog.show(
      ref.read(feedbackServiceProvider),
      userName: user.name,
      suspending: suspending,
    );
    if (reason == null || !mounted) return;
    if (suspending) {
      unawaited(viewModel.suspend(user.uid, reason));
    } else {
      unawaited(viewModel.unsuspend(user.uid));
    }
  }

  void _loadMoreIfNearEnd() {
    if (!mounted || !scrollController.hasClients || !_state.hasMore) return;
    final position = scrollController.position;
    if (position.extentAfter < position.viewportDimension) {
      unawaited(viewModel.loadMore());
    }
  }

  /// Rotadaki `?filter=` süzgecini ilk kareden sonra uygular (yapım
  /// sırasında sağlayıcı değiştirilmez); boş değer hâli değiştirmez.
  void _applyRouteFilter() {
    final filter = widget.filter;
    if (filter == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) viewModel.setFilter(filter);
    });
  }
}
