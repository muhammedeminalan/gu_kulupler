import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/features/events/provider/my_events_state.dart';
import 'package:gu_kulupler/features/events/provider/my_events_view_model.dart';
import 'package:gu_kulupler/features/events/view/my_events_view.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';

/// EVT-04 davranışı: sekmeler, sayfalama tetikleyicisi, vazgeçme ve gezinme.
///
/// * Sayfalama: liste sonuna bir ekran boyundan az kaldığında sonraki sayfa
///   istenir (kaydırma dinleyicisi). Sayfa geldiğinde ya da sekme
///   değiştiğinde liste hâlâ ekranı doldurmuyorsa istek yinelenir. Okunamayan
///   sayfa kendiliğinden yeniden denenmez (kullanıcı yeniden kaydırınca).
/// * Gezinme `go` ile (guard'lı rotalar): satır → EVT-02, bilet → EVT-03,
///   "Etkinlikleri keşfet" → EVT-01; geri önceki sayfa (yığın yoksa EVT-01).
mixin MyEventsViewMixin on ConsumerState<MyEventsView> {
  /// Listenin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  ProviderSubscription<MyEventsState>? _stateSubscription;

  /// Ekranın ViewModel'i.
  MyEventsViewModel get viewModel =>
      ref.read(myEventsViewModelProvider.notifier);

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_loadMoreIfNearEnd);
    _stateSubscription = ref.listenManual(myEventsViewModelProvider, (
      previous,
      next,
    ) {
      // Görünen liste değişti (sayfa geldi, sekme): ekran hâlâ dolmuyorsa
      // sıradaki sayfa istenir.
      final changed =
          previous == null ||
          previous.loadedCount != next.loadedCount ||
          previous.rsvps.length != next.rsvps.length ||
          previous.tab != next.tab;
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

  /// Geri (`EVT-04.back`): önceki sayfa; yığın yoksa EVT-01.
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      const EventsRoute().go(context);
    }
  }

  /// Sekme (`EVT-04.tab.<id>`): liste başa döner.
  void selectTab(MyEventsTab tab) {
    if (scrollController.hasClients) scrollController.jumpTo(0);
    viewModel.setTab(tab);
  }

  /// "Yeniden dene" (`EVT-04.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Çek-yenile.
  Future<void> refresh() => viewModel.refresh();

  /// Satır (`EVT-04.event.<eventId>`) → EVT-02.
  void openEvent(String eventId) {
    if (!mounted) return;
    EventDetailRoute(eventId: eventId).go(context);
  }

  /// "Biletini göster" (`EVT-04.ticket.<eventId>`) → EVT-03.
  void openTicket(String eventId) {
    if (!mounted) return;
    TicketRoute(eventId: eventId).go(context);
  }

  /// "Vazgeç" / "Ayrıl" (`EVT-04.leave.<eventId>`): DLG-14 → TST-42
  /// (ViewModel).
  void leave(String eventId) => unawaited(viewModel.leave(eventId));

  /// "Etkinlikleri keşfet" (`EVT-04.discover`) → EVT-01.
  void discover() {
    if (!mounted) return;
    const EventsRoute().go(context);
  }

  /// Liste sonuna bir ekran boyundan az kaldıysa sonraki sayfayı ister.
  void _loadMoreIfNearEnd() {
    if (!mounted || !scrollController.hasClients) return;
    if (!ref.read(myEventsViewModelProvider).wantsMore) return;
    final position = scrollController.position;
    if (position.extentAfter < position.viewportDimension) {
      unawaited(viewModel.loadMore());
    }
  }
}
