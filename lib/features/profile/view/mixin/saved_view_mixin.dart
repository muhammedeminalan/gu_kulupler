import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/features/profile/provider/saved_state.dart';
import 'package:gu_kulupler/features/profile/provider/saved_view_model.dart';
import 'package:gu_kulupler/features/profile/view/saved_view.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';

/// PRF-04 davranışı: sayfalama tetikleyicisi, kaydı kaldırma ve gezinme.
///
/// * Sayfalama: liste sonuna bir ekran boyundan az kaldığında sonraki sayfa
///   istenir; sayfa geldiğinde liste hâlâ ekranı doldurmuyorsa istek
///   yinelenir (EVT-04 kalıbı).
/// * Gezinme `go` ile (guard'lı rota; sekme değiştirir — Q-20 (A)): kart →
///   FED-02 (`PostDetailRoute`); geri önceki sayfa (yığın yoksa PRF-01).
mixin SavedViewMixin on ConsumerState<SavedView> {
  /// Listenin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  ProviderSubscription<SavedState>? _stateSubscription;

  /// Ekranın ViewModel'i.
  SavedViewModel get viewModel => ref.read(savedViewModelProvider.notifier);

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_loadMoreIfNearEnd);
    _stateSubscription = ref.listenManual(savedViewModelProvider, (
      previous,
      next,
    ) {
      final changed =
          previous == null || previous.items.length != next.items.length;
      if (!changed || !next.wantsMore) return;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadMoreIfNearEnd(),
      );
    });
  }

  @override
  void dispose() {
    _stateSubscription?.close();
    scrollController
      ..removeListener(_loadMoreIfNearEnd)
      ..dispose();
    super.dispose();
  }

  /// Geri (`PRF-04.back`): önceki sayfa; yığın yoksa PRF-01.
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      const ProfileRoute().go(context);
    }
  }

  /// "Yeniden dene" (`PRF-04.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Çek-yenile.
  Future<void> refresh() => viewModel.refresh();

  /// Kart (`PRF-04.post.<postId>`) → FED-02.
  void openPost({required String clubId, required String postId}) {
    if (!mounted) return;
    PostDetailRoute(clubId: clubId, postId: postId).go(context);
  }

  /// "Kaydı kaldır" (`PRF-04.unsave.<postId>`) → TST-11 (ViewModel).
  void unsave(String postId) => unawaited(viewModel.unsave(postId));

  /// Liste sonuna bir ekran boyundan az kaldıysa sonraki sayfayı ister.
  void _loadMoreIfNearEnd() {
    if (!mounted || !scrollController.hasClients) return;
    if (!ref.read(savedViewModelProvider).wantsMore) return;
    final position = scrollController.position;
    if (position.extentAfter < position.viewportDimension) {
      unawaited(viewModel.loadMore());
    }
  }
}
