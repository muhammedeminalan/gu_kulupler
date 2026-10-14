import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/events/provider/event_detail_state.dart';
import 'package:gu_kulupler/features/events/provider/event_detail_view_model.dart';
import 'package:gu_kulupler/features/events/view/event_detail_view.dart';
import 'package:gu_kulupler/features/events/view/widget/add_to_calendar_sheet.dart';
import 'package:gu_kulupler/features/events/view/widget/event_detail_sections.dart';
import 'package:gu_kulupler/features/events/view/widget/event_menu.dart';
import 'package:gu_kulupler/features/events/view/widget/reminder_sheet.dart';
import 'package:gu_kulupler/features/events/view/widget/rsvp_confirm_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/share_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/menu_id.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/navigation/routes/system_routes.dart';
import 'package:gu_kulupler/product/widget/event/event_place_label.dart';
import 'package:gu_ui/gu_ui.dart';

/// EVT-02 davranışı: kaydırma (paralaks, durum çubuğu), açılış sonuçları
/// (SYS-04, CD-57, DLG-16), katılım akışı, hatırlatıcı, takvim, paylaşım,
/// menü, şikayet ve gezinme.
///
/// * Sheet'ler (SHT-10, SHT-12, SHT-13, SHT-14, SHT-15) ve EVT-MENU buradan
///   açılır (`FeedbackService`); dialog ve toast'ları ViewModel gösterir.
/// * Gezinme `go` ile (guard'lı rotalar): kulüp → CLB-03, bilet → EVT-03,
///   bulunamadı → SYS-04, okuma izni yok / "Benzer etkinlikleri gör" →
///   Etkinlikler sekmesi.
/// * Hedefi henüz yazılmamış girişler anahtarlarıyla yerindedir: Düzenle
///   (MGT-05 → T-34), Katılımcılar / Yoklama (MGT-06 / 07 → T-35), yönetici
///   menüsü (SHT-23 → T-34).
mixin EventDetailViewMixin on ConsumerState<EventDetailView> {
  /// Sayfanın kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  /// Paralaks ofseti (`min(220, scrollTop)`, eksi olmaz).
  final ValueNotifier<double> parallaxOffset = ValueNotifier<double>(0);

  /// Kapak durum çubuğunun altında mı? `true` iken durum çubuğu açık
  /// ikonludur (D-20); kapak yukarı kayınca tema stiline dönülür.
  final ValueNotifier<bool> coverUnderStatusBar = ValueNotifier<bool>(true);

  /// Açıklama açık mı ("Devamı"ya dokunuldu)?
  bool aboutExpanded = false;

  final List<ProviderSubscription<Object?>> _subscriptions = [];

  /// Ekranın ViewModel'i.
  EventDetailViewModel get viewModel =>
      ref.read(eventDetailViewModelProvider(widget.eventId).notifier);

  EventDetailState get _state =>
      ref.read(eventDetailViewModelProvider(widget.eventId));

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    final provider = eventDetailViewModelProvider(widget.eventId);
    _subscriptions
      ..add(
        ref.listenManual<bool>(provider.select((s) => s.isNotFound), (
          _,
          missing,
        ) {
          if (missing) _afterFrame(() => const NotFoundRoute().go(context));
        }, fireImmediately: true),
      )
      ..add(
        ref.listenManual<bool>(provider.select((s) => s.isDenied), (_, denied) {
          if (denied) _afterFrame(() => const EventsRoute().go(context));
        }, fireImmediately: true),
      )
      ..add(
        ref.listenManual<bool>(provider.select((s) => s.event != null), (
          before,
          loaded,
        ) {
          if (loaded && before != true) _afterFrame(_showCancelledNotice);
        }, fireImmediately: true),
      );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.close();
    }
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    parallaxOffset.dispose();
    coverUnderStatusBar.dispose();
    super.dispose();
  }

  /// Üst güvenli alan şeridinin opaklığı (0–1; `ClubDetailViewMixin` ile
  /// aynı kural).
  double topStripOpacity(double offset, double topInset) {
    if (topInset <= 0) return 0;
    final fadeStart = GuSizes.parallaxHeight - topInset - topInset;
    return ((offset - fadeStart) / topInset).clamp(0, 1).toDouble();
  }

  // ───────────────────────────────── biçim ──────────────────────────────────

  AppDateFormats get _formats => AppDateFormats(
    Localizations.localeOf(context),
    ref.read(appClockProvider),
  );

  /// Tarih kartının başlığı (`9 Ekim Cuma`).
  String dateLabelOf(EventModel event) => _formats.dateLong(event.startsAt);

  /// Tarih kartının alt satırı: saat aralığı · süre (`18:00–20:00 · 2 sa`).
  String timeLabelOf(EventModel event) {
    final l10n = context.l10n;
    final minutes = event.endsAt.difference(event.startsAt).inMinutes;
    final String duration;
    if (minutes < Duration.minutesPerHour) {
      duration = l10n.timeMinutes(minutes);
    } else {
      // Bir ondalık (`app.fmt.duration`, core.js:637): 90 dk → 1,5 sa.
      final tenths = (minutes * 10 / Duration.minutesPerHour).round();
      duration = l10n.timeHours(tenths % 10 == 0 ? tenths ~/ 10 : tenths / 10);
    }
    return [
      _formats.range(l10n, event.startsAt, event.endsAt),
      duration,
    ].join(EventDetailSections.separator);
  }

  /// Mekânın gösterilen adı.
  String placeLabelOf(EventModel event) => EventPlaceLabel.of(context, event);

  /// İptal bandının metni (neden varsa "… — {neden}").
  String cancelledTextOf(EventModel event, String? reason) {
    final l10n = context.l10n;
    return reason == null
        ? l10n.eventCancelledBanner
        : l10n.eventCancelledBannerReason(reason);
  }

  /// Yüklenmiş kapak görseli (`event.coverPath`); adresi henüz bilinmiyorsa
  /// `null` (şablon kapak). Adres gelince görsel çözücüsü yeniden yayılır ve
  /// ekran yeniden çizilir.
  ImageProvider? coverImageOf(EventModel event) {
    final path = event.coverPath;
    if (path == null) return null;
    ref.watch(postImageResolverProvider);
    final cache = ref.read(imageUrlCacheProvider);
    unawaited(cache.request(path));
    final url = cache.peek(path);
    return url == null
        ? null
        : ref.read(storageImageFactoryProvider)(url, path);
  }

  // ──────────────────────────────── eylemler ────────────────────────────────

  /// Geri (`EVT-02.back`): yığında sayfa varsa geri, yoksa Etkinlikler.
  void back() {
    if (context.canPop()) {
      context.pop();
    } else {
      const EventsRoute().go(context);
    }
  }

  /// "Yeniden dene" (hata görünümü).
  Future<void> retry() => viewModel.fetch();

  /// "Devamı" (`EVT-02.more`).
  void readMore() => setState(() => aboutExpanded = true);

  /// Kulüp satırı (`EVT-02.club`) ve "Kulübe başvur" (`EVT-02.applyClub`)
  /// → CLB-03.
  void openClub() {
    final clubId = _state.event?.clubId;
    if (clubId != null) ClubDetailRoute(clubId: clubId).go(context);
  }

  /// "Biletini göster" (`EVT-02.ticket`, TST-41 eylemi) → EVT-03.
  void openTicket() {
    if (mounted) TicketRoute(eventId: widget.eventId).go(context);
  }

  /// "Katıl" (`EVT-02.join`): çevrimdışı → TST-24; SHT-12 (çakışma uyarısı
  /// ile) → seçilen hatırlatıcıyla katılım.
  Future<void> join() async {
    final event = _state.event;
    if (event == null || !viewModel.ensureCanJoin()) return;
    final conflict = await viewModel.hasConflict();
    if (!mounted) return;
    final reminder = await _feedback.showSheet<ReminderOption>(
      SheetId.sht12,
      builder: (_) => RsvpConfirmSheet(event: event, hasConflict: conflict),
    );
    if (reminder == null || !mounted) return;
    await viewModel.join(reminder, onTicket: openTicket);
  }

  /// Devre dışı "Kayıtlar kapalı" (`EVT-02.join`) → TST-X2.
  void showClosed() => viewModel.showRegistrationClosed();

  /// "Bekleme listesine katıl" (`EVT-02.waitlist`) → DLG-15.
  Future<void> joinWaitlist() async {
    await viewModel.joinWaitlist();
  }

  /// "Vazgeç" / "Ayrıl" (`EVT-02.leave`) → DLG-14.
  Future<void> leave() async {
    await viewModel.cancelRsvp();
  }

  /// Devre dışı "Etkinlik sona erdi" (`EVT-02.ended`) → TST-X6.
  void showEnded() => viewModel.showEnded();

  /// Hatırlatıcı satırı (`EVT-02.reminder`, `EVT-02.menu.reminder`): kayıt
  /// yoksa TST-X7; varsa SHT-13 → seçim.
  Future<void> openReminder() async {
    if (!viewModel.ensureCanSetReminder()) return;
    final current = _state.activeRsvp?.reminder ?? ReminderOption.none;
    final option = await _feedback.showSheet<ReminderOption>(
      SheetId.sht13,
      builder: (_) => ReminderSheet(current: current),
    );
    if (option == null || !mounted) return;
    await viewModel.setReminder(option);
  }

  /// "Takvime ekle" (`EVT-02.addToCalendar`, `EVT-02.menu.calendar`) →
  /// SHT-14 → seçilen yol.
  Future<void> openCalendar() async {
    final event = _state.event;
    if (event == null) return;
    final location = placeLabelOf(event);
    final choice = await _feedback.showSheet<CalendarChoice>(
      SheetId.sht14,
      builder: (_) => const AddToCalendarSheet(),
    );
    if (choice == null || !mounted) return;
    await viewModel.addToCalendar(
      choice,
      event: event,
      clubName: _state.club?.name ?? '',
      placeLabel: location,
    );
  }

  /// "Yol tarifi" (`EVT-02.directions`) → DLG-32 → harita.
  Future<void> openDirections() async {
    final event = _state.event;
    if (event == null) return;
    await viewModel.openDirections(placeLabelOf(event));
  }

  /// Paylaş (`EVT-02.share`, `EVT-02.menu.share`): SHT-15 → seçilen yol.
  Future<void> openShare() async {
    final event = _state.event;
    if (event == null) return;
    final choice = await _feedback.showSheet<ShareChoice>(
      SheetId.sht15,
      builder: (_) => ShareSheet(title: event.title, url: viewModel.shareUrl()),
    );
    if (choice == null || !mounted) return;
    await viewModel.share(choice);
  }

  /// "Etkinliği şikayet et" (`EVT-02.report`, `EVT-02.menu.report`): SHT-10
  /// → yazım → DLG-12.
  Future<void> openReport() async {
    final target = viewModel.reportTarget;
    if (target == null) return;
    final report = await _feedback.showSheet<ReportReasonResult>(
      SheetId.sht10,
      builder: (_) =>
          ReportReasonSheet(target: target, onSubmit: viewModel.submitReport),
    );
    if (report == null || !mounted) return;
    await viewModel.showReportReceived();
  }

  /// ⋮ (`EVT-02.menu`): yönetici → SHT-23 (T-34); diğerleri → EVT-MENU.
  Future<void> openMenu() async {
    final state = _state;
    if (state.event == null) return;
    if (state.canManage) {
      // TODO(T-34): SHT-23 "Etkinlik menüsü" (yönetici — düzenle, çoğalt,
      // kayıtları aç / kapa, iptal).
      return;
    }
    final action = await _feedback.showMenu<EventMenuAction>(
      id: MenuId.evtMenu,
      scrimKey: GuKey.action('EVT-02.scrim'),
      items: EventMenu.items(
        context.l10n,
        hasRsvp: state.activeRsvp != null,
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case EventMenuAction.reminder:
        await openReminder();
      case EventMenuAction.calendar:
        await openCalendar();
      case EventMenuAction.share:
        await openShare();
      case EventMenuAction.report:
        await openReport();
    }
  }

  /// Katılımcı satırı (`EVT-02.attendeesPreview`): yönetici → MGT-06;
  /// diğerleri → TST-X8.
  void openAttendeesPreview() {
    if (_state.canManage) {
      openAttendees();
    } else {
      viewModel.showAttendeeCount();
    }
  }

  /// "Düzenle" (`EVT-02.edit`) → MGT-05.
  void openEdit() {
    // TODO(T-34): `EventFormRoute(clubId:, eventId:)` (MGT-05).
  }

  /// "Katılımcılar" (`EVT-02.attendees`) → MGT-06.
  void openAttendees() {
    // TODO(T-35): `AttendeesRoute(clubId:, eventId:)` (MGT-06).
  }

  /// "Yoklama başlat" (`EVT-02.scan`) → MGT-07.
  void openScan() {
    // TODO(T-35): `ScanRoute(clubId:, eventId:)` (MGT-07).
  }

  // ────────────────────────────────── iç ────────────────────────────────────

  /// İptal edilmiş etkinlik: DLG-16 (oturumda bir kez; bildirimden gelince
  /// her zaman). "Benzer etkinlikleri gör" → Etkinlikler.
  Future<void> _showCancelledNotice() async {
    final similar = await viewModel.showCancelledNotice(
      force: widget.showCancelled,
    );
    if (similar && mounted) const EventsRoute().go(context);
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final offset = math.max<double>(0, scrollController.offset);
    parallaxOffset.value = math.min(GuSizes.parallaxHeight, offset);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    coverUnderStatusBar.value = offset < GuSizes.parallaxHeight - topInset;
  }

  /// [action] yapım bittikten sonra (sağlayıcı dinleyicisinden gezinme).
  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) action();
      })
      ..ensureVisualUpdate();
  }
}
