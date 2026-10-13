import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_provider_mixin.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/search/provider/search_scope.dart';
import 'package:gu_kulupler/features/search/provider/search_state.dart';
import 'package:gu_kulupler/features/search/provider/search_view_model.dart';
import 'package:gu_kulupler/features/search/view/mixin/search_view_mixin.dart';
import 'package:gu_kulupler/features/search/view/widget/recent_searches_section.dart';
import 'package:gu_kulupler/features/search/view/widget/search_result_section.dart';
import 'package:gu_kulupler/product/widget/club/club_card.dart';
import 'package:gu_ui/gu_ui.dart';

export 'package:gu_kulupler/features/search/provider/search_scope.dart'
    show SearchScope;

/// "Arama" ekranı — paylaşılan yaprak (PLAN §13.9): `ClubsSearchRoute`
/// (`/clubs/search`) ve `EventsSearchRoute` (`/events/search`) aynı view'ı
/// açar; [scope] yalnızca başlangıç sekmesini seçer. Prototip `S['CLB-02']`
/// (`screens-clubs.js:37–55`).
///
/// Yukarıdan aşağıya: arama çubuğu (alan otomatik odaklı, min 44 · "İptal")
/// · sekmeler (Kulüpler / Etkinlikler) · kaydırma alanı. Başlık çubuğu
/// yoktur.
///
/// * Terim boşken: "Son aramalar" (varsa; "Temizle" → TST-06 + Geri al) ·
///   "Popüler aramalar" çipleri · Kulüpler sekmesinde "Sizin için önerilen
///   kulüpler" (üç `ClubCard`, liste varyantı).
/// * Terim doluyken (sıra: hata → yükleniyor → boş → dolu): havuz
///   okunamadıysa "Bir şeyler ters gitti" + "Yeniden dene"; sorgu bekleme
///   süresindeyken ya da havuz okunurken üç satır iskelet; eşleşme yoksa
///   "sonuç yok" bloğu; varsa sonuç satırları (`SearchResultSection`).
/// * Önerilen kulüpler bölümü kendi durumunu taşır: havuz okunurken kart
///   iskeleti, okunamadıysa satır içi hata, öneri yoksa bölüm çizilmez.
/// * Çevrimdışı bandı kökte çizilir; içerik ekranda kalır, "Katıl" TST-24
///   verir.
/// * Etkinlik sonuçları T-23'te dolar (`EventRepository` yok): sekme ve satır
///   yerindedir, eşleşme her zaman boştur.
///
/// Davranış `SearchViewMixin`'dedir.
///
/// Design: CLB-02
class SearchView extends ConsumerStatefulWidget {
  /// [scope] sekmesiyle açılan arama.
  const SearchView({
    required this.scope,
    this.applicationSheetBuilder,
    super.key,
  });

  /// Başlangıç sekmesi (kulüpler / etkinlikler).
  final SearchScope scope;

  /// SHT-05 "Katılma başvurusu" formunun gövdesi (`clubId` → sheet). Form
  /// `features/clubs` altındadır ve feature'lar birbirini içe aktaramaz;
  /// gövdeyi rota (kompozisyon kökü) verir. Verilmezse onay gereken kulüpte
  /// "Katıl" kulüp sayfasına (CLB-03) gider.
  final Widget Function(String clubId)? applicationSheetBuilder;

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<SearchView>
    with AppProviderMixin, SearchViewMixin {
  /// Sonuç beklenirken çizilen iskelet satırı sayısı (prototip
  /// `SkeletonList n=3`, `screens-clubs.js:51`).
  static const int _skeletonRows = 3;

  String _tabLabel(SearchScope scope) {
    final l10n = context.l10n;
    return switch (scope) {
      SearchScope.clubs => l10n.navClubs,
      SearchScope.events => l10n.navEvents,
    };
  }

  Widget _card(SearchState state, ClubModel club) => ClubCard(
    club: club,
    access: session.accessTo(club.id),
    membershipStatus: session.memberships[club.id]?.status,
    memberPreview: [
      for (final manager
          in state.managerPreviews[club.id] ?? const <MembershipModel>[])
        GuAvatarData(
          initials: manager.applicant.name.initials,
          seed: manager.applicant.avatarSeed,
        ),
    ],
    actionKey: GuKey.action('CLB-02.card.${club.id}'),
    joinKey: GuKey.action('CLB-02.join.${club.id}'),
    statusKey: GuKey.action('CLB-02.status.${club.id}'),
    openKey: GuKey.action('CLB-02.open.${club.id}'),
    onOpen: () => openClub(club.id),
    onJoin: () => unawaited(join(club)),
    onClosedTap: showClosed,
    onStatus: () => openStatus(club.id),
  );

  /// "Sizin için önerilen kulüpler": hata → iskelet → (boşsa hiçbir şey) →
  /// kartlar.
  List<Widget> _suggested(SearchState state) {
    final l10n = context.l10n;
    final Widget body;
    if (state.isError) {
      body = GuErrorState(
        title: l10n.sysErrorTitle,
        description: l10n.sysErrorDesc,
        retryLabel: l10n.commonRetry,
        onRetry: retry,
        retryActionKey: GuKey.action('CLB-02.retry'),
        inline: true,
      );
    } else if (state.isFetching) {
      body = GuSkeletonList(
        semanticLabel: l10n.commonLoading,
        count: _skeletonRows,
        variant: GuSkeletonVariant.card,
      );
    } else if (state.suggested.isEmpty) {
      return const [];
    } else {
      body = Padding(
        padding: GuInsets.h16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s12,
          children: [for (final club in state.suggested) _card(state, club)],
        ),
      );
    }
    return [GuSectionTitle(title: l10n.searchSuggested), body];
  }

  /// Terim boşken: son aramalar, popüler aramalar, önerilen kulüpler.
  Widget _defaults(SearchState state) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.recent.isNotEmpty)
          RecentSearchesSection(
            recent: state.recent,
            onPick: pickTerm,
            onRemove: removeRecent,
            onClear: clearRecent,
            clearKey: GuKey.action('CLB-02.clearRecent'),
            rowKeyOf: (index) => GuKey.action('CLB-02.recent.$index'),
            removeKeyOf: (index) => GuKey.action('CLB-02.removeRecent.$index'),
          ),
        GuSectionTitle(
          title: l10n.searchPopular,
          topMargin: state.recent.isEmpty
              ? GuSectionTitleMargin.first
              : GuSectionTitleMargin.normal,
        ),
        Padding(
          padding: GuInsets.h16,
          child: Wrap(
            spacing: GuSpacing.s8,
            runSpacing: GuSpacing.s8,
            children: [
              for (final (index, term) in state.popular.indexed)
                GuChip(
                  key: GuKey.action('CLB-02.popular.$index'),
                  icon: GuIcons.trendingUp,
                  label: term,
                  onTap: () => pickTerm(term),
                ),
            ],
          ),
        ),
        if (state.scope == SearchScope.clubs) ..._suggested(state),
      ],
    );
  }

  /// Terim doluyken: hata → iskelet → sonuçlar ("sonuç yok" dahil).
  Widget _results(SearchState state) {
    final l10n = context.l10n;
    if (state.isError) {
      return GuErrorState(
        title: l10n.sysErrorTitle,
        description: l10n.sysErrorDesc,
        retryLabel: l10n.commonRetry,
        onRetry: retry,
        retryActionKey: GuKey.action('CLB-02.retry'),
      );
    }
    if (state.isSearching || state.isFetching) {
      return GuSkeletonList(
        semanticLabel: l10n.commonLoading,
        count: _skeletonRows,
      );
    }
    return SearchResultSection(
      scope: state.scope,
      term: state.searchTerm,
      clubs: state.clubResults,
      events: state.eventResults,
      popular: state.popular,
      formats: dateFormats,
      clubNameOf: (clubId) {
        for (final club in state.clubPool) {
          if (club.id == clubId) return club.name;
        }
        return null;
      },
      onClub: openClubResult,
      onEvent: openEventResult,
      onSuggest: pickTerm,
      clubKeyOf: (clubId) => GuKey.action('CLB-02.result.club.$clubId'),
      eventKeyOf: (eventId) => GuKey.action('CLB-02.result.event.$eventId'),
      suggestKeyOf: (index) => GuKey.action('CLB-02.suggest.$index'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(searchViewModelProvider(widget.scope));
    return Scaffold(
      backgroundColor: context.gu.colors.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // `screens-clubs.js:45` `padding:4px 8px 4px 16px`, `gap4`.
            Padding(
              padding: GuInsets.only(
                left: GuSpacing.s16,
                top: GuSpacing.s4,
                right: GuSpacing.s8,
                bottom: GuSpacing.s4,
              ),
              child: Row(
                spacing: GuSpacing.s4,
                children: [
                  Expanded(
                    child: GuSearchField(
                      value: state.query,
                      onChanged: onQueryChanged,
                      onClear: clearQuery,
                      onSubmitted: submit,
                      placeholder: l10n.searchPlaceholder,
                      semanticLabel: l10n.commonSearch,
                      clearSemanticLabel: l10n.commonClear,
                      compact: true,
                      autofocus: true,
                      actionKey: GuKey.action('CLB-02.input'),
                      clearKey: GuKey.action('CLB-02.clear'),
                    ),
                  ),
                  GuButton(
                    key: GuKey.action('CLB-02.cancel'),
                    label: l10n.commonCancel,
                    onPressed: cancel,
                    variant: GuButtonVariant.text,
                  ),
                ],
              ),
            ),
            GuTabs(
              tabs: [
                for (final scope in SearchScope.values)
                  GuTabItem(id: scope.name, label: _tabLabel(scope)),
              ],
              value: state.scope.name,
              onChanged: selectTab,
              tabKeyBuilder: (index) => GuKey.action(
                'CLB-02.tab.${SearchScope.values[index].name}',
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                // css:123 `.screen-scroll{padding-bottom:calc(safe-bottom +
                // 8px)}`.
                padding: GuInsets.only(
                  bottom:
                      MediaQuery.viewPaddingOf(context).bottom + GuSpacing.s8,
                ),
                child: state.hasTerm ? _results(state) : _defaults(state),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
