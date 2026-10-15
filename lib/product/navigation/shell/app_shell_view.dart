import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_view_model.dart';
import 'package:gu_kulupler/features/notifications/view/widget/foreground_notification_banner.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/format/count_badge_label.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/notification_navigator.dart';
import 'package:gu_ui/gu_ui.dart';

/// Uygulama kabuğu: etkin dalın gezgini + alt sekme çubuğu (navigation.md
/// §1, §6; PLAN §13.2, §13.8, §13.10).
///
/// * Alt çubuk **yalnızca sekme kökünde** görünür; derinlik yoldan türetilir
///   (`GuTab.isTabRoot`), ekran ekran bayrak yoktur.
/// * `admin` sekmesi yalnızca süper admine çizilir (dal yine tanımlıdır;
///   rotayı yönlendirme R8 korur).
/// * Etkin sekmeye yeniden dokunma: yığın derinse köke döner, kökteyse
///   `scrollTopRequestProvider` ile listeyi başa kaydırtır.
/// * Sistem geri tuşunun kabuk kuralı tek [PopScope]'tadır: derin ekranda
///   `pop`, ilk sekme dışındaki sekme kökünde ilk sekmeye dönüş, ilk sekmenin
///   kökünde uygulamadan çıkış.
/// * `NAV.tab.*` aksiyon anahtarları yalnızca buradadır (K-17).
/// * Kabuk yalnızca `active` oturumda kurulur (`AppRedirect`); ilk kuruluşta
///   bildirim ön izni (DLG-03) cihazda **bir kez** sorulur (architecture §6;
///   prototip `auth.enterApp`). Prototipteki 600 ms gecikme yoktur: soru ilk
///   kareden sonra açılır.
/// * Yerel hatırlatıcı dokunuşu (CD-72): uygulama hatırlatıcıya dokunarak
///   (soğuk) açıldıysa ilk kareden sonra yük
///   (`SessionViewModel.takeLaunchReminder`, uygulama ömründe bir kez),
///   uygulama çalışırken dokunulduysa `SessionViewModel.reminderTaps`
///   `NotificationNavigator.openPayload`'a verilir (bilet → EVT-03, değilse
///   EVT-02; Etkinlikler sekmesi).
/// * Push dokunuşu (T-42): soğuk açılış yükü (`SessionViewModel
///   .takeLaunchPush`, bir kez) ve arka plandan dokunuşlar
///   (`SessionViewModel.pushTaps`) `NotificationNavigator.openPush`'a
///   verilir.
/// * Ön plan bandı (TST-55) kabuğu sarar ([ForegroundNotificationBanner]).
class AppShellView extends ConsumerStatefulWidget {
  /// [navigationShell]: `StatefulShellRoute.indexedStack`'in dal kabı.
  const AppShellView({required this.navigationShell, super.key});

  /// Dal gezginlerini taşıyan ve dal değiştiren kap.
  final StatefulNavigationShell navigationShell;

  /// Kabuk aksiyon anahtarları — tek tanım (K-17, CD-53).
  static final Map<GuTab, Key> tabKeys = <GuTab, Key>{
    GuTab.clubs: GuKey.action('NAV.tab.clubs'),
    GuTab.events: GuKey.action('NAV.tab.events'),
    GuTab.notifications: GuKey.action('NAV.tab.notifications'),
    GuTab.admin: GuKey.action('NAV.tab.admin'),
    GuTab.profile: GuKey.action('NAV.tab.profile'),
  };

  /// Çubukta çizilen sekmeler, dal sırasıyla: süper admin değilse `admin`
  /// yoktur (4 sekme), süper adminde beş sekme.
  static List<GuTab> visibleTabs({required bool isSuperAdmin}) => <GuTab>[
    for (final tab in GuTab.values)
      if (tab != GuTab.admin || isSuperAdmin) tab,
  ];

  @override
  ConsumerState<AppShellView> createState() => _AppShellViewState();

  /// Sekme seçimi kuralı (navigation.md §1; prototip `nav.switchTab`).
  ///
  /// * Başka sekme → o dal **kaldığı yerden** açılır (yığın korunur).
  /// * Etkin sekme, yığın derin → dalın köküne dönülür.
  /// * Etkin sekme, zaten kökte ([isTabRoot]) → [onScrollTop] (liste başa
  ///   kaydırılır).
  ///
  /// Alt çubuk yalnızca sekme kökünde çizildiğinden ikinci durum bugün
  /// arayüzden üretilmez; kural yine de eksiksiz tutulur.
  static void selectTab({
    required StatefulNavigationShell shell,
    required GuTab tab,
    required bool isTabRoot,
    required ValueChanged<GuTab> onScrollTop,
  }) {
    final isActive = tab.index == shell.currentIndex;
    if (isActive && isTabRoot) {
      onScrollTop(tab);
      return;
    }
    shell.goBranch(tab.index, initialLocation: isActive);
  }
}

class _AppShellViewState extends ConsumerState<AppShellView> {
  /// Uygulama açıkken dokunulan hatırlatıcılar (yalnızca etkin oturumda).
  StreamSubscription<String>? _reminderTaps;

  /// Uygulama arka plandayken dokunulan push'lar (yalnızca etkin oturumda).
  StreamSubscription<Map<String, String>>? _pushTaps;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionViewModelProvider.notifier);
    _reminderTaps = session.reminderTaps.listen(_openReminder);
    _pushTaps = session.pushTaps.listen(_openPush);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(appPreferencesViewModelProvider.notifier)
            .askNotificationPermissionOnce(),
      );
      unawaited(_openLaunchReminder());
      unawaited(_openLaunchPush());
    });
  }

  @override
  void dispose() {
    unawaited(_reminderTaps?.cancel());
    unawaited(_pushTaps?.cancel());
    super.dispose();
  }

  /// Soğuk açılışın hatırlatıcı yükü varsa hedefine gider.
  Future<void> _openLaunchReminder() async {
    final payload = await ref
        .read(sessionViewModelProvider.notifier)
        .takeLaunchReminder();
    if (payload == null || !mounted) return;
    _openReminder(payload);
  }

  /// Soğuk açılışın push yükü varsa hedefine gider (T-42).
  Future<void> _openLaunchPush() async {
    final data = await ref
        .read(sessionViewModelProvider.notifier)
        .takeLaunchPush();
    if (data == null || !mounted) return;
    _openPush(data);
  }

  /// Push yükü → `NotificationNavigator.openPush` (T-42).
  void _openPush(Map<String, String> data) {
    if (!mounted) return;
    unawaited(ref.read(notificationNavigatorProvider).openPush(data));
  }

  /// Hatırlatıcı yükü → `NotificationNavigator.openPayload` (CD-72).
  void _openReminder(String payload) {
    if (!mounted) return;
    unawaited(ref.read(notificationNavigatorProvider).openPayload(payload));
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final isSuperAdmin = ref.watch(
      sessionViewModelProvider.select((session) => session.isSuperAdmin),
    );
    final isTabRoot = GuTab.isTabRoot(GoRouterState.of(context).uri);
    final currentTab = GuTab.values[navigationShell.currentIndex];
    final tabs = AppShellView.visibleTabs(isSuperAdmin: isSuperAdmin);
    final l10n = context.l10n;
    final colors = context.gu.colors;
    // Rozet: tercih süzgecinden geçmiş okunmamışlar (PLAN §15.9; "9+").
    final unreadCount = ref.watch(
      notificationsViewModelProvider.select((s) => s.unreadCount),
    );

    return ForegroundNotificationBanner(
      child: PopScope<Object?>(
        // Yalnızca ilk sekmenin kökünde sistem uygulamadan çıkarır.
        canPop: currentTab == GuTab.clubs && isTabRoot,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          // Dal gezgini çağrı anında okunur: derleme anındaki değer bir
          // gezinme geride kalabilir.
          if (currentTab.navigatorKey.currentState?.canPop() ?? false) {
            GoRouter.of(context).pop();
            return;
          }
          navigationShell.goBranch(GuTab.clubs.index);
        },
        child: GuSystemUi(
          // Sekme kökünde sistem gezinme çubuğu alt çubuğun zeminini sürdürür.
          navBarColor: isTabRoot ? colors.bgSurface : null,
          child: Scaffold(
            backgroundColor: colors.bgCanvas,
            body: navigationShell,
            bottomNavigationBar: isTabRoot
                ? GuBottomNav(
                    items: [
                      for (final tab in tabs)
                        GuBottomNavItem(
                          icon: _iconOf(tab),
                          label: _labelOf(l10n, tab),
                          badge: tab == GuTab.notifications
                              ? countBadgeLabel(l10n, unreadCount)
                              : null,
                        ),
                    ],
                    currentIndex: tabs.indexOf(currentTab),
                    onTap: (index) => AppShellView.selectTab(
                      shell: navigationShell,
                      tab: tabs[index],
                      isTabRoot: isTabRoot,
                      onScrollTop: (tab) => ref
                          .read(scrollTopRequestProvider(tab).notifier)
                          .request(),
                    ),
                    semanticLabel: l10n.a11yMainNav,
                    tabKeyBuilder: (index) =>
                        AppShellView.tabKeys[tabs[index]]!,
                  )
                : null,
          ),
        ),
      ),
    );
  }

  static GuIcons _iconOf(GuTab tab) => switch (tab) {
    GuTab.clubs => GuIcons.usersRound,
    GuTab.events => GuIcons.calendar,
    GuTab.notifications => GuIcons.bell,
    GuTab.admin => GuIcons.shieldCheck,
    GuTab.profile => GuIcons.user,
  };

  static String _labelOf(AppLocalizations l10n, GuTab tab) => switch (tab) {
    GuTab.clubs => l10n.navClubs,
    GuTab.events => l10n.navEvents,
    GuTab.notifications => l10n.navNotifications,
    GuTab.admin => l10n.navAdmin,
    GuTab.profile => l10n.navProfile,
  };
}
