import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/clubs/provider/club_detail_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_detail_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/join_application_state.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_events_tab.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_menu_sheet.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_notification_sheet.dart';
import 'package:gu_kulupler/features/clubs/view/widget/join_application_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/share_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/navigation/routes/system_routes.dart';
import 'package:gu_kulupler/product/widget/event/event_cta.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-03 davranışı: kaydırma (parallax, durum çubuğu), sekmeler, katılım
/// akışı, paylaşım, menü, şikayet, bağlantılar ve gezinme.
///
/// * Kaydırma: [scrollOffset] kapağın parallax'ını ve üst güvenli alan
///   şeridini besler; kapak durum çubuğunun altından çıkınca
///   [coverUnderStatusBar] `false` olur (durum çubuğu tema stiline döner).
/// * Sheet'ler buradan açılır (`FeedbackService`); dialog ve toast'ları
///   ViewModel gösterir.
/// * "Katıl": ViewModel hangi yolun gerektiğini söyler — SHT-05 (başvuru)
///   → CLB-04, bekleme → CLB-05, onaysız kulüp → doğrudan katılım (TST-34).
/// * Kulüp yoksa / silinmişse SYS-04'e gidilir.
/// * Kişi satırları CLB-07'ye, "Tüm üyeler" CLB-06'ya gider (`go`).
/// * Etkinlik kartı EVT-02'ye, bilet düğmesi EVT-03'e gider; karttan katılım
///   rotanın verdiği akışla ([ClubDetailView.eventJoinFlow]) yapılır.
/// * "Yönetim" girişi MGT-01'e (W-12, T-31), "Etkinlik oluştur" MGT-05'e
///   (W-17, T-34) gider. Hedefi henüz yazılmamış girişler (MGT-09, SHT-25)
///   anahtarlarıyla yerindedir; hedef ekranın task'ında bağlanır (bağlama
///   borçları W-13…W-16).
mixin ClubDetailViewMixin on ConsumerState<ClubDetailView> {
  /// Sayfanın kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  /// Kaydırma ofseti (dp, eksi olmaz).
  final ValueNotifier<double> scrollOffset = ValueNotifier<double>(0);

  /// Kapak durum çubuğunun altında mı? `true` iken durum çubuğu açık
  /// ikonludur (D-20); kapak yukarı kayınca tema stiline dönülür.
  final ValueNotifier<bool> coverUnderStatusBar = ValueNotifier<bool>(true);

  /// "Hakkında" metni açık mı ("Devamı"ya dokunuldu)?
  bool aboutExpanded = false;

  /// "Etkinlikler" sekmesinin dilimi.
  ClubEventSegment eventSegment = ClubEventSegment.upcoming;

  ProviderSubscription<bool>? _notFoundSubscription;

  /// Ekranın ViewModel'i.
  ClubDetailViewModel get viewModel =>
      ref.read(clubDetailViewModelProvider(widget.clubId).notifier);

  ClubDetailState get _state =>
      ref.read(clubDetailViewModelProvider(widget.clubId));

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    _notFoundSubscription = ref.listenManual(
      clubDetailViewModelProvider(widget.clubId).select((s) => s.isNotFound),
      (_, missing) {
        if (missing) _leaveForNotFound();
      },
      fireImmediately: true,
    );
    _applyRouteTab();
  }

  @override
  void didUpdateWidget(ClubDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != oldWidget.tab) _applyRouteTab();
  }

  @override
  void dispose() {
    _notFoundSubscription?.close();
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    scrollOffset.dispose();
    coverUnderStatusBar.dispose();
    super.dispose();
  }

  /// Üst güvenli alan şeridinin opaklığı (0–1): kapağın alt kenarı şeride
  /// yaklaşırken şerit `bg.canvas` ile dolar; şeridin altına inen içerik
  /// durum çubuğunun arkasında görünmez. Güvenli alan yoksa 0.
  double topStripOpacity(double offset, double topInset) {
    if (topInset <= 0) return 0;
    final fadeStart = GuSizes.parallaxHeight - topInset - topInset;
    return ((offset - fadeStart) / topInset).clamp(0, 1).toDouble();
  }

  /// Geri (`CLB-03.back`): yığında sayfa varsa geri, yoksa Kulüpler.
  void back() {
    if (context.canPop()) {
      context.pop();
    } else {
      const ClubsRoute().go(context);
    }
  }

  /// "Yeniden dene" (hata görünümü).
  Future<void> retry() => viewModel.fetch();

  /// Sekme seçildi (`CLB-03.tab.<ad>`).
  void selectTab(String id) =>
      viewModel.setTab(ClubDetailTab.values.byName(id));

  /// Üye sayısı satırı (`CLB-03.memberCount`) → Üyeler sekmesi.
  void openMembersTab() => viewModel.setTab(ClubDetailTab.members);

  /// "Devamı" (`CLB-03.about.more`): tanıtım metnini açar.
  void readMore() => setState(() => aboutExpanded = true);

  /// "Yaklaşan / Geçmiş" dilimi (`CLB-03.eventSeg.<dilim>`).
  void selectEventSegment(ClubEventSegment segment) =>
      setState(() => eventSegment = segment);

  /// Etkinlikler sekmesi hata görünümündeki "Yeniden dene"
  /// (`CLB-03.eventsRetry`).
  Future<void> retryEvents() => viewModel.fetchEvents();

  /// Etkinlik kartı (`CLB-03.card.<eventId>`) → EVT-02 (Etkinlikler
  /// sekmesine geçilir — Q-20).
  void openEvent(EventModel event) =>
      EventDetailRoute(eventId: event.id).go(context);

  /// Etkinlik kartının hızlı eylemi (`CLB-03.join.<eventId>`; prototip
  /// `eventQuickAction`, `cards.js:58–67`): bilet → EVT-03; bekleme
  /// listesindeyse → EVT-02; "Kulübe başvur" → bu kulübün katılım akışı;
  /// "Kayıtlar kapalı" → TST-X2; "Katıl" / "Bekleme listesine katıl" → rotanın
  /// verdiği akış (SHT-12 / DLG-15, `ClubDetailView.eventJoinFlow`; yoksa
  /// EVT-02). Akış katılımı değiştirdiyse sekme yeniden okunur.
  Future<void> onEventQuickAction(EventModel event, EventCtaKind kind) async {
    switch (kind) {
      case EventCtaKind.ticket:
        TicketRoute(eventId: event.id).go(context);
      case EventCtaKind.waitlist:
        openEvent(event);
      case EventCtaKind.applyClub:
        await join();
      case EventCtaKind.closed:
        viewModel.showRegistrationClosed();
      case EventCtaKind.join:
      case EventCtaKind.joinWaitlist:
        final flow = widget.eventJoinFlow;
        if (flow == null) {
          openEvent(event);
          return;
        }
        final changed = await flow(context, event, kind);
        if (changed && mounted) await viewModel.fetchEvents();
    }
  }

  /// "Katıl" (`CLB-03.join.<clubId>`).
  Future<void> join() async {
    final outcome = await viewModel.startJoin(
      formatDate: formatDate,
      onOpenClub: _openClub,
    );
    if (!mounted) return;
    switch (outcome) {
      case JoinOutcome.needsApplication:
        await _openApplication();
      case JoinOutcome.waiting:
        openStatus();
      case JoinOutcome.joined:
      case JoinOutcome.cooldown:
      case JoinOutcome.closed:
      case JoinOutcome.failed:
        break;
    }
  }

  /// Devre dışı "Başvurular kapalı" düğmesi → TST-X1.
  void showClosed() => viewModel.showApplicationsClosed();

  /// Başvuru durumu (`CLB-03.status.<clubId>`) → CLB-05.
  void openStatus() => ClubApplicationRoute(clubId: widget.clubId).go(context);

  /// Paylaş (`CLB-03.share`): SHT-15 → seçilen yol ViewModel'de uygulanır.
  Future<void> openShare() async {
    final club = _state.club;
    if (club == null) return;
    final choice = await _feedback.showSheet<ShareChoice>(
      SheetId.sht15,
      builder: (_) => ShareSheet(title: club.name, url: viewModel.shareUrl()),
    );
    if (choice == null || !mounted) return;
    await viewModel.share(choice);
  }

  /// Menü (`CLB-03.menu`): SHT-06 → seçilen satırın eylemi.
  Future<void> openMenu() async {
    final club = _state.club;
    if (club == null) return;
    final action = await _feedback.showSheet<ClubMenuAction>(
      SheetId.sht06,
      builder: (_) => ClubMenuSheet(clubId: club.id, clubName: club.name),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case ClubMenuAction.notifications:
        await _feedback.showSheet<void>(
          SheetId.sht07,
          builder: (_) =>
              ClubNotificationSheet(clubId: club.id, clubName: club.name),
        );
      case ClubMenuAction.share:
        await openShare();
      case ClubMenuAction.members:
        openAllMembers();
      case ClubMenuAction.report:
        await openReport();
      case ClubMenuAction.settings:
        openSettings();
      case ClubMenuAction.leave:
        await leave();
    }
  }

  /// "Bu kulübü şikayet et" (`CLB-03.report`): SHT-10 → yazım → DLG-12.
  Future<void> openReport() async {
    final report = await _feedback.showSheet<ReportReasonResult>(
      SheetId.sht10,
      builder: (_) => ReportReasonSheet(
        target: viewModel.reportTarget,
        onSubmit: viewModel.submitReport,
      ),
    );
    if (report == null || !mounted) return;
    await viewModel.showReportReceived();
  }

  /// "Kulüpten ayrıl" (SHT-06): DLG-08 / DLG-09 ViewModel'dedir. DLG-09
  /// "Başkanlığı devret" → SHT-25 → DLG-21 (W-14; `dialogs.js:25`).
  Future<void> leave() async {
    final outcome = await viewModel.leave();
    if (!mounted || outcome != LeaveOutcome.transferRequested) return;
    await viewModel.transferPresidencyForLeave();
  }

  /// E-posta satırı (`CLB-03.about.link.email`).
  void openEmail() => unawaited(viewModel.openEmail());

  /// Instagram satırı (`CLB-03.about.link.instagram`).
  void openInstagram() => unawaited(viewModel.openInstagram());

  /// Web sitesi satırı (`CLB-03.about.link.web`).
  void openWeb() => unawaited(viewModel.openWeb());

  /// Kişi satırı (`CLB-03.about.person.<userId>`, `CLB-03.member.<userId>`)
  /// → CLB-07; kulüp bağlamı `?clubId=` ile taşınır.
  void openPerson(String userId) =>
      ClubUserProfileRoute(userId: userId, clubId: widget.clubId).go(context);

  /// "Tüm üyeler" (`CLB-03.allMembers`, SHT-06 "Üyeler") → CLB-06.
  void openAllMembers() => ClubMembersRoute(clubId: widget.clubId).go(context);

  /// "Yönetim" / "Yönetimi görüntüle" (`CLB-03.openManage`) → MGT-01.
  void openManage() => ManageRoute(clubId: widget.clubId).go(context);

  /// "Etkinlik oluştur" (`CLB-03.createEvent`) → MGT-05.
  void createEvent() => EventFormRoute(clubId: widget.clubId).go(context);

  /// "Kulüp ayarları" (SHT-06) → MGT-09.
  void openSettings() {
    // TODO(T-36): `ClubSettingsRoute(clubId: widget.clubId)` (MGT-09; W-13).
  }

  /// [instant] anının yerel ayara göre tarihi (`12 Ekim 2026`): bekleme notu
  /// ve TST-X4.
  String formatDate(DateTime instant) => AppDateFormats(
    Locale(context.l10n.localeName),
    ref.read(appClockProvider),
  ).date(instant);

  /// TST-34 "Kulübe git".
  void _openClub() {
    if (mounted) ClubDetailRoute(clubId: widget.clubId).go(context);
  }

  /// SHT-05: başvuru yazıldıysa CLB-04'e gidilir; onaysız kulüpte katılımla
  /// kapandıysa TST-34 gösterilir.
  Future<void> _openApplication() async {
    final outcome = await _feedback.showSheet<JoinApplicationOutcome>(
      SheetId.sht05,
      builder: (_) => JoinApplicationSheet(clubId: widget.clubId),
    );
    if (!mounted) return;
    if (outcome == JoinApplicationOutcome.applied) {
      ClubAppliedRoute(clubId: widget.clubId).go(context);
    } else if (outcome == JoinApplicationOutcome.joined) {
      viewModel.showJoined(onOpenClub: _openClub);
    }
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final offset = scrollController.offset;
    scrollOffset.value = offset < 0 ? 0 : offset;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    coverUnderStatusBar.value =
        scrollOffset.value < GuSizes.parallaxHeight - topInset;
  }

  /// Rotadaki `?tab=` sekmesini ilk kareden sonra uygular (yapım sırasında
  /// sağlayıcı değiştirilmez).
  void _applyRouteTab() {
    final tab = widget.tab;
    if (tab == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) viewModel.setTab(tab);
    });
  }

  /// Kulüp yok / silinmiş → SYS-04 (yapım bittikten sonra).
  void _leaveForNotFound() {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) const NotFoundRoute().go(context);
      })
      ..ensureVisualUpdate();
  }
}
