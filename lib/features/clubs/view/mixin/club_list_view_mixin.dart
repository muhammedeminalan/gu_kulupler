import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/clubs/provider/club_filters.dart';
import 'package:gu_kulupler/features/clubs/provider/club_list_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/join_application_state.dart';
import 'package:gu_kulupler/features/clubs/view/club_list_view.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_filter_sheet.dart';
import 'package:gu_kulupler/features/clubs/view/widget/join_application_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/mixin/club_join_mixin.dart'
    show JoinOutcome;
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-01 davranışı: kaydırma (başa dön, "Keşfet"), arama ve süzgeç girişi,
/// kategori / görünüm seçimi, katılım akışı ve gezinme.
///
/// * Etkin sekmeye yeniden dokunma (`scrollTopRequestProvider`, PLAN §13.2)
///   listeyi başa kaydırır.
/// * SHT-04 ve SHT-05 buradan açılır (`FeedbackService`); toast'ları
///   ViewModel gösterir.
/// * "Katıl": ViewModel hangi yolun gerektiğini söyler — SHT-05 (başvuru)
///   → CLB-04, bekleme → CLB-05, onaysız kulüp → doğrudan katılım (TST-34).
/// * "Tümü" (PRF-03) anahtarıyla yerindedir; hedef ekranın task'ında
///   bağlanır (bağlama borcu W-18, T-27).
mixin ClubListViewMixin on ConsumerState<ClubListView> {
  /// Sayfanın kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  /// "Keşfet"in kaydırdığı yer: kategori şeridi (kulüp listesinin başı).
  final GlobalKey listAnchorKey = GlobalKey();

  ProviderSubscription<int>? _scrollTopSubscription;

  /// Ekranın ViewModel'i.
  ClubListViewModel get viewModel =>
      ref.read(clubListViewModelProvider.notifier);

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  Duration get _scrollDuration =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : GuMotion.base;

  @override
  void initState() {
    super.initState();
    _scrollTopSubscription = ref.listenManual(
      scrollTopRequestProvider(GuTab.clubs),
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

  /// Ara (`CLB-01.search`) → CLB-02.
  void openSearch() => const ClubsSearchRoute().go(context);

  /// "Filtre / Sırala" (`CLB-01.filter`): SHT-04 → "Sonuçları göster" ile
  /// dönen süzgeç uygulanır; kapatılırsa değişiklik yok.
  Future<void> openFilters() async {
    final initial = ref.read(clubListViewModelProvider).filters;
    final result = await _feedback.showSheet<ClubFilters>(
      SheetId.sht04,
      builder: (_) =>
          ClubFilterSheet(initial: initial, countFor: viewModel.countFor),
    );
    if (result == null || !mounted) return;
    viewModel.setFilters(result);
  }

  /// Kategori çipi (`CLB-01.category.<id>`; `null` = "Tümü").
  void selectCategory(String? categoryId) => viewModel.setCategory(categoryId);

  /// Liste ↔ ızgara (`CLB-01.toggleView`).
  void toggleView() => viewModel.toggleLayout();

  /// "Filtreleri temizle" (`CLB-01.clearFilters`).
  void clearFilters() => viewModel.clearFilters();

  /// "Yeniden dene" (`CLB-01.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Çek-yenile (`CLB-01.refresh`).
  Future<void> refresh() => viewModel.refresh();

  /// "Keşfet" (`CLB-01.discover`): kulüp listesinin başına kaydırır
  /// (`screens-clubs.js:26`).
  void discover() {
    final anchor = listAnchorKey.currentContext;
    if (anchor == null) return;
    unawaited(
      Scrollable.ensureVisible(
        anchor,
        duration: _scrollDuration,
        curve: GuMotion.easeStandard,
      ),
    );
  }

  /// "Kulüplerim → Tümü" (`CLB-01.myClubsAll`) → PRF-03.
  void openMyClubsAll() {
    // TODO(T-27): `MyClubsRoute()` (PRF-03; W-18).
  }

  /// Kart, "Aç" ve "Kulüplerim" kartı (`CLB-01.card.<clubId>`,
  /// `.open.<clubId>`, `.myClub.<clubId>`) → CLB-03.
  void openClub(String clubId) {
    if (mounted) ClubDetailRoute(clubId: clubId).go(context);
  }

  /// Başvuru durumu (`CLB-01.status.<clubId>`) → CLB-05.
  void openStatus(String clubId) =>
      ClubApplicationRoute(clubId: clubId).go(context);

  /// Devre dışı "Başvurular kapalı" düğmesi → TST-X1.
  void showClosed() => viewModel.showApplicationsClosed();

  /// "Katıl" (`CLB-01.join.<clubId>`).
  Future<void> join(String clubId) async {
    final outcome = await viewModel.join(
      clubId,
      formatDate: formatDate,
      onOpenClub: () => openClub(clubId),
    );
    if (!mounted) return;
    switch (outcome) {
      case JoinOutcome.needsApplication:
        await _openApplication(clubId);
      case JoinOutcome.waiting:
        openStatus(clubId);
      case JoinOutcome.joined:
      case JoinOutcome.cooldown:
      case JoinOutcome.closed:
      case JoinOutcome.failed:
        break;
    }
  }

  /// [instant] anının yerel ayara göre tarihi (`12 Ekim 2026`): TST-X4.
  String formatDate(DateTime instant) => AppDateFormats(
    Locale(context.l10n.localeName),
    ref.read(appClockProvider),
  ).date(instant);

  /// SHT-05: başvuru yazıldıysa CLB-04'e gidilir; onaysız kulüpte katılımla
  /// kapandıysa TST-34 gösterilir.
  Future<void> _openApplication(String clubId) async {
    final outcome = await _feedback.showSheet<JoinApplicationOutcome>(
      SheetId.sht05,
      builder: (_) => JoinApplicationSheet(clubId: clubId),
    );
    if (!mounted) return;
    if (outcome == JoinApplicationOutcome.applied) {
      ClubAppliedRoute(clubId: clubId).go(context);
    } else if (outcome == JoinApplicationOutcome.joined) {
      viewModel.showJoined(onOpenClub: () => openClub(clubId));
    }
  }
}
