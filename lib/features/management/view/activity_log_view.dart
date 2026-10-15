import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/activity_log_state.dart';
import 'package:gu_kulupler/features/management/provider/activity_log_view_model.dart';
import 'package:gu_kulupler/features/management/view/mixin/activity_log_view_mixin.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/format/relative_time_formatter.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/manage/activity_row.dart';
import 'package:gu_kulupler/product/widget/manage/activity_texts.dart';
import 'package:gu_kulupler/product/widget/manage/manage_header.dart';
import 'package:gu_kulupler/product/widget/system/offline_list_fallback.dart';
import 'package:gu_ui/gu_ui.dart';

/// Faaliyet geçmişi — `ActivityLogRoute` (`/clubs/:clubId/manage/activity`);
/// prototip `Activity` (`screens-manage.js:190–196`). MGT-01 "Son hareketler
/// → Tümü" açar (guard `V`, router'da).
///
/// Yukarıdan aşağıya: `ManageHeader` (geri · "Faaliyet geçmişi" · kulüp adı
/// · rol rozeti; danışmanda salt okunur bandı) · tür grubu çipleri (Tümü /
/// Üyelik / Etkinlik / İçerik / Ayar; şerit dolgusu 3 px — K-59) · çek-yenile
/// liste: Istanbul gün grupları (yapışkan başlık "Bugün" / "Dün" / "12 Ekim
/// Pazartesi", büyük harf yok) + `ActivityRow` satırları + liste sonu.
///
/// * Durumlar yalnızca listeyi değiştirir (sıra: hata → yükleniyor → boş →
///   dolu). Hata: "Bir şeyler ters gitti" + "Yeniden dene"; yükleniyor: 6
///   satır iskeleti; boş (süzgeçli ya da süzgeçsiz): `empty-notifications`
///   illüstrasyonu + "Henüz hareket yok" (prototip ikisini ayırmaz; çipler
///   görünür kalır). Çevrimdışı bandı kökte; liste önbellekle kalır.
/// * Kayıtlar 20'lik sayfalarla gelir; sonraki sayfa okunurken liste sonunda
///   iskelet satırları, son sayfadan sonra "Hepsi bu kadar" çizilir.
/// * Kaydırma sonu dolgusu alt güvenli alandır.
///
/// Davranış `ActivityLogViewModel` ve `ActivityLogViewMixin`'dedir.
///
/// Design: MGT-10
class ActivityLogView extends ConsumerStatefulWidget {
  /// [clubId] kulübünün faaliyet geçmişi.
  const ActivityLogView({required this.clubId, super.key});

  /// Kulüp kimliği (`ActivityLogRoute.clubId`).
  final String clubId;

  @override
  ConsumerState<ActivityLogView> createState() => _ActivityLogViewState();
}

class _ActivityLogViewState extends ConsumerState<ActivityLogView>
    with ActivityLogViewMixin {
  /// Yükleniyor iskeletindeki satır sayısı (prototip `ListState n=6`,
  /// `screens-manage.js:195`).
  static const int _skeletonRows = 6;

  /// Sonraki sayfa okunurken liste sonunda çizilen iskelet satırı sayısı.
  static const int _nextPageRows = 3;

  /// Çiplerin prototip sırası (`screens-manage.js:194`); `null` → "Tümü".
  static const List<ActivityCategory?> _filters = [
    null,
    ActivityCategory.membership,
    ActivityCategory.event,
    ActivityCategory.content,
    ActivityCategory.settings,
  ];

  static String _filterLabel(AppLocalizations l10n, ActivityCategory? c) =>
      switch (c) {
        null => l10n.commonAll,
        ActivityCategory.membership => l10n.activityCatMembership,
        ActivityCategory.event => l10n.activityCatEvent,
        ActivityCategory.content => l10n.activityCatContent,
        ActivityCategory.settings => l10n.activityCatSettings,
      };

  static Key _filterKey(ActivityCategory? c) => switch (c) {
    null => GuKey.action('MGT-10.filter.all'),
    ActivityCategory.membership => GuKey.action('MGT-10.filter.membership'),
    ActivityCategory.event => GuKey.action('MGT-10.filter.event'),
    ActivityCategory.content => GuKey.action('MGT-10.filter.content'),
    ActivityCategory.settings => GuKey.action('MGT-10.filter.settings'),
  };

  /// Bir gün grubu: yapışkan başlık (`.group-head .t-overline`,
  /// `text-transform:none`) + satırlar.
  Widget _section(
    ActivityLogState state,
    ActivityDaySection section,
    ActivityTexts texts,
    RelativeTimeFormatter relative,
    DateTime nowUtc,
  ) => SliverMainAxisGroup(
    key: ValueKey<DateTime>(section.day),
    slivers: [
      GuGroupHeader(title: relative.dayLabel(section.day), sticky: true),
      SliverList.builder(
        itemCount: section.items.length,
        itemBuilder: (_, index) {
          final entry = section.items[index];
          final actor = state.lookups.users[entry.actorId];
          return ActivityRow(
            key: ValueKey<String>(entry.id),
            activity: entry,
            text: texts.text(entry, state.lookups),
            timeLabel: relative.format(entry.createdAt ?? nowUtc),
            actor: actor,
            actorImage: ref.userAvatarImage(
              actor,
              displaySize: GuSizes.activityRowAvatar,
            ),
            actionKey: GuKey.action('MGT-10.row.${entry.id}'),
            onTap: () => openEntry(entry),
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(activityLogViewModelProvider(widget.clubId));
    final session = ref.watch(sessionViewModelProvider);
    final clock = ref.watch(appClockProvider);
    final nowUtc = clock.nowUtc();
    final role = session.roleIn(widget.clubId);
    final canSwitch = ManagedClubPickerSheet.managedOf(session).length > 1;
    final texts = ActivityTexts(l10n);
    final relative = RelativeTimeFormatter(l10n, clock);
    final status = GuListStatus.resolve(
      isError: state.isError,
      isLoading: state.isFetching,
      isEmpty: state.isEmpty,
    );

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: ManageHeader(
        club: state.club,
        title: l10n.activityTitle,
        onBack: goBack,
        backKey: GuKey.action('MGT-10.back'),
        role: role,
        isSuperAdmin: session.isSuperAdmin,
        onSwitchClub: canSwitch ? switchClub : null,
        switchClubKey: canSwitch ? GuKey.action('MGT-10.switchClub') : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (role == ClubRole.advisor)
            GuBanner(kind: GuBannerKind.readonly, text: l10n.mgtReadOnlyBanner),
          // `.hscroll.py8` yazılmıştır, ancak `.hscroll` dolgusu ezer:
          // dikey 3 px (K-59; referans görüntüde ölçüldü).
          GuHorizontalList(
            children: [
              for (final filter in _filters)
                GuChip(
                  key: _filterKey(filter),
                  label: _filterLabel(l10n, filter),
                  selected: state.category == filter,
                  onTap: () => selectCategory(filter),
                ),
            ],
          ),
          Expanded(
            child: GuRefresh(
              onRefresh: refresh,
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  ...switch (status) {
                    _ when OfflineListFallback.applies(ref, status) => [
                      OfflineListFallback.sliver(onReload: retry),
                    ],
                    GuListStatus.error => [
                      SliverToBoxAdapter(
                        child: GuErrorState(
                          title: l10n.sysErrorTitle,
                          description: l10n.sysErrorDesc,
                          retryLabel: l10n.commonRetry,
                          retryActionKey: GuKey.action('MGT-10.retry'),
                          inline: true,
                          onRetry: retry,
                        ),
                      ),
                    ],
                    GuListStatus.loading => [
                      SliverToBoxAdapter(
                        child: GuSkeletonList(
                          semanticLabel: l10n.commonLoading,
                          count: _skeletonRows,
                        ),
                      ),
                    ],
                    GuListStatus.empty => [
                      SliverToBoxAdapter(
                        child: GuEmptyState(
                          illustration: GuIllustrations.emptyNotifications,
                          title: l10n.activityEmpty,
                        ),
                      ),
                    ],
                    GuListStatus.data => [
                      for (final section in state.sections)
                        _section(state, section, texts, relative, nowUtc),
                      SliverToBoxAdapter(
                        child: state.isLoadingMore
                            ? GuSkeletonList(
                                semanticLabel: l10n.commonLoading,
                                count: _nextPageRows,
                              )
                            : state.hasMore
                            ? const SizedBox.shrink()
                            : GuListEnd(label: l10n.commonAllDone),
                      ),
                    ],
                  },
                  const SliverSafeArea(
                    top: false,
                    sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
