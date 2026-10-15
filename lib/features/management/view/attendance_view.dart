import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/management/provider/attendance_state.dart';
import 'package:gu_kulupler/features/management/provider/attendance_view_model.dart';
import 'package:gu_kulupler/features/management/view/mixin/attendance_view_mixin.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/member/attendee_row.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// Katılımcılar ve yoklama — `AttendanceRoute`
/// (`/clubs/:clubId/manage/events/:eventId/attendance`); prototip
/// `Attendance` (`screens-manage.js:121–139`). EVT-02 yönetici (W-27),
/// MGT-01 "Yoklama" (W-39) ve SHT-23 satırları (W-42) açar (guard `V`,
/// router'da); danışman salt okunur görür (yazma eylemleri TST-26).
///
/// Yukarıdan aşağıya: başlık çubuğu (geri · "Katılımcılar ve yoklama ·
/// {kulüp}" + etkinlik adı `chevron-down` → etkinlik değiştir · QR tarayıcı
/// (danışmanda yok) · "⋮") · danışmanda salt okunur bandı · toplu yoklama
/// ilerleme bandı · yoklama penceresi bandı (K-G) · özet çipleri (Kayıtlı /
/// Katıldın / Gelmedi / Bekleme listesi + sayı; şerit dolgusu 3 px — K-59) ·
/// yoklama çubuğu + "Yoklama %n" · arama · kaydırma alanı: `AttendeeRow`
/// satırları (ada göre; süzgece / aramaya uyan yoksa küçük boş durum) +
/// "Bekleme listesi" grubu (`AttendeeRow` bekleme satırı, "Kayıtlıya al").
///
/// Durumlar (sıra: hata → yükleniyor → dolu) yalnızca listeyi değiştirir;
/// çevrimdışı bandı kökte (kabuk) çizilir, yazan eylemler TST-24 verir.
/// Liste canlıdır (çek-yenile yok). Davranış `AttendanceViewModel` ve
/// `AttendanceViewMixin`'dedir.
///
/// Design: MGT-06
class AttendanceView extends ConsumerStatefulWidget {
  /// [clubId] kulübünün [eventId] etkinliğinin katılımcıları.
  const AttendanceView({
    required this.clubId,
    required this.eventId,
    super.key,
  });

  /// Kulüp kimliği (`AttendanceRoute.clubId`).
  final String clubId;

  /// Etkinlik kimliği (`AttendanceRoute.eventId`).
  final String eventId;

  @override
  ConsumerState<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends ConsumerState<AttendanceView>
    with AttendanceViewMixin {
  /// Yükleniyor iskeletindeki satır sayısı (prototip `ListState n=5`).
  static const int _skeletonRows = 5;

  /// Başlıktaki üst satırın ayracı (prototip `${a} · ${b}`).
  static const String _separator = ' · ';

  /// Başlıktaki üst satırın en çok satır sayısı (referansta iki satır).
  static const int _captionMaxLines = 2;

  /// Başlık: "Katılımcılar ve yoklama · {kulüp}" (caption, sarar) + etkinlik
  /// adı (`titleS`) ve `chevron-down` → etkinlik değiştir
  /// (`screens-manage.js:127`).
  Widget _title(AttendanceState state, AppLocalizations l10n) {
    final gu = context.gu;
    final clubName = state.club?.name;
    final title = state.event?.title ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [l10n.attendanceTitle, ?clubName].join(_separator),
          style: gu.text.caption,
          maxLines: _captionMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
        Semantics(
          header: true,
          child: GuTapTarget(
            key: GuKey.action('MGT-06.switchEvent'),
            onTap: switchEvent,
            semanticLabel: title,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: GuSpacing.s4,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: gu.text.titleS,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GuIcon(
                  GuIcons.chevronDown,
                  size: GuSizes.icon16,
                  color: gu.colors.textHeading,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Yoklama penceresi bandı (K-G; prototip yalnızca "henüz başlamadı").
  String? _phaseText(AttendancePhase phase, AppLocalizations l10n) =>
      switch (phase) {
        AttendancePhase.beforeWindow => l10n.attendanceWindowNotOpen(
          Limits.attendanceWindowBefore.inHours,
        ),
        AttendancePhase.beforeStart => l10n.attendanceNotStarted,
        AttendancePhase.open => null,
        AttendancePhase.closed => l10n.attendanceWindowClosed(
          Limits.attendanceWindowAfter.inHours,
        ),
      };

  Widget _attendee(AttendanceState state, RsvpModel rsvp) {
    final userId = rsvp.userId;
    final user = state.users[userId];
    final isSelf = state.isOwn(userId);
    final enabled =
        state.canMark && !isSelf && !state.pendingIds.contains(userId);
    return AttendeeRow(
      key: ValueKey<String>(userId),
      rsvp: rsvp,
      name: state.nameOf(userId),
      sub: MemberRow.departmentAndYear(
        context,
        department: user?.department,
        year: user?.year,
      ),
      avatarImage: ref.userAvatarImage(user, displaySize: GuSizes.avatar),
      avatarSeed: user?.avatarSeed,
      attended: rsvp.status == RsvpStatus.attended,
      onToggle: enabled ? (value) => toggleAttended(userId, value) : null,
      isSelf: isSelf,
      readOnly: !enabled && !isSelf,
      onDisabledTap: state.isReadOnly ? onReadOnly : null,
      actionKey: GuKey.action('MGT-06.attended.$userId'),
    );
  }

  Widget _waiting(AttendanceState state, RsvpModel rsvp, int index) {
    final userId = rsvp.userId;
    final user = state.users[userId];
    return AttendeeRow(
      key: ValueKey<String>(userId),
      rsvp: rsvp,
      name: state.nameOf(userId),
      sub: MemberRow.departmentAndYear(
        context,
        department: user?.department,
        year: user?.year,
      ),
      avatarImage: ref.userAvatarImage(
        user,
        displaySize: AttendeeRow.waitlistAvatarSize,
      ),
      avatarSeed: user?.avatarSeed,
      attended: false,
      onToggle: null,
      waitlistPosition: index + 1,
      readOnly: state.isReadOnly,
      onDisabledTap: onReadOnly,
      capacityFull: state.isFull,
      onCapacityFullTap: onPromoteDisabled,
      promoting: state.pendingIds.contains(userId),
      onPromote: () => promote(userId),
      promoteKey: GuKey.action('MGT-06.promote.$userId'),
    );
  }

  List<Widget> _slivers(AttendanceState state, AppLocalizations l10n) {
    if (state.isError) {
      return [
        SliverToBoxAdapter(
          child: GuErrorState(
            title: l10n.sysErrorTitle,
            description: l10n.sysErrorDesc,
            retryLabel: l10n.commonRetry,
            retryActionKey: GuKey.action('MGT-06.retry'),
            inline: true,
            onRetry: retry,
          ),
        ),
      ];
    }
    if (state.isFetching) {
      return [
        SliverToBoxAdapter(
          child: GuSkeletonList(
            semanticLabel: l10n.commonLoading,
            count: _skeletonRows,
          ),
        ),
      ];
    }
    final rows = state.visible;
    final waitlist = state.waitlist;
    final muted = context.gu.colors.textMuted;
    return [
      if (state.showsRegistered)
        if (rows.isEmpty)
          SliverToBoxAdapter(
            child: GuEmptyState(
              illustration: GuIllustrations.emptyApplications,
              title: state.needle.isEmpty
                  ? l10n.attendanceEmpty
                  : l10n.membersNoResults,
              compact: true,
            ),
          )
        else
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (_, index) => _attendee(state, rows[index]),
          ),
      if (state.showsWaitlist) ...[
        SliverToBoxAdapter(
          child: GuGroupHeader(
            title: l10n.statusWaitlist.upperFor(
              Localizations.localeOf(context),
            ),
            trailingText: waitlist.length.toString(),
          ),
        ),
        if (waitlist.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: GuInsets.only(
                left: GuSpacing.s16,
                right: GuSpacing.s16,
                bottom: GuSpacing.s16,
              ),
              child: Text(
                l10n.attendanceNoWaitlist,
                style: context.gu.text.bodyS.copyWith(color: muted),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: waitlist.length,
            itemBuilder: (_, index) => _waiting(state, waitlist[index], index),
          ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(
      attendanceViewModelProvider(widget.clubId, widget.eventId),
    );
    final formats = AppDateFormats(
      Localizations.localeOf(context),
      ref.watch(appClockProvider),
    );
    final phaseText = _phaseText(state.phase, l10n);
    final bulk = state.bulkProgress;

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        titleWidget: _title(state, l10n),
        onBack: goBack,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('MGT-06.back'),
        actions: [
          if (!state.isReadOnly)
            GuIconButton(
              key: GuKey.action('MGT-06.scan'),
              icon: GuIcons.scanLine,
              semanticLabel: l10n.eventCtaScan,
              tone: GuIconButtonTone.brand,
              onPressed: openScan,
            ),
          GuIconButton(
            key: GuKey.action('MGT-06.menu'),
            icon: GuIcons.moreVertical,
            semanticLabel: l10n.a11yMore,
            onPressed: openMenu,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.isReadOnly)
            GuBanner(kind: GuBannerKind.readonly, text: l10n.mgtReadOnlyBanner),
          if (bulk != null)
            GuBanner(
              text: l10n.attendanceMarkingProgress(
                formats.percent(
                  bulk.total == 0 ? 0 : (bulk.done * 100 / bulk.total).round(),
                ),
              ),
            ),
          if (phaseText != null) GuBanner(text: phaseText),
          // `.hscroll.py8` yazılmıştır, ancak dikey dolgu 3 px kalır (K-59).
          GuHorizontalList(
            children: [
              for (final summary in AttendanceSummaryFilter.values)
                GuChip(
                  key: AttendanceViewMixin.summaryKeyOf(summary),
                  label: l10n.attendanceSummaryChip(
                    AttendanceViewMixin.summaryLabel(l10n, summary),
                    state.countOf(summary),
                  ),
                  selected: state.summary == summary,
                  onTap: () => selectSummary(summary),
                ),
            ],
          ),
          Padding(
            padding: GuInsets.only(
              left: GuSpacing.s16,
              right: GuSpacing.s16,
              bottom: GuSpacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: GuSpacing.s8,
              children: [
                Row(
                  spacing: GuSpacing.s8,
                  children: [
                    Expanded(
                      child: GuProgress(
                        value: state.attendanceRate.toDouble(),
                        kind: GuProgressKind.success,
                        semanticLabel: l10n.attendanceRate,
                      ),
                    ),
                    Text(
                      l10n.attendanceRateValue(
                        formats.percent(state.attendanceRate),
                      ),
                      maxLines: 1,
                      style: gu.text.labelM.copyWith(
                        color: gu.colors.textHeading,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                GuInput(
                  controller: searchController,
                  icon: GuIcons.search,
                  placeholder: l10n.membersSearch,
                  semanticLabel: l10n.membersSearch,
                  textInputAction: TextInputAction.search,
                  onChanged: onQueryChanged,
                  actionKey: GuKey.action('MGT-06.search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                ..._slivers(state, l10n),
                const SliverSafeArea(
                  top: false,
                  sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
