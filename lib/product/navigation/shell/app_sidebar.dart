import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_view_model.dart';
import 'package:gu_kulupler/product/format/count_badge_label.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/shell/app_shell_view.dart';
import 'package:gu_kulupler/product/navigation/shell/shell_tab_selector.dart';
import 'package:gu_ui/gu_ui.dart';

/// Web yan menüsü (H-23): geniş web penceresinde alt sekme çubuğunun yerini
/// alır (`WebShell`). Sekmeler, sıra, ikon, etiket, bildirim rozeti ve
/// anahtarlar alt çubukla aynıdır (`AppShellView.visibleTabs`, `iconOf`,
/// `labelOf`, `tabKeys` — `NAV.tab.*`, K-17); dokunma kabuğun seçim kuralına
/// gider (`ShellTabSelector` → `AppShellView.selectTab`: başka sekme kaldığı
/// yerden, etkin sekme köke / başa).
///
/// Yönlendiricinin üstünde çizilir ([location] = yönlendiricinin konumu);
/// yalnızca kabuk bağlıyken (etkin oturum) kurulur.
class AppSidebar extends ConsumerWidget {
  const AppSidebar({required this.location, super.key});

  /// Yönlendiricinin geçerli konumu (seçili sekme buradan).
  final Uri location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final gu = context.gu;
    final isSuperAdmin = ref.watch(
      sessionViewModelProvider.select((session) => session.isSuperAdmin),
    );
    final unreadCount = ref.watch(
      notificationsViewModelProvider.select((s) => s.unreadCount),
    );
    final tabs = AppShellView.visibleTabs(isSuperAdmin: isSuperAdmin);
    final current = GuTab.ofLocation(location);
    return GuSidebar(
      header: Row(
        spacing: GuSpacing.s12,
        children: [
          const GuLogo(size: GuWebLayout.sidebarLogo),
          Expanded(
            child: Text(
              AppConstants.appName,
              style: gu.text.titleM.copyWith(color: gu.colors.textHeading),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      items: [
        for (final tab in tabs)
          GuSidebarItem(
            icon: AppShellView.iconOf(tab),
            label: AppShellView.labelOf(l10n, tab),
            badge: tab == GuTab.notifications
                ? countBadgeLabel(l10n, unreadCount)
                : null,
          ),
      ],
      currentIndex: current == null ? -1 : tabs.indexOf(current),
      onTap: (index) => ref.read(shellTabSelectorProvider)?.call(tabs[index]),
      semanticLabel: l10n.a11yMainNav,
      itemKeyBuilder: (index) => AppShellView.tabKeys[tabs[index]]!,
    );
  }
}
