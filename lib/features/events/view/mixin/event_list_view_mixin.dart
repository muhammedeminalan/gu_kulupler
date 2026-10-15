import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/events/provider/event_filter_state.dart';
import 'package:gu_kulupler/features/events/provider/event_list_state.dart';
import 'package:gu_kulupler/features/events/provider/event_list_view_model.dart';
import 'package:gu_kulupler/features/events/view/event_join_flow.dart';
import 'package:gu_kulupler/features/events/view/event_list_view.dart';
import 'package:gu_kulupler/features/events/view/widget/event_filter_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/widget/event/event_cta.dart';
import 'package:gu_ui/gu_ui.dart';

/// EVT-01 davranışı: başa kaydırma, üst çubuk girişleri (ara, Biletlerim),
/// görünüm / çip / süzgeç seçimi, kart hızlı eylemi ve gezinme.
///
/// * Etkin sekmeye yeniden dokunma (`scrollTopRequestProvider`, PLAN §13.2)
///   listeyi başa kaydırır.
/// * SHT-11 buradan açılır (`FeedbackService`); toast'ları ViewModel ve
///   katılım akışı gösterir.
/// * Hızlı eylem (prototip `eventQuickAction`, `cards.js:58–67`): bilet →
///   EVT-03; bekleme listesindeyse → EVT-02; "Kulübe başvur" → CLB-03;
///   "Kayıtlar kapalı" → TST-X2; "Katıl" / "Bekleme listesine katıl" →
///   `runEventJoinFlow` (SHT-12 / DLG-15, T-23; W-81 kararı kartta
///   `joinsWaitlist`). Akış kayıt yazdıysa liste yeniden okunur.
mixin EventListViewMixin on ConsumerState<EventListView> {
  /// Sayfanın kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  ProviderSubscription<int>? _scrollTopSubscription;

  /// Ekranın ViewModel'i.
  EventListViewModel get viewModel =>
      ref.read(eventListViewModelProvider.notifier);

  Duration get _scrollDuration =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : GuMotion.base;

  @override
  void initState() {
    super.initState();
    _scrollTopSubscription = ref.listenManual(
      scrollTopRequestProvider(GuTab.events),
      (_, _) => scrollToTop(),
    );
  }

  @override
  void dispose() {
    _scrollTopSubscription?.close();
    scrollController.dispose();
    super.dispose();
  }

  /// Listeyi başa kaydırır (etkin sekmeye yeniden dokunma).
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

  /// Ara (`EVT-01.search`) → CLB-02, "Etkinlikler" sekmesi
  /// (`EventsSearchRoute`).
  void openSearch() => const EventsSearchRoute().go(context);

  /// "Biletlerim" (`EVT-01.tickets`) → EVT-04.
  void openMyEvents() => const MyEventsRoute().go(context);

  /// Liste ↔ takvim (`EVT-01.view.<kip>`).
  void selectMode(String id) =>
      viewModel.setMode(EventListMode.values.byName(id));

  /// Hızlı çip (`EVT-01.chip.<id>`).
  void selectChip(EventListChip chip) => viewModel.setChip(chip);

  /// "Filtre" (`EVT-01.filter`): SHT-11 → "Uygula" ile dönen süzgeç
  /// uygulanır; kapatılırsa değişiklik yok.
  Future<void> openFilters() async {
    final state = ref.read(eventListViewModelProvider);
    final result = await ref
        .read(feedbackServiceProvider)
        .showSheet<EventFilterState>(
          SheetId.sht11,
          builder: (_) => EventFilterSheet(
            initial: state.filter,
            clubs: state.clubs,
            memberClubIds: state.memberClubIds,
            countFor: viewModel.countFor,
          ),
        );
    if (result == null || !mounted) return;
    viewModel.setFilter(result);
  }

  /// "Filtreleri temizle" (`EVT-01.clearFilters`).
  void clearFilters() => viewModel.clearFilters();

  /// "Yeniden dene" (`EVT-01.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Çek-yenile (`EVT-01.refresh`).
  Future<void> refresh() => viewModel.refresh();

  /// Kart (`EVT-01.card.<eventId>`) → EVT-02.
  void openEvent(EventModel event) {
    if (mounted) EventDetailRoute(eventId: event.id).go(context);
  }

  /// Kulüp adı (`EVT-01.club.<eventId>`) → CLB-03 (Kulüpler sekmesine
  /// geçilir — Q-20).
  void openClub(String clubId) {
    if (mounted) ClubDetailRoute(clubId: clubId).go(context);
  }

  /// Kart hızlı eylemi (`EVT-01.join.<eventId>`).
  Future<void> onQuickAction(EventModel event, EventCtaKind kind) async {
    switch (kind) {
      case EventCtaKind.ticket:
        TicketRoute(eventId: event.id).go(context);
      case EventCtaKind.waitlist:
        openEvent(event);
      case EventCtaKind.applyClub:
        openClub(event.clubId);
      case EventCtaKind.closed:
        viewModel.showRegistrationClosed();
      case EventCtaKind.join:
      case EventCtaKind.joinWaitlist:
        final changed = await runEventJoinFlow(context, event, kind);
        if (changed && mounted) await viewModel.onRsvpChanged(event.id);
    }
  }
}
