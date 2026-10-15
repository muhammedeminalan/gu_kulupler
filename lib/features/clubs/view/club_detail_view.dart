import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/clubs/provider/club_detail_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_detail_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/mixin/club_detail_view_mixin.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_about_tab.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_detail_cta_bar.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_events_tab.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_feed_tab.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_header.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_locked_tab.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_members_tab.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/media/club_media_image.dart';
import 'package:gu_kulupler/product/navigation/club_detail_tab.dart';
import 'package:gu_kulupler/product/widget/club/club_cta.dart';
import 'package:gu_kulupler/product/widget/event/event_cta.dart';
import 'package:gu_ui/gu_ui.dart';

/// Kulüp ekranı — `ClubDetailRoute` (`/clubs/:clubId?tab=`); prototip
/// `ClubDetail` (`screens-clubs.js:77–112`).
///
/// Yukarıdan aşağıya tek kaydırma alanı: parallax kapak + üst çubuk (geri ·
/// paylaş · menü), durum bantları, amblem, ad, rozetler, üye sayısı
/// (`ClubHeader`) · yapışkan sekme çubuğu (Hakkında / Etkinlikler /
/// Gönderiler / Üyeler) · sekme gövdesi. Altta kullanıcının kipine göre eylem
/// çubuğu (`ClubDetailCtaBar`).
///
/// * Durumlar (sıra: hata → yükleniyor → dolu): kulüp okunamadıysa başlık
///   çubuğu + "Bir şeyler ters gitti" + "Yeniden dene"; okunurken başlık
///   çubuğu + iskelet; kulüp yoksa / silinmişse SYS-04'e gidilir. Çevrimdışı
///   bandı kökte çizilir; içerik ekranda kalır, yazan eylemler TST-24 verir.
/// * Kip görünümleri (`ClubAccess`): ziyaretçi / bekleyen / reddedilen /
///   çıkarılan → alt çubukta `ClubCta`; "Gönderiler" ve "Üyeler" kilitli.
///   Üye → çubuk yok, rol rozeti. Yönetici ve süper admin → "Yönetim" +
///   "Etkinlik oluştur". Danışman → salt okunur bandı + "Yönetimi
///   görüntüle". Askıdaki kulüp → uyarı bandı, çubuk yok.
/// * Kapak durum çubuğunun altına uzanır: durum çubuğu açık ikonludur
///   (D-20); kapak yukarı kayınca tema stiline döner ve üst güvenli alan
///   `bg.canvas` şeridiyle kapanır — yapışkan sekmeler şeridin altında durur
///   (prototipteki sahte durum çubuğu yerine gerçek güvenli alan, K-07).
/// * Kaydırma alt dolgusu: çubuk yoksa alt güvenli alan; çubuk varsa güvenli
///   alanı çubuk taşır.
///
/// Davranış `ClubDetailViewMixin`'dedir.
///
/// Design: CLB-03
class ClubDetailView extends ConsumerStatefulWidget {
  /// [clubId] kulübünün sayfası; [tab] ilk açılan sekmedir (`?tab=`).
  const ClubDetailView({
    required this.clubId,
    this.tab,
    this.commentsSheetBuilder,
    this.eventJoinFlow,
    super.key,
  });

  /// Kulüp kimliği (`ClubDetailRoute.clubId`).
  final String clubId;

  /// İlk açılan sekme; `null` → hakkında.
  final ClubDetailTab? tab;

  /// "Gönderiler" sekmesindeki yorum sayfasının (SHT-09) gövdesi. Sayfa
  /// `features/feed` altındadır ve feature'lar birbirini içe aktaramaz;
  /// gövdeyi rota (kompozisyon kökü) verir (`ClubFeedTab`'a aktarılır).
  final Widget Function(String clubId, String postId)? commentsSheetBuilder;

  /// "Etkinlikler" sekmesindeki kartın "Katıl" (SHT-12) / "Bekleme listesine
  /// katıl" (DLG-15) akışı. Akış `features/events` altındadır (katılım
  /// yazımı + hatırlatıcı) ve feature'lar birbirini içe aktaramaz; rota
  /// (kompozisyon kökü) verir. `null` → etkinlik sayfası (EVT-02) açılır,
  /// katılım orada yapılır.
  final EventJoinFlow? eventJoinFlow;

  @override
  ConsumerState<ClubDetailView> createState() => _ClubDetailViewState();
}

/// CLB-03 etkinlik kartından katılım akışı: [kind] `join` (SHT-12) ya da
/// `joinWaitlist` (DLG-15). `true` → katılım kaydı değişti (sekme yeniden
/// okunur).
typedef EventJoinFlow =
    Future<bool> Function(
      BuildContext context,
      EventModel event,
      EventCtaKind kind,
    );

class _ClubDetailViewState extends ConsumerState<ClubDetailView>
    with ClubDetailViewMixin {
  /// Yükleniyor iskeletindeki kart sayısı (prototip `ListState n=3`,
  /// `screens-clubs.js:104`).
  static const int _skeletonCards = 3;

  /// `ClubCta`: alt çubukta büyük + tam genişlik, kilitli blokta orta boy.
  /// Aynı anahtarlar iki yerde de kullanılır (`cards.js:22–25`).
  Widget _cta(ClubDetailState state, {required bool inBar}) {
    final club = state.club!;
    return ClubCta(
      club: club,
      access: state.access,
      membershipStatus: state.membership?.status,
      size: inBar ? GuButtonSize.lg : GuButtonSize.md,
      full: inBar,
      joinKey: GuKey.action('CLB-03.join.${club.id}'),
      statusKey: GuKey.action('CLB-03.status.${club.id}'),
      onJoin: join,
      onClosedTap: showClosed,
      onStatus: openStatus,
      // Kulübün içini gören kipler bu ekranda `ClubCta` çizmez.
      onOpen: () {},
    );
  }

  /// Seçili sekmenin gövdesi — sliver: "Gönderiler" akışı kendi sliver
  /// grubudur (kartlar tembel kurulur, T-44); öteki sekmeler kutudur.
  Widget _tabBody(ClubDetailState state) {
    final l10n = context.l10n;
    final club = state.club!;
    if (state.tab == ClubDetailTab.posts && state.seesInside) {
      return ClubFeedTab(
        clubId: club.id,
        commentsSheetBuilder: widget.commentsSheetBuilder,
      );
    }
    return SliverToBoxAdapter(child: _boxTabBody(state, l10n, club));
  }

  Widget _boxTabBody(
    ClubDetailState state,
    AppLocalizations l10n,
    ClubModel club,
  ) {
    return switch (state.tab) {
      ClubDetailTab.about => ClubAboutTab(
        club: club,
        managers: state.managers,
        expanded: aboutExpanded,
        onReadMore: readMore,
        onEmail: openEmail,
        onInstagram: openInstagram,
        onWeb: openWeb,
        onPerson: openPerson,
        onReport: openReport,
        personKeyOf: (userId) => GuKey.action('CLB-03.about.person.$userId'),
        readMoreKey: GuKey.action('CLB-03.about.more'),
        emailKey: GuKey.action('CLB-03.about.link.email'),
        instagramKey: GuKey.action('CLB-03.about.link.instagram'),
        webKey: GuKey.action('CLB-03.about.link.web'),
        reportKey: GuKey.action('CLB-03.report'),
      ),
      ClubDetailTab.events => ClubEventsTab(
        events: state.events,
        club: club,
        rsvps: state.rsvps,
        nowUtc: ref.watch(appClockProvider).nowUtc(),
        isFetching: state.isEventsFetching,
        isError: state.isEventsError,
        segment: eventSegment,
        onSegmentChanged: selectEventSegment,
        seesInside: state.seesInside,
        onRetry: retryEvents,
        onEvent: openEvent,
        onQuickAction: onEventQuickAction,
        segmentKeyOf: (segment) =>
            GuKey.action('CLB-03.eventSeg.${segment.name}'),
        cardKeyOf: (eventId) => GuKey.action('CLB-03.card.$eventId'),
        joinKeyOf: (eventId) => GuKey.action('CLB-03.join.$eventId'),
        retryKey: GuKey.action('CLB-03.eventsRetry'),
      ),
      // İçini görene akış [_tabBody]'de sliver olarak çizilir.
      ClubDetailTab.posts => ClubLockedTab(
        text: l10n.clubPostsLocked,
        cta: _cta(state, inBar: false),
      ),
      ClubDetailTab.members =>
        state.seesInside
            ? ClubMembersTab(
                memberCount: club.memberCount,
                members: state.memberPreview,
                onMember: openPerson,
                onAllMembers: openAllMembers,
                memberKeyOf: (userId) => GuKey.action('CLB-03.member.$userId'),
                allMembersKey: GuKey.action('CLB-03.allMembers'),
              )
            : ClubLockedTab(
                text: l10n.clubMembersLocked(club.memberCount),
                cta: _cta(state, inBar: false),
              ),
    };
  }

  String _tabLabel(ClubDetailTab tab) {
    final l10n = context.l10n;
    return switch (tab) {
      ClubDetailTab.about => l10n.clubTabAbout,
      ClubDetailTab.events => l10n.clubTabEvents,
      ClubDetailTab.posts => l10n.clubTabPosts,
      ClubDetailTab.members => l10n.clubTabMembers,
    };
  }

  /// Hata ve yükleniyor görünümlerinin kabuğu: başlık çubuğu + gövde.
  Widget _pending({required Widget body}) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.clubTitle,
        onBack: back,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('CLB-03.back'),
      ),
      body: SafeArea(top: false, child: body),
    );
  }

  Widget _loaded(ClubDetailState state) {
    final gu = context.gu;
    final colors = gu.colors;
    final club = state.club!;
    final media = MediaQuery.of(context);
    final topInset = media.viewPadding.top;
    final hasBar = ClubDetailCtaBar.hasBar(state);
    final retryAfter = state.retryAfterAt(ref.watch(appClockProvider).nowUtc());

    final page = Scaffold(
      backgroundColor: colors.bgCanvas,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                // Üst güvenli alan şeridi: kapak görünürken saydam (kapak
                // arkasından görünür), kapak çıkınca `bg.canvas`. Yapışkan
                // sekmeler bu şeridin altına sabitlenir.
                PinnedHeaderSliver(
                  child: ValueListenableBuilder<double>(
                    valueListenable: scrollOffset,
                    builder: (context, offset, child) => Opacity(
                      opacity: topStripOpacity(offset, topInset),
                      child: child,
                    ),
                    // Şerit dokunmayı yutmaz: altındaki kapak düğmeleri
                    // güvenli alanın 4 dp üstünden başlar.
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: colors.bgCanvas,
                        child: SizedBox(
                          height: topInset,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ClubHeader(
                    club: club,
                    scrollOffset: scrollOffset,
                    role: state.activeRole,
                    isAdvisor: state.access == ClubAccess.advisor,
                    memberPreview: state.memberPreview,
                    coverImage: ref.clubCoverImage(club),
                    logoImage: ref.clubLogoImage(
                      club,
                      displaySize: GuEmblemSize.lg.dimension,
                    ),
                    onBack: back,
                    onShare: openShare,
                    onMenu: openMenu,
                    onMemberCount: openMembersTab,
                    backKey: GuKey.action('CLB-03.back'),
                    shareKey: GuKey.action('CLB-03.share'),
                    menuKey: GuKey.action('CLB-03.menu'),
                    memberCountKey: GuKey.action('CLB-03.memberCount'),
                  ),
                ),
                const SliverToBoxAdapter(child: GuGap.v16),
                GuTabs(
                  sticky: true,
                  tabs: [
                    for (final tab in ClubDetailTab.values)
                      GuTabItem(id: tab.name, label: _tabLabel(tab)),
                  ],
                  value: state.tab.name,
                  onChanged: selectTab,
                  tabKeyBuilder: (index) => GuKey.action(
                    'CLB-03.tab.${ClubDetailTab.values[index].name}',
                  ),
                ),
                _tabBody(state),
                if (!hasBar)
                  SliverToBoxAdapter(
                    child: SizedBox(height: media.viewPadding.bottom),
                  ),
              ],
            ),
          ),
          if (hasBar)
            ClubDetailCtaBar(
              state: state,
              cta: _cta(state, inBar: true),
              retryNote: retryAfter == null
                  ? null
                  : context.l10n.applicationRetryAt(formatDate(retryAfter)),
              onManage: openManage,
              onCreateEvent: createEvent,
              manageKey: GuKey.action('CLB-03.openManage'),
              createEventKey: GuKey.action('CLB-03.createEvent'),
            ),
        ],
      ),
    );

    return ValueListenableBuilder<bool>(
      valueListenable: coverUnderStatusBar,
      builder: (context, underCover, child) => GuSystemUi(
        style: underCover ? GuSystemUiStyle.lightIcons : GuSystemUiStyle.auto,
        child: child!,
      ),
      child: page,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(clubDetailViewModelProvider(widget.clubId));

    if (state.isError && state.club == null) {
      return _pending(
        body: Center(
          child: SingleChildScrollView(
            child: GuErrorState(
              title: l10n.sysErrorTitle,
              description: l10n.sysErrorDesc,
              retryLabel: l10n.commonRetry,
              onRetry: retry,
            ),
          ),
        ),
      );
    }
    if (state.club != null) return _loaded(state);
    // Kulüp yoksa SYS-04'e gidilir; geçiş karesinde boş zemin kalır.
    return _pending(
      body: state.isNotFound
          ? const SizedBox.expand()
          : SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: GuSkeletonList(
                semanticLabel: l10n.commonLoading,
                count: _skeletonCards,
                variant: GuSkeletonVariant.card,
              ),
            ),
    );
  }
}
