import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/features/events/provider/ticket_state.dart';
import 'package:gu_kulupler/features/events/provider/ticket_view_model.dart';
import 'package:gu_kulupler/features/events/view/ticket_view.dart';
import 'package:gu_kulupler/features/events/view/widget/add_to_calendar_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/navigation/routes/system_routes.dart';
import 'package:gu_kulupler/product/widget/event/event_place_label.dart';

/// EVT-03 davranışı: gezinme, takvime ekleme (SHT-14), vazgeçme (DLG-14),
/// "içerik yok" / "bilet yok" yönlendirmesi (prototip `Ticket`,
/// `screens-events.js:74–87`).
///
/// * Geri (`EVT-03.back`) önceki sayfaya döner; yığın yoksa EVT-02.
/// * "Etkinliğe git" (`EVT-03.openEvent`) EVT-02'ye döner (prototip
///   `popTo('EVT-02') || push`): bilet rotası EVT-02'nin altındadır.
/// * Takvim simgesi (`EVT-03.addToCalendar`) SHT-14'ü açar; seçilen yol
///   ViewModel'de yürür (`EventCalendarMixin`).
/// * "Vazgeç" (`EVT-03.leave`) DLG-14 → vazgeçildiyse önceki sayfa
///   (prototip `onDone: () => app.nav.back()`).
/// * Etkinlik yoksa SYS-04; bilet yoksa (kayıt yok / bekleme listesi)
///   EVT-02.
mixin TicketViewMixin on ConsumerState<TicketView> {
  /// Ekranın ViewModel sağlayıcısı (etkinlik ailesi).
  TicketViewModelProvider get provider =>
      ticketViewModelProvider(widget.eventId);

  /// Ekranın ViewModel'i.
  TicketViewModel get viewModel => ref.read(provider.notifier);

  @override
  void initState() {
    super.initState();
    // ViewModel canlıyken (yönlendirme gerektiren durum zaten biliniyorsa).
    final state = ref.read(provider);
    if (state.isNotFound || state.hasNoTicket) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _redirect(state));
    }
  }

  /// `build` içinde çağrılır: etkinlik yok → SYS-04, bilet yok → EVT-02.
  void watchRedirects() => ref.listen(provider, (previous, next) {
    final wasRedirect =
        (previous?.isNotFound ?? false) || (previous?.hasNoTicket ?? false);
    if (!wasRedirect) _redirect(next);
  });

  /// Geri (`EVT-03.back`): önceki sayfa; yığın yoksa EVT-02.
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      openEvent();
    }
  }

  /// "Etkinliğe git" (`EVT-03.openEvent`) → EVT-02.
  void openEvent() {
    if (mounted) EventDetailRoute(eventId: widget.eventId).go(context);
  }

  /// "Yeniden dene" (`EVT-03.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Takvim simgesi (`EVT-03.addToCalendar`) → SHT-14 → seçilen yol.
  Future<void> openCalendar() async {
    final state = ref.read(provider);
    final event = state.event;
    if (event == null) return;
    final choice = await ref
        .read(feedbackServiceProvider)
        .showSheet<CalendarChoice>(
          SheetId.sht14,
          builder: (_) => const AddToCalendarSheet(),
        );
    if (choice == null || !mounted) return;
    await viewModel.addToCalendar(
      choice,
      event: event,
      clubName: state.club?.name ?? '',
      placeLabel: EventPlaceLabel.of(context, event),
    );
  }

  /// "Vazgeç" (`EVT-03.leave`) → DLG-14; vazgeçildiyse önceki sayfa.
  Future<void> leave() async {
    if (await viewModel.leave() && mounted) goBack();
  }

  void _redirect(TicketViewState state) {
    if (!mounted) return;
    if (state.isNotFound) {
      const NotFoundRoute().go(context);
    } else if (state.hasNoTicket) {
      openEvent();
    }
  }
}
