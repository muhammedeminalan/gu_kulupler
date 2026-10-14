import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_view_model.dart';
import 'package:gu_kulupler/features/management/view/mixin/manage_view_mixin.dart';
import 'package:gu_kulupler/features/management/view/widget/mgt_event_card.dart';
import 'package:gu_kulupler/features/management/view/widget/mgt_kpi_grid.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/format/relative_time_formatter.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/manage/activity_row.dart';
import 'package:gu_kulupler/product/widget/manage/activity_texts.dart';
import 'package:gu_kulupler/product/widget/manage/manage_header.dart';
import 'package:gu_kulupler/product/widget/post/announcement_quota_bar.dart';
import 'package:gu_ui/gu_ui.dart';

/// Yönetim paneli — `ManageRoute` (`/clubs/:clubId/manage`); prototip
/// `Panel` (`screens-manage.js:16–31`). CLB-03 "Yönetim paneli", SHT-18 ve
/// PRF-01 yönetilen kulüp açar; yalnızca o kulübün yöneticisi ya da danışmanı
/// girer (guard `V`, router'da). Danışman salt okunur görür (Q-09).
///
/// Yukarıdan aşağıya: `ManageHeader` (geri · "Yönetim paneli" / kulüp adı
/// (birden çok yönetilen kulüpte SHT-18 düğmesi) · rol rozeti) · danışmanda
/// salt okunur bandı · kaydırma alanı (çek-yenile; `.col.gap20.px16.pb24`):
///
/// 1. "Henüz üyen yok" kartı (sıradan üye yokken, danışman hariç) + Paylaş
///    (SHT-15).
/// 2. Göstergeler (`.grid2`): Toplam üye (+x bu ay) · Bekleyen başvuru
///    (vurgulu) · Yaklaşan etkinlik · Bu ay duyuru.
/// 3. "Hızlı işlemler" (`.grid3`): Gönderi yaz · Duyuru yap · Etkinlik
///    oluştur (danışmanda devre dışı + TST-26) · Yoklama al (etkinlik yoksa
///    TST-X12) · Üyeler · Kulüp ayarları.
/// 4. "Üye artışı" kartı — `GuMiniLineChart`, son 8 hafta (CD-46).
/// 5. "Bugünkü duyuru hakkı" kartı (`AnnouncementQuotaBar.card`).
/// 6. "Yaklaşan etkinlikler" (+ "Tümü"): ilk iki etkinlik ya da "Yaklaşan
///    etkinlik yok.".
/// 7. "Son hareketler" (+ "Tümü" → MGT-10): ilk beş `ActivityRow` ya da
///    "Henüz hareket yok".
///
/// Durumlar: hata ("Bir şeyler ters gitti" + "Yeniden dene") → yükleniyor
/// (iskelet) → dolu. Boş durum yoktur (bölümler kendi boş metnini çizer).
/// Çevrimdışı bandı kökte (kabuk) çizilir; içerik önbellekle kalır.
///
/// Davranış `ManageViewModel` ve `ManageViewMixin`'dedir.
///
/// Design: MGT-01
class ManageView extends ConsumerStatefulWidget {
  /// [clubId] kulübünün yönetim paneli.
  const ManageView({required this.clubId, super.key});

  /// Kulüp kimliği (`ManageRoute.clubId`).
  final String clubId;

  @override
  ConsumerState<ManageView> createState() => _ManageViewState();
}

class _ManageViewState extends ConsumerState<ManageView> with ManageViewMixin {
  /// "Henüz üyen yok" kartının illüstrasyonu (`size=80`, K-48).
  static final double _newClubIllustrationSize = GuSizes.illustrationSizes[2];

  /// Yükleniyor iskeletindeki satır sayısı.
  static const int _skeletonRows = 6;

  Widget _heading(String text) => Semantics(
    header: true,
    child: Text(text, style: context.gu.text.titleS),
  );

  /// Başlık + "Tümü" (`.row.between` + `Button sm text`).
  Widget _sectionHeader(String title, Key allKey, VoidCallback onAll) => Row(
    spacing: GuSpacing.s8,
    children: [
      Expanded(child: _heading(title)),
      GuButton(
        key: allKey,
        label: context.l10n.commonAll,
        variant: GuButtonVariant.text,
        size: GuButtonSize.sm,
        onPressed: onAll,
      ),
    ],
  );

  Widget _newClubCard(AppLocalizations l10n) {
    final gu = context.gu;
    return GuCard(
      muted: true,
      padding: GuCard.bodyPadding,
      child: Column(
        spacing: GuSpacing.s8,
        children: [
          GuIllustration(
            GuIllustrations.emptyClubs,
            size: _newClubIllustrationSize,
          ),
          Text(
            l10n.mgtNewClubTitle,
            textAlign: TextAlign.center,
            style: gu.text.titleS,
          ),
          Text(
            l10n.mgtNewClubDesc,
            textAlign: TextAlign.center,
            style: gu.text.bodyS.copyWith(color: gu.colors.textSecondary),
          ),
          GuButton(
            key: GuKey.action('MGT-01.share'),
            label: l10n.commonShare,
            icon: GuIcons.share2,
            size: GuButtonSize.sm,
            onPressed: share,
          ),
        ],
      ),
    );
  }

  Widget _kpis(ManageState state, AppDateFormats formats, AppLocalizations l) {
    final k = state.kpis;
    return MgtKpiGrid(
      children: [
        GuKpi(
          key: GuKey.action('MGT-01.kpi.members'),
          label: l.mgtKpiMembers,
          value: formats.number(k.memberCount),
          subtitle: l.mgtKpiNewThisMonth(k.joinedThisMonth),
          icon: GuIcons.users,
          onTap: openMembers,
        ),
        GuKpi(
          key: GuKey.action('MGT-01.kpi.pending'),
          label: l.mgtKpiPending,
          value: formats.number(k.pendingCount),
          icon: GuIcons.userPlus,
          accent: true,
          onTap: openApplications,
        ),
        GuKpi(
          key: GuKey.action('MGT-01.kpi.events'),
          label: l.mgtKpiEvents,
          value: formats.number(k.upcomingEventCount),
          icon: GuIcons.calendar,
          onTap: openEvents,
        ),
        GuKpi(
          key: GuKey.action('MGT-01.kpi.announcements'),
          label: l.mgtKpiAnnouncements,
          value: formats.number(k.announcementCount),
          icon: GuIcons.megaphone,
          onTap: openAnnouncements,
        ),
      ],
    );
  }

  Widget _quick(ManageState state, AppLocalizations l10n) {
    final readOnly = state.isReadOnly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        _heading(l10n.mgtQuickTitle),
        MgtKpiGrid(
          columnCount: 3,
          children: [
            GuQuickAction(
              key: GuKey.action('MGT-01.quick.post'),
              icon: GuIcons.pencil,
              label: l10n.mgtQuickPost,
              disabled: readOnly,
              onDisabledPressed: onReadOnly,
              onTap: composePost,
            ),
            GuQuickAction(
              key: GuKey.action('MGT-01.quick.announce'),
              icon: GuIcons.megaphone,
              label: l10n.mgtQuickAnnounce,
              disabled: readOnly,
              onDisabledPressed: onReadOnly,
              onTap: composeAnnouncement,
            ),
            GuQuickAction(
              key: GuKey.action('MGT-01.quick.event'),
              icon: GuIcons.calendarPlus,
              label: l10n.mgtQuickEvent,
              disabled: readOnly,
              onDisabledPressed: onReadOnly,
              onTap: createEvent,
            ),
            GuQuickAction(
              key: GuKey.action('MGT-01.quick.attendance'),
              icon: GuIcons.scanLine,
              label: l10n.mgtQuickAttendance,
              onTap: takeAttendance,
            ),
            GuQuickAction(
              key: GuKey.action('MGT-01.quick.members'),
              icon: GuIcons.users,
              label: l10n.mgtQuickMembers,
              onTap: openMembers,
            ),
            GuQuickAction(
              key: GuKey.action('MGT-01.quick.settings'),
              icon: GuIcons.settings,
              label: l10n.mgtQuickSettings,
              onTap: openSettings,
            ),
          ],
        ),
      ],
    );
  }

  Widget _chart(ManageState state, AppDateFormats formats, AppLocalizations l) {
    final gu = context.gu;
    const last = ManageViewModel.chartWeeks - 1;
    final labels = [
      for (var i = 0; i < state.chart.length; i++) l.mgtWeekN(i - last),
    ];
    return GuCard(
      padding: GuCard.bodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s8,
        children: [
          Row(
            spacing: GuSpacing.s8,
            children: [
              Expanded(
                child: Text(
                  l.mgtGrowth,
                  style: gu.text.labelL.copyWith(color: gu.colors.textHeading),
                ),
              ),
              Text(l.mgtWeeks8, style: gu.text.caption),
            ],
          ),
          if (state.chart.isNotEmpty)
            GuMiniLineChart(
              data: [for (final v in state.chart) v.toDouble()],
              labels: labels,
              semanticLabel: l.mgtChartAria,
              pointLabelBuilder: (i, v) =>
                  l.mgtChartPoint(labels[i], formats.number(v)),
              tooltipBuilder: (i, v) =>
                  l.mgtChartTooltip(labels[i], formats.number(v)),
              pointKeyBuilder: (i) => GuKey.action('MGT-01.chart.point.$i'),
            ),
        ],
      ),
    );
  }

  Widget _upcoming(ManageState state, AppLocalizations l10n) {
    final gu = context.gu;
    final events = state.upcomingEvents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        _sectionHeader(
          l10n.mgtUpcoming,
          GuKey.action('MGT-01.eventsAll'),
          openEvents,
        ),
        if (events.isEmpty)
          Text(
            l10n.mgtNoUpcoming,
            style: gu.text.bodyS.copyWith(color: gu.colors.textMuted),
          )
        else
          for (final event in events)
            MgtEventCard(
              key: ValueKey<String>(event.id),
              event: event,
              actionKey: GuKey.action('MGT-01.event.${event.id}'),
              onTap: () => openAttendance(event.id),
            ),
      ],
    );
  }

  Widget _recent(ManageState state, AppLocalizations l10n) {
    final gu = context.gu;
    final clock = ref.watch(appClockProvider);
    final now = clock.nowUtc();
    final relative = RelativeTimeFormatter(l10n, clock);
    final texts = ActivityTexts(l10n);
    final items = state.recentActivity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        _sectionHeader(
          l10n.mgtRecent,
          GuKey.action('MGT-01.activityAll'),
          openActivityLog,
        ),
        GuCard(
          child: items.isEmpty
              ? Padding(
                  padding: GuInsets.all16,
                  child: Text(
                    l10n.activityEmpty,
                    style: gu.text.bodyS.copyWith(color: gu.colors.textMuted),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, activity) in items.indexed) ...[
                      if (index > 0) const GuDivider(),
                      _row(state, activity, texts, relative, now),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(
    ManageState state,
    ActivityModel activity,
    ActivityTexts texts,
    RelativeTimeFormatter relative,
    DateTime now,
  ) {
    final actor = state.lookups.users[activity.actorId];
    return ActivityRow(
      key: ValueKey<String>(activity.id),
      activity: activity,
      text: texts.text(activity, state.lookups),
      timeLabel: relative.format(activity.createdAt ?? now),
      actor: actor,
      actorImage: ref.userAvatarImage(actor),
      actionKey: GuKey.action('MGT-01.row.${activity.id}'),
      onTap: () => openActivity(activity),
    );
  }

  /// Kaydırma alanının bölümleri — sıra: hata → iskelet → dolu.
  List<Widget> _sections(ManageState state, AppLocalizations l10n) {
    if (state.isError) {
      return [
        GuErrorState(
          title: l10n.sysErrorTitle,
          description: l10n.sysErrorDesc,
          retryLabel: l10n.commonRetry,
          retryActionKey: GuKey.action('MGT-01.retry'),
          onRetry: retry,
        ),
      ];
    }
    if (state.isFetching || state.club == null) {
      return [
        GuSkeletonList(semanticLabel: l10n.commonLoading, count: _skeletonRows),
      ];
    }
    final formats = AppDateFormats(
      Localizations.localeOf(context),
      ref.watch(appClockProvider),
    );
    return [
      if (state.showNewClubCard) _newClubCard(l10n),
      _kpis(state, formats, l10n),
      _quick(state, l10n),
      _chart(state, formats, l10n),
      AnnouncementQuotaBar(
        used: state.announcementsToday,
        limit: Limits.announcementDailyLimit,
        card: true,
      ),
      _upcoming(state, l10n),
      _recent(state, l10n),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(manageViewModelProvider(widget.clubId));
    final canSwitch = ref.watch(
      sessionViewModelProvider.select(
        (session) => ManagedClubPickerSheet.managedOf(session).length > 1,
      ),
    );

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: ManageHeader(
        club: state.club,
        title: l10n.mgtTitle,
        onBack: goBack,
        backKey: GuKey.action('MGT-01.back'),
        role: state.role,
        isSuperAdmin: state.isSuperAdmin,
        onSwitchClub: canSwitch ? switchClub : null,
        switchClubKey: canSwitch ? GuKey.action('MGT-01.switchClub') : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.isReadOnly)
            GuBanner(kind: GuBannerKind.readonly, text: l10n.mgtReadOnlyBanner),
          Expanded(
            child: GuRefresh(
              onRefresh: refresh,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: GuInsets.only(
                      left: GuSpacing.s16,
                      right: GuSpacing.s16,
                      bottom: GuSpacing.s24,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: GuSpacing.s20,
                        children: _sections(state, l10n),
                      ),
                    ),
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
