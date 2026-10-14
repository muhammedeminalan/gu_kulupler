import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_state.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_view_model.dart';
import 'package:gu_kulupler/features/notifications/view/mixin/notifications_view_mixin.dart';
import 'package:gu_kulupler/features/notifications/view/widget/notification_group.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/format/relative_time_formatter.dart';
import 'package:gu_kulupler/product/widget/notification/notification_row.dart';
import 'package:gu_kulupler/product/widget/notification/notification_texts.dart';
import 'package:gu_ui/gu_ui.dart';

/// "Bildirimler" sekme kökü — `NotificationsRoute` (`/notifications`);
/// prototip `Notifications` (`screens-events.js:98–106`).
///
/// Yukarıdan aşağıya: büyük başlık ("Bildirimler" · "Tümünü okundu yap" ·
/// ayarlar) · izin bandı (izin yoksa ve kapatılmadıysa; `warning`,
/// `bell-off`, "Aç" + kapat) · filtre çipleri (Tümü / Okunmamış / Kulüpler /
/// Etkinlikler / Sistem) · çek-yenile liste: gün grupları (`NotificationGroup`
/// — Bugün / Dün / Bu hafta / Daha önce, yapışkan başlık) + `NotificationRow`
/// + liste sonu.
///
/// Durumlar (yalnızca liste değişir): hata ("Bir şeyler ters gitti" +
/// "Yeniden dene") → yükleniyor (6 satır iskelet) → boş (`empty-notifications`
/// illüstrasyonu) → dolu; çevrimdışı bandı kökte (liste önbellekle kalır).
/// Liste canlıdır; çek-yenile tercihleri ve izni yeniden okur. Davranış
/// `NotificationsViewModel` ve `NotificationsViewMixin`'dedir.
///
/// Design: NTF-01
class NotificationsView extends ConsumerStatefulWidget {
  /// Bildirim merkezi.
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView>
    with NotificationsViewMixin {
  /// İskelet satır sayısı (prototip `ListState n=6`).
  static const int _skeletonRows = 6;

  /// Çiplerin prototip sırası (`screens-events.js:103`).
  static const List<NotificationFilter> _filters = [
    NotificationFilter.all,
    NotificationFilter.unread,
    NotificationFilter.clubs,
    NotificationFilter.events,
    NotificationFilter.system,
  ];

  static String _filterLabel(AppLocalizations l10n, NotificationFilter f) =>
      switch (f) {
        NotificationFilter.all => l10n.commonAll,
        NotificationFilter.unread => l10n.notifUnread,
        NotificationFilter.clubs => l10n.navClubs,
        NotificationFilter.events => l10n.navEvents,
        NotificationFilter.system => l10n.notifSystem,
      };

  static Key _filterKey(NotificationFilter f) => switch (f) {
    NotificationFilter.all => GuKey.action('NTF-01.filter.all'),
    NotificationFilter.unread => GuKey.action('NTF-01.filter.unread'),
    NotificationFilter.clubs => GuKey.action('NTF-01.filter.clubs'),
    NotificationFilter.events => GuKey.action('NTF-01.filter.events'),
    NotificationFilter.system => GuKey.action('NTF-01.filter.system'),
  };

  static String _dayLabel(AppLocalizations l10n, NotificationDay day) =>
      switch (day) {
        NotificationDay.today => l10n.timeGroupToday,
        NotificationDay.yesterday => l10n.timeGroupYesterday,
        NotificationDay.week => l10n.timeGroupWeek,
        NotificationDay.earlier => l10n.timeGroupOlder,
      };

  Widget _row(
    NotificationsState state,
    NotificationModel n,
    NotificationTexts texts,
    RelativeTimeFormatter relative,
    DateTime nowUtc,
  ) {
    final id = n.id;
    final canMute =
        state.settings != null &&
        NotificationsViewModel.mutePatchOf(n.type) != null;
    return NotificationRow(
      key: ValueKey<String>(id),
      notification: n,
      title: texts.title(n, state.lookups),
      body: texts.body(n, state.lookups),
      timeLabel: relative.format(n.createdAt ?? nowUtc),
      onOpen: () => openNotification(n),
      onToggleRead: () => markRead(n),
      onDelete: () => remove(n),
      onMute: canMute ? () => mute(n) : null,
      openKey: GuKey.action('NTF-01.item.$id'),
      swipeKey: GuKey.action('NTF-01.swipe.$id'),
      menuKeys: NotificationRowMenuKeys(
        scrim: GuKey.action('NTF-01.scrim'),
        read: GuKey.action('NTF-01.menu.$id.read'),
        delete: GuKey.action('NTF-01.menu.$id.delete'),
        mute: GuKey.action('NTF-01.menu.$id.mute'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(notificationsViewModelProvider);
    final clock = ref.watch(appClockProvider);
    final nowUtc = clock.nowUtc();
    final texts = NotificationTexts(
      l10n,
      AppDateFormats(Localizations.localeOf(context), clock),
    );
    final relative = RelativeTimeFormatter(l10n, clock);
    final status = GuListStatus.resolve(
      isError: state.isError,
      isLoading: state.isFetching,
      isEmpty: state.isEmpty,
    );

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.navNotifications,
        large: true,
        actions: [
          GuIconButton(
            key: GuKey.action('NTF-01.markAllRead'),
            icon: GuIcons.checkCheck,
            semanticLabel: l10n.notifMarkAllRead,
            onPressed: markAllRead,
          ),
          GuIconButton(
            key: GuKey.action('NTF-01.settings'),
            icon: GuIcons.settings,
            semanticLabel: l10n.notifSettings,
            onPressed: openSettings,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.showPermissionBanner)
            GuBanner(
              kind: GuBannerKind.warning,
              icon: GuIcons.bellOff,
              text: l10n.notifOffBanner,
              actionLabel: l10n.commonOpen,
              actionKey: GuKey.action('NTF-01.enable'),
              onAction: enableNotifications,
              onDismiss: dismissBanner,
              dismissActionKey: GuKey.action('NTF-01.dismissBanner'),
              dismissSemanticLabel: l10n.a11yClose,
            ),
          // `.hscroll.py8` yazılmıştır, ancak `.hscroll` dolgusu ezer:
          // dikey 3 px (referans görüntüde ölçüldü; AUT-06 ile aynı).
          GuHorizontalList(
            children: [
              for (final filter in _filters)
                GuChip(
                  key: _filterKey(filter),
                  label: _filterLabel(l10n, filter),
                  selected: state.filter == filter,
                  onTap: () => selectFilter(filter),
                ),
            ],
          ),
          Expanded(
            child: GuRefresh(
              onRefresh: refresh,
              refreshActionKey: GuKey.action('NTF-01.refresh'),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  ...switch (status) {
                    GuListStatus.error => [
                      SliverToBoxAdapter(
                        child: GuErrorState(
                          title: l10n.sysErrorTitle,
                          description: l10n.sysErrorDesc,
                          retryLabel: l10n.commonRetry,
                          retryActionKey: GuKey.action('NTF-01.retry'),
                          inline: true,
                          onRetry: refresh,
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
                          title: l10n.notifEmptyTitle,
                          description: l10n.notifEmptyDesc,
                        ),
                      ),
                    ],
                    GuListStatus.data => [
                      for (final section in state.sections)
                        NotificationGroup(
                          key: ValueKey<NotificationDay>(section.day),
                          title: _dayLabel(l10n, section.day),
                          children: [
                            for (final n in section.items)
                              _row(state, n, texts, relative, nowUtc),
                          ],
                        ),
                      SliverToBoxAdapter(
                        child: GuListEnd(label: l10n.commonAllDone),
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
