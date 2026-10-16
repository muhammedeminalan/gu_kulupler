import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_applications_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_applications_view_model.dart';
import 'package:gu_kulupler/features/management/view/mixin/manage_applications_view_mixin.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/format/relative_time_formatter.dart';
import 'package:gu_kulupler/product/l10n/reject_reason_labels.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/navigation/applications_tab.dart';
import 'package:gu_kulupler/product/widget/manage/manage_header.dart';
import 'package:gu_kulupler/product/widget/member/application_row.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_kulupler/product/widget/system/offline_list_fallback.dart';
import 'package:gu_ui/gu_ui.dart';

/// Başvurular — `ManageApplicationsRoute`
/// (`/clubs/:clubId/manage/applications?tab=&applicant=`); prototip
/// `Applications` (`screens-manage.js:43–51`). MGT-01 "Başvurular" (W-36),
/// faaliyet satırı (W-95) ve `application_received` bildirimi (W-28) açar
/// (guard `V`, router'da).
///
/// Yukarıdan aşağıya: `ManageHeader` (geri · "Başvurular" / kulüp adı · rol
/// rozeti · sırala) — seçim kipinde yerini seçim çubuğu alır (kapat · "{n}
/// seçili" · "Hepsini seç" · toplu onay / ret → DLG-17) · danışmanda salt
/// okunur bandı · başvurular kapalıysa bilgi bandı + "Başvuruları aç"
/// anahtarı (TST-54) · sekmeler (Bekleyen (sayı) / Onaylanan / Reddedilen)
/// · arama (`.px16.py8`) · kaydırma alanı (çek-yenile):
///
/// * Bekleyen: ipucu ("Satıra basılı tutarak çoklu seçim yapabilirsin.") +
///   `ApplicationRow` satırları (tek dokunuş onay → TST-27, ret → SHT-20 →
///   TST-28; satır → SHT-19; uzun basış → seçim kipi).
/// * Onaylanan / Reddedilen: kişi satırı (avatar 40 · ad · "bölüm · sınıf ·
///   karar tarihi" · ret nedeni · durum rozeti) → SHT-19.
///
/// Durumlar (sıra: hata → yükleniyor → boş → dolu) yalnızca listeyi
/// değiştirir; çevrimdışı bandı kökte (kabuk) çizilir. Hesabı silinmiş
/// başvuran listelenmez (W-92).
///
/// Davranış `ManageApplicationsViewModel` ve
/// `ManageApplicationsViewMixin`'dedir.
///
/// Design: MGT-02
class ManageApplicationsView extends ConsumerStatefulWidget {
  /// [clubId] kulübünün başvuruları.
  const ManageApplicationsView({
    required this.clubId,
    this.tab,
    this.applicantId,
    super.key,
  });

  /// Kulüp kimliği (`ManageApplicationsRoute.clubId`).
  final String clubId;

  /// İlk açılan sekme; `null` → [ApplicationsTab.pending].
  final ApplicationsTab? tab;

  /// Açılışta SHT-19'u açılan başvuranın kullanıcı kimliği (W-28); `null`
  /// → sheet açılmaz.
  final String? applicantId;

  @override
  ConsumerState<ManageApplicationsView> createState() =>
      _ManageApplicationsViewState();
}

class _ManageApplicationsViewState extends ConsumerState<ManageApplicationsView>
    with ManageApplicationsViewMixin {
  /// Yükleniyor iskeletindeki satır sayısı (prototip `ListState n=5`).
  static const int _skeletonRows = 5;

  /// Sonraki sayfa okunurken liste sonunda çizilen iskelet satırı sayısı.
  static const int _nextPageRows = 3;

  static Key _tabKey(ApplicationsTab tab) => switch (tab) {
    ApplicationsTab.pending => GuKey.action('MGT-02.tab.pending'),
    ApplicationsTab.approved => GuKey.action('MGT-02.tab.approved'),
    ApplicationsTab.rejected => GuKey.action('MGT-02.tab.rejected'),
  };

  static String _tabLabel(AppLocalizations l10n, ApplicationsTab tab) =>
      switch (tab) {
        ApplicationsTab.pending => l10n.applicationsTabPending,
        ApplicationsTab.approved => l10n.applicationsTabApproved,
        ApplicationsTab.rejected => l10n.applicationsTabRejected,
      };

  static String _emptyTitle(AppLocalizations l10n, ApplicationsTab tab) =>
      switch (tab) {
        ApplicationsTab.pending => l10n.applicationsEmptyPending,
        ApplicationsTab.approved => l10n.applicationsEmptyApproved,
        ApplicationsTab.rejected => l10n.applicationsEmptyRejected,
      };

  /// Başlık çubuğu: olağan kipte `ManageHeader` + sırala.
  PreferredSizeWidget _header(
    ManageApplicationsState state,
    AppLocalizations l10n, {
    required bool canSwitch,
  }) => ManageHeader(
    club: state.club,
    title: l10n.applicationsTitle,
    onBack: goBack,
    backKey: GuKey.action('MGT-02.back'),
    role: state.role,
    isSuperAdmin: state.isSuperAdmin,
    onSwitchClub: canSwitch ? switchClub : null,
    switchClubKey: canSwitch ? GuKey.action('MGT-02.switchClub') : null,
    actions: [
      GuIconButton(
        key: GuKey.action('MGT-02.sort'),
        icon: GuIcons.arrowUpDown,
        semanticLabel: l10n.commonSort,
        onPressed: toggleSort,
      ),
    ],
  );

  /// Seçim çubuğu (`screens-manage.js:50`): kapat · "{n} seçili" · "Hepsini
  /// seç" · onay (başarı rengi) · ret (tehlike rengi); seçim yokken toplu
  /// düğmeler devre dışı.
  PreferredSizeWidget _selectionBar(
    ManageApplicationsState state,
    AppLocalizations l10n,
  ) {
    final colors = context.gu.colors;
    final none = state.selectedIds.isEmpty;
    Widget tinted(Color color, Widget child) => DefaultTextStyle.merge(
      style: TextStyle(color: color),
      child: child,
    );
    return GuAppBar(
      title: l10n.applicationsSelected(state.selectedIds.length),
      onBack: cancelSelect,
      closeIcon: true,
      backSemanticLabel: l10n.a11yClose,
      backActionKey: GuKey.action('MGT-02.cancelSelect'),
      actions: [
        GuButton(
          key: GuKey.action('MGT-02.selectAll'),
          label: l10n.applicationsSelectAll,
          variant: GuButtonVariant.text,
          size: GuButtonSize.sm,
          onPressed: selectAll,
        ),
        tinted(
          colors.stateSuccess,
          GuIconButton(
            key: GuKey.action('MGT-02.bulkApprove'),
            icon: GuIcons.check,
            semanticLabel: l10n.applicationsApprove,
            foregroundInherit: true,
            disabled: none,
            onPressed: bulkApprove,
          ),
        ),
        tinted(
          colors.stateDanger,
          GuIconButton(
            key: GuKey.action('MGT-02.bulkReject'),
            icon: GuIcons.x,
            semanticLabel: l10n.applicationsReject,
            foregroundInherit: true,
            disabled: none,
            onPressed: bulkReject,
          ),
        ),
      ],
    );
  }

  /// Bekleyen başvuru satırı.
  Widget _pendingRow(
    ManageApplicationsState state,
    MembershipModel m,
    RelativeTimeFormatter relative,
    DateTime now,
  ) {
    final userId = m.userId;
    final user = state.users[userId];
    return ApplicationRow(
      key: ValueKey<String>(userId),
      application: m,
      user: user,
      avatarImage: ref.userAvatarImage(
        user,
        displaySize: GuSizes.applicationRowAvatar,
      ),
      note: state.contacts[userId]?.note,
      timeLabel: relative.format(m.appliedAt ?? m.createdAt ?? now),
      actionKey: GuKey.action('MGT-02.row.$userId'),
      onOpen: () => onRowTap(userId),
      selecting: state.selecting,
      selected: state.selectedIds.contains(userId),
      onSelect: (_) => toggleSelect(userId),
      selectActionKey: GuKey.action('MGT-02.select.$userId'),
      onApprove: () => approve(userId),
      approveActionKey: GuKey.action('MGT-02.approve.$userId'),
      onReject: () => reject(userId),
      rejectActionKey: GuKey.action('MGT-02.reject.$userId'),
      readOnly: state.isReadOnly,
      onReadOnlyTap: onReadOnly,
    );
  }

  /// Onaylanan / reddedilen başvuru satırı (`screens-manage.js:51` `Tile`).
  Widget _decidedRow(
    ManageApplicationsState state,
    MembershipModel m,
    AppDateFormats formats,
    AppLocalizations l10n,
  ) {
    final userId = m.userId;
    final user = state.users[userId];
    final applicant = m.applicant;
    final decidedAt = m.decidedAt;
    final rejected = m.status == MembershipStatus.rejected;
    final reason = m.rejectReason;
    final sub = [
      MemberRow.departmentAndYear(
        context,
        department: user == null ? applicant.department : user.department,
        year: user == null ? applicant.year : user.year,
      ),
      if (decidedAt != null) formats.date(decidedAt),
    ].where((part) => part.isNotEmpty).join(' · ');
    final seed = user?.avatarSeed ?? applicant.avatarSeed;
    return UserRow.named(
      key: ValueKey<String>(userId),
      name: state.nameOf(m),
      avatarSeed: seed.isEmpty ? userId : seed,
      avatarImage: ref.userAvatarImage(user, displaySize: GuSizes.avatar),
      sub: sub,
      sub2: rejected && reason != null
          ? Text(
              RejectReasonLabels.of(l10n, reason),
              style: context.gu.text.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: rejected
          ? GuStatusBadge(
              kind: GuStatusBadgeKind.rejected,
              label: l10n.statusRejected,
            )
          : GuStatusBadge(
              kind: GuStatusBadgeKind.approved,
              label: l10n.statusApproved,
            ),
      actionKey: GuKey.action('MGT-02.row.$userId'),
      onTap: () => onRowTap(userId),
    );
  }

  List<Widget> _slivers(ManageApplicationsState state, AppLocalizations l10n) {
    final gu = context.gu;
    final rows = state.visible;
    final status = GuListStatus.resolve(
      isError: state.isError,
      isLoading: state.isFetching,
      isEmpty: rows.isEmpty,
    );
    switch (status) {
      case _ when OfflineListFallback.applies(ref, status):
        return [OfflineListFallback.sliver(onReload: retry)];
      case GuListStatus.error:
        return [
          SliverToBoxAdapter(
            child: GuErrorState(
              title: l10n.sysErrorTitle,
              description: l10n.sysErrorDesc,
              retryLabel: l10n.commonRetry,
              retryActionKey: GuKey.action('MGT-02.retry'),
              inline: true,
              onRetry: retry,
            ),
          ),
        ];
      case GuListStatus.loading:
        return [
          SliverToBoxAdapter(
            child: GuSkeletonList(
              semanticLabel: l10n.commonLoading,
              count: _skeletonRows,
            ),
          ),
        ];
      case GuListStatus.empty:
        return [
          SliverToBoxAdapter(
            child: GuEmptyState(
              illustration: GuIllustrations.emptyApplications,
              title: _emptyTitle(l10n, state.tab),
            ),
          ),
        ];
      case GuListStatus.data:
        final clock = ref.watch(appClockProvider);
        final now = clock.nowUtc();
        final relative = RelativeTimeFormatter(l10n, clock);
        final formats = AppDateFormats(Localizations.localeOf(context), clock);
        final pending = state.tab == ApplicationsTab.pending;
        return [
          if (pending)
            SliverToBoxAdapter(
              child: Padding(
                padding: GuInsets.only(
                  left: GuSpacing.s16,
                  right: GuSpacing.s16,
                  bottom: GuSpacing.s16,
                ),
                child: Text(l10n.applicationsHint, style: gu.text.caption),
              ),
            ),
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (_, index) => pending
                ? _pendingRow(state, rows[index], relative, now)
                : _decidedRow(state, rows[index], formats, l10n),
          ),
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
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(manageApplicationsViewModelProvider(widget.clubId));
    final canSwitch = ref.watch(
      sessionViewModelProvider.select(
        (session) => ManagedClubPickerSheet.managedOf(session).length > 1,
      ),
    );
    final pendingCount = state.pendingCount;

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: state.selecting
          ? _selectionBar(state, l10n)
          : _header(state, l10n, canSwitch: canSwitch),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.isReadOnly)
            GuBanner(kind: GuBannerKind.readonly, text: l10n.mgtReadOnlyBanner),
          if (state.applicationsClosed)
            GuBanner(
              icon: GuIcons.lock,
              text: l10n.applicationsClosedBanner,
              trailing: GuSwitch(
                key: GuKey.action('MGT-02.toggleOpen'),
                value: false,
                semanticLabel: l10n.applicationsOpenToggle,
                disabled: state.isReadOnly,
                onDisabledPressed: onReadOnly,
                onChanged: (_) => openApplications(),
              ),
            ),
          GuTabs(
            tabs: [
              for (final tab in ApplicationsTab.values)
                GuTabItem(
                  id: tab.name,
                  label: _tabLabel(l10n, tab),
                  count: tab == ApplicationsTab.pending && pendingCount > 0
                      ? pendingCount
                      : null,
                ),
            ],
            value: state.tab.name,
            onChanged: (id) => selectTab(ApplicationsTab.values.byName(id)),
            tabKeyBuilder: (index) => _tabKey(ApplicationsTab.values[index]),
          ),
          Padding(
            padding: GuInsets.h16v8,
            child: GuInput(
              controller: searchController,
              icon: GuIcons.search,
              placeholder: l10n.membersSearch,
              semanticLabel: l10n.membersSearch,
              textInputAction: TextInputAction.search,
              onChanged: onQueryChanged,
              actionKey: GuKey.action('MGT-02.search'),
            ),
          ),
          Expanded(
            child: GuRefresh(
              onRefresh: refresh,
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  // Sekme değişimi kısa solma (kullanıcı kararı 2026-10-16;
                  // `GuMotion.tabSwitch`).
                  GuSliverContentFade(
                    value: state.tab,
                    sliver: SliverMainAxisGroup(slivers: _slivers(state, l10n)),
                  ),
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
