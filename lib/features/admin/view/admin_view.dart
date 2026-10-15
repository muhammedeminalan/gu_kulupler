import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/admin/provider/admin_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_view_model.dart';
import 'package:gu_kulupler/features/admin/view/mixin/admin_view_mixin.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_segment_bar.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';

/// Admin genel bakış — `AdminRoute` (`/admin`, Admin sekmesinin kökü;
/// guard `S`: yalnızca süper admin, router'da). Prototip `Overview`
/// (`screens-admin.js:11–27`).
///
/// Yukarıdan aşağıya: büyük başlık "Admin" + "Süper Admin" rozeti ·
/// `AdminSegmentBar` (Genel seçili) · kaydırma alanı (çek-yenile;
/// `.col.gap20.px16.pb24`):
///
/// 1. Dönem çipleri (7 gün · 30 gün · Dönem; `.row.gap8`).
/// 2. Göstergeler (`.grid2`): Aktif kulüp · Toplam kullanıcı (+x yeni) ·
///    Askıdaki kulüp · Açık şikayet (vurgulu).
/// 3. "Haftalık aktif kullanıcı" kartı — `GuMiniLineChart`, son 8 hafta
///    (CD-46: tüm kulüplerde yeni üyelik).
/// 4. "En aktif 5 kulüp" kartı — ad + üye sayısı satırları → CLB-03.
///    Prototipteki ince ilerleme çubuğu referans görüntüde görünmez
///    (`.prog` `flex:1` sütun düzeninde yükseklik 0): 1:1 görüntü esas,
///    çizilmez; satırlar arası 4 (`gap4`).
/// 5. Etkinlik katılım oranı kartı (`GuDonut` + açıklama).
/// 6. "Bekleyen işler": açık şikayet ve askıdaki kulüp satırları.
///
/// Durumlar: hata ("Bir şeyler ters gitti" + "Yeniden dene") → yükleniyor
/// (iskelet) → dolu. Boş durum yoktur (sayılar 0 olur; kulüp yoksa kartta
/// "Kulüp yok"). Çevrimdışı bandı kökte (kabuk) çizilir.
///
/// Davranış `AdminViewModel` ve `AdminViewMixin`'dedir.
///
/// Design: ADM-01
class AdminView extends ConsumerStatefulWidget {
  /// Admin sekme kökü.
  const AdminView({super.key});

  @override
  ConsumerState<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends ConsumerState<AdminView> with AdminViewMixin {
  /// Yükleniyor iskeletindeki satır sayısı.
  static const int _skeletonRows = 6;

  /// Grafiğin son noktasının dizini (etiket "0. hafta" = bu hafta).
  static const int _lastWeek = AdminViewModel.chartWeeks - 1;

  /// `.tnum` (css:99).
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  String _rangeLabel(AppLocalizations l10n, AdminRange range) =>
      switch (range) {
        AdminRange.days7 => l10n.adminRange7,
        AdminRange.days30 => l10n.adminRange30,
        AdminRange.term => l10n.adminRangeTerm,
      };

  Key _rangeKey(AdminRange range) => switch (range) {
    AdminRange.days7 => GuKey.action('ADM-01.range.7'),
    AdminRange.days30 => GuKey.action('ADM-01.range.30'),
    AdminRange.term => GuKey.action('ADM-01.range.term'),
  };

  Widget _ranges(AdminState state, AppLocalizations l10n) => Wrap(
    spacing: GuSpacing.s8,
    runSpacing: GuSpacing.s8,
    children: [
      for (final range in AdminRange.values)
        GuChip(
          key: _rangeKey(range),
          label: _rangeLabel(l10n, range),
          selected: state.range == range,
          onTap: () => selectRange(range),
        ),
    ],
  );

  /// `.grid2`: iki sütun, aralık 12; aynı satırdaki kartlar eşit boyda
  /// (ekran içi kompozisyon — CD-112).
  Widget _kpiRow(Widget left, Widget right) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s12,
      children: [
        Expanded(child: left),
        Expanded(child: right),
      ],
    ),
  );

  Widget _kpis(AdminState state, AppDateFormats formats, AppLocalizations l) {
    final stats = state.stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s12,
      children: [
        _kpiRow(
          GuKpi(
            key: GuKey.action('ADM-01.kpi.clubs'),
            label: l.adminKpiActiveClubs,
            value: formats.number(stats.clubCount),
            icon: GuIcons.usersRound,
            onTap: openClubs,
          ),
          GuKpi(
            key: GuKey.action('ADM-01.kpi.users'),
            label: l.adminKpiUsers,
            value: formats.number(stats.userCount),
            subtitle: l.adminKpiNewUsers(state.newCount),
            icon: GuIcons.user,
            onTap: openUsers,
          ),
        ),
        _kpiRow(
          GuKpi(
            key: GuKey.action('ADM-01.kpi.suspended'),
            label: l.adminKpiSuspended,
            value: formats.number(state.suspendedClubCount),
            icon: GuIcons.ban,
            onTap: openSuspendedClubs,
          ),
          GuKpi(
            key: GuKey.action('ADM-01.kpi.reports'),
            label: l.adminKpiOpenReports,
            value: formats.number(stats.openReportCount),
            icon: GuIcons.flag,
            accent: true,
            onTap: openReports,
          ),
        ),
      ],
    );
  }

  Widget _cardTitle(String text) {
    final gu = context.gu;
    return Semantics(
      header: true,
      child: Text(
        text,
        style: gu.text.labelL.copyWith(color: gu.colors.textHeading),
      ),
    );
  }

  Widget _chart(AdminState state, AppDateFormats formats, AppLocalizations l) {
    final labels = [
      for (var i = 0; i < state.chart.length; i++) l.mgtWeekN(i - _lastWeek),
    ];
    return GuCard(
      padding: GuCard.bodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s8,
        children: [
          _cardTitle(l.adminWau),
          if (state.chart.isNotEmpty)
            GuMiniLineChart(
              data: [for (final v in state.chart) v.toDouble()],
              labels: labels,
              semanticLabel: l.adminWau,
              pointLabelBuilder: (i, v) =>
                  l.mgtChartPoint(labels[i], formats.number(v)),
              tooltipBuilder: (i, v) =>
                  l.mgtChartTooltip(labels[i], formats.number(v)),
              pointKeyBuilder: (i) => GuKey.action('ADM-01.chart.point.$i'),
            ),
        ],
      ),
    );
  }

  Widget _topClubs(
    AdminState state,
    AppDateFormats formats,
    AppLocalizations l,
  ) {
    final gu = context.gu;
    final clubs = state.topClubs;
    // `.col.gap10` CSS'te tanımsız → başlık ile satırlar arası boşluk yok
    // (CD-99, K-42).
    return GuCard(
      padding: GuCard.bodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(l.adminTopClubs),
          if (clubs.isEmpty)
            Text(
              l.adminClubsEmpty,
              style: gu.text.bodyS.copyWith(color: gu.colors.textMuted),
            )
          else
            for (final club in clubs) _topClubRow(club, formats),
        ],
      ),
    );
  }

  Widget _topClubRow(ClubModel club, AppDateFormats formats) {
    final gu = context.gu;
    final count = formats.number(club.memberCount);
    // Satır en az 44 dp (D-22; kullanıcı kararı 2026-10-15 — prototipte
    // ~24 dp `button.col.gap4`): satır kutusu hedefin kendisidir; komşu
    // satırlar bitişik olduğundan 48'e simetrik genişletme alttaki satırın
    // üstüne taşardı (sonra çizilen önce vurulur) → `minSize` satır yüksekliği.
    return GuTapTarget(
      key: GuKey.action('ADM-01.topClub.${club.id}'),
      minSize: GuSizes.tapTargetIos,
      semanticLabel: '${club.name}, $count',
      onTap: () => openClub(club.id),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: GuSizes.tapTargetIos),
        child: Row(
          spacing: GuSpacing.s8,
          children: [
            Expanded(
              child: Text(
                club.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: gu.text.bodyS.copyWith(color: gu.colors.textHeading),
              ),
            ),
            Text(
              count,
              style: gu.text.caption.copyWith(fontFeatures: _tabular),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attendance(
    AdminState state,
    AppDateFormats formats,
    AppLocalizations l,
  ) {
    final gu = context.gu;
    final a = state.attendance;
    final rate = a.rate.round();
    return GuCard(
      padding: GuCard.bodyPadding,
      child: Row(
        spacing: GuSpacing.s16,
        children: [
          GuDonut(
            value: a.rate,
            valueLabel: formats.percent(rate),
            semanticLabel: l.adminAttendanceRate,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: GuSpacing.s4,
              children: [
                _cardTitle(l.adminAttendanceRate),
                Text(
                  l.adminAttendanceDesc(
                    formats.number(a.eventCount),
                    formats.number(a.registered),
                    formats.number(a.attended),
                  ),
                  style: gu.text.bodyS.copyWith(
                    color: gu.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tasks(AdminState state, AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: GuSpacing.s8,
    children: [
      Semantics(
        header: true,
        child: Text(l10n.adminPendingTasks, style: context.gu.text.titleS),
      ),
      GuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GuTile(
              key: GuKey.action('ADM-01.task.reports'),
              leading: const GuIconBox(
                icon: GuIcons.flag,
                tone: GuIconBoxTone.warning,
                iconSize: GuSizes.icon18,
              ),
              title: l10n.adminTaskReports(state.stats.openReportCount),
              chevron: true,
              padding: GuTilePadding.inCard,
              onTap: openReports,
            ),
            const GuDivider(),
            GuTile(
              key: GuKey.action('ADM-01.task.suspended'),
              leading: const GuIconBox(
                icon: GuIcons.ban,
                tone: GuIconBoxTone.danger,
                iconSize: GuSizes.icon18,
              ),
              title: l10n.adminTaskSuspended(state.suspendedClubCount),
              chevron: true,
              padding: GuTilePadding.inCard,
              onTap: openSuspendedClubs,
            ),
          ],
        ),
      ),
    ],
  );

  /// Kaydırma alanının bölümleri — sıra: hata → iskelet → dolu.
  List<Widget> _sections(AdminState state, AppLocalizations l10n) {
    if (state.isError) {
      return [
        GuErrorState(
          title: l10n.sysErrorTitle,
          description: l10n.sysErrorDesc,
          retryLabel: l10n.commonRetry,
          retryActionKey: GuKey.action('ADM-01.retry'),
          onRetry: retry,
        ),
      ];
    }
    if (state.isFetching || !state.isLoaded) {
      return [
        GuSkeletonList(semanticLabel: l10n.commonLoading, count: _skeletonRows),
      ];
    }
    final formats = AppDateFormats(
      Localizations.localeOf(context),
      ref.watch(appClockProvider),
    );
    return [
      _ranges(state, l10n),
      _kpis(state, formats, l10n),
      _chart(state, formats, l10n),
      _topClubs(state, formats, l10n),
      _attendance(state, formats, l10n),
      _tasks(state, l10n),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(adminViewModelProvider);

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.navAdmin,
        large: true,
        actions: [
          GuRoleBadge(
            kind: GuRoleBadgeKind.superadmin,
            label: l10n.roleSuperadmin,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSegmentBar(
            current: AdminSegmentBar.overview,
            onSelect: openSegment,
            keyOf: (id) => GuKey.action('ADM-01.seg.$id'),
          ),
          Expanded(
            child: GuRefresh(
              onRefresh: refresh,
              child: CustomScrollView(
                controller: scrollController,
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
