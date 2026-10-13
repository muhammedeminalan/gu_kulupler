import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/search/provider/search_state.dart';
import 'package:gu_kulupler/features/search/provider/search_view_model.dart';
import 'package:gu_kulupler/features/search/view/search_view.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/mixin/club_join_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';

/// CLB-02 davranışı: sorgu, sekme, son aramalar, katılım akışı ve gezinme.
///
/// * Kategori adları ekranın dilinde ViewModel'e verilir (kulüp araması
///   kategori adını da tarar); dil değişince yenilenir.
/// * Toast'ları ViewModel gösterir (TST-06, TST-34, TST-X1, TST-24 …).
/// * "Katıl": ViewModel hangi yolun gerektiğini söyler — SHT-05 (başvuru)
///   → CLB-04, bekleme → CLB-05, onaysız kulüp → doğrudan katılım (TST-34).
/// * Hedefi henüz yazılmamış giriş (etkinlik sonucu → EVT-02) anahtarıyla
///   yerindedir; T-23'te bağlanır.
mixin SearchViewMixin on ConsumerState<SearchView> {
  Locale? _labelsLocale;

  /// Ekranın ViewModel'i (rotanın başlangıç sekmesi başına bir örnek).
  SearchViewModel get viewModel =>
      ref.read(searchViewModelProvider(widget.scope).notifier);

  SearchState get _state => ref.read(searchViewModelProvider(widget.scope));

  /// Tarih / saat biçimleri (etkinlik sonucu satırı).
  AppDateFormats get dateFormats => AppDateFormats(
    Locale(context.l10n.localeName),
    ref.read(appClockProvider),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (locale == _labelsLocale) return;
    _labelsLocale = locale;
    final labels = {
      for (final category in StaticTables.categories)
        category.id: StaticLabels.category(context, category.id),
    };
    // Yapım sırasında sağlayıcı değiştirilmez: ilk kareden sonra.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) viewModel.setCategoryLabels(labels);
    });
  }

  /// "İptal" (`CLB-02.cancel`): yığında sayfa varsa geri, yoksa ekranı açan
  /// sekmenin kökü.
  void cancel() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    switch (widget.scope) {
      case SearchScope.clubs:
        const ClubsRoute().go(context);
      case SearchScope.events:
        const EventsRoute().go(context);
    }
  }

  /// Arama alanı değişti (`CLB-02.input`).
  void onQueryChanged(String value) => viewModel.setQuery(value);

  /// Arama alanı temizlendi (`CLB-02.clear`).
  void clearQuery() => viewModel.setQuery('');

  /// Klavyede "Ara": terim son aramalara yazılır.
  void submit() => unawaited(viewModel.commitRecent(_state.query));

  /// Son arama (`CLB-02.recent.<i>`), popüler arama (`CLB-02.popular.<i>`)
  /// ya da öneri çipi (`CLB-02.suggest.<i>`): terim arama alanına yazılır.
  void pickTerm(String term) => viewModel.setQuery(term);

  /// "Kaldır" (`CLB-02.removeRecent.<i>`).
  void removeRecent(String term) => unawaited(viewModel.removeRecent(term));

  /// "Temizle" (`CLB-02.clearRecent`) → TST-06 ("Geri al").
  void clearRecent() => unawaited(viewModel.clearRecent());

  /// Sekme seçildi (`CLB-02.tab.<ad>`).
  void selectTab(String id) =>
      viewModel.setScope(SearchScope.values.byName(id));

  /// "Yeniden dene" (hata görünümü, `CLB-02.retry`).
  Future<void> retry() => viewModel.loadPools();

  /// Kulüp kartı / "Aç" (`CLB-02.card.<clubId>`, `CLB-02.open.<clubId>`) →
  /// CLB-03.
  void openClub(String clubId) => ClubDetailRoute(clubId: clubId).go(context);

  /// Başvuru durumu (`CLB-02.status.<clubId>`) → CLB-05.
  void openStatus(String clubId) =>
      ClubApplicationRoute(clubId: clubId).go(context);

  /// "Katıl" (`CLB-02.join.<clubId>`).
  Future<void> join(ClubModel club) async {
    final outcome = await viewModel.join(
      club.id,
      formatDate: formatDate,
      onOpenClub: () {
        if (mounted) openClub(club.id);
      },
    );
    if (!mounted) return;
    switch (outcome) {
      case JoinOutcome.needsApplication:
        await _openApplication(club.id);
      case JoinOutcome.waiting:
        openStatus(club.id);
      case JoinOutcome.joined:
      case JoinOutcome.cooldown:
      case JoinOutcome.closed:
      case JoinOutcome.failed:
        break;
    }
  }

  /// SHT-05: başvuru yazıldıysa CLB-04'e gidilir; onaysız kulüpte katılımla
  /// kapandıysa TST-34 gösterilir. Gövdeyi rota verir
  /// (`SearchView.applicationSheetBuilder`); yoksa kulüp sayfası açılır.
  Future<void> _openApplication(String clubId) async {
    final builder = widget.applicationSheetBuilder;
    if (builder == null) {
      openClub(clubId);
      return;
    }
    final outcome = await ref
        .read(feedbackServiceProvider)
        .showSheet<JoinApplicationOutcome>(
          SheetId.sht05,
          builder: (_) => builder(clubId),
        );
    if (!mounted) return;
    if (outcome == JoinApplicationOutcome.applied) {
      ClubAppliedRoute(clubId: clubId).go(context);
    } else if (outcome == JoinApplicationOutcome.joined) {
      viewModel.showJoined(
        clubId,
        onOpenClub: () {
          if (mounted) openClub(clubId);
        },
      );
    }
  }

  /// Devre dışı "Başvurular kapalı" düğmesi → TST-X1.
  void showClosed() => viewModel.showApplicationsClosed();

  /// Kulüp sonucu (`CLB-02.result.club.<clubId>`): terim son aramalara
  /// yazılır, kulüp açılır (CLB-03).
  void openClubResult(ClubModel club) {
    submit();
    openClub(club.id);
  }

  /// Etkinlik sonucu (`CLB-02.result.event.<eventId>`): terim son aramalara
  /// yazılır, etkinlik açılır (EVT-02).
  void openEventResult(EventModel event) {
    submit();
    // TODO(T-23): `EventDetailRoute(eventId: event.id).go(context)` (EVT-02;
    // bağlama borcu "CLB-02 etkinlik sonuçları → EVT-02").
  }

  /// [instant] anının yerel ayara göre tarihi (`12 Ekim 2026`): TST-X4.
  String formatDate(DateTime instant) => dateFormats.date(instant);
}
