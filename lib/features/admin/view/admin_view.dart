import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/admin/view/admin_clubs_view.dart';
import 'package:gu_kulupler/features/admin/view/admin_overview_view.dart';
import 'package:gu_kulupler/features/admin/view/admin_reports_view.dart';
import 'package:gu_kulupler/features/admin/view/admin_users_view.dart';
import 'package:gu_kulupler/features/admin/view/mixin/admin_view_mixin.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_segment_bar.dart';
import 'package:gu_kulupler/product/navigation/admin_clubs_tab.dart';
import 'package:gu_kulupler/product/navigation/admin_reports_tab.dart';
import 'package:gu_kulupler/product/navigation/admin_tab.dart';
import 'package:gu_kulupler/product/navigation/admin_users_filter.dart';
import 'package:gu_ui/gu_ui.dart';

/// Admin — `AdminRoute` (`/admin?tab=`, Admin sekmesinin kökü; guard `S`:
/// yalnızca süper admin, router'da).
///
/// Kullanıcı kararı (2026-10-16; tasarımdan bilinçli sapma, K-94):
/// prototipte dört ayrı ekran olan Genel (ADM-01) · Kulüpler (ADM-02) ·
/// Şikayetler (ADM-04) · Kullanıcılar (ADM-05) **tek sayfadır**. Hepsi sekme
/// kökündedir: alt sekme çubuğu görünür, geri oku yoktur; `AdminSegmentBar`
/// sayfa değiştirmez, bölme içeriği kısa solmayla değişir
/// (`GuFadeIndexedStack`, `GuMotion.tabSwitch`). Her bölme hâlini korur
/// (arama metni, sekme, süzgeç, kaydırma konumu); bölmeler ilk seçildiğinde
/// kurulur (okuma o an başlar), yeniden seçildiğinde içerik kalarak yeniden
/// okunur (öteki bölmenin yazımı — SHT-26 askı, ADM-02 askı — bayat kalmaz). Alt sayfalar (ADM-03 kulüp formu, admin
/// CLB-07, SHT-26 şikayet ayrıntısı) ayrı sayfa / sheet olarak açılır; geri
/// aynı bölmeye döner.
///
/// Yukarıdan aşağıya: büyük başlık "Admin" + "Süper Admin" rozeti ·
/// `AdminSegmentBar` (seçili bölme; anahtarlar `<bölme ekranı>.seg.<hedef>`)
/// · bölme: [AdminOverviewView] · [AdminClubsView] · [AdminReportsView] ·
/// [AdminUsersView].
///
/// Rota sorgusu komuttur ([tab] ve bölme hâlleri yalnızca değişip dolu
/// geldiğinde uygulanır; `AdminRoute`). Davranış `AdminViewMixin`'dedir.
///
/// Design: ADM-01
class AdminView extends ConsumerStatefulWidget {
  /// Admin sekme kökü; parametreler rotanın sorgusudur.
  const AdminView({
    this.tab,
    this.clubsTab,
    this.reportsTab,
    this.reportId,
    this.filter,
    super.key,
  });

  /// Açılacak bölme (`?tab=`; `null` → son seçili, ilk açılışta genel bakış).
  final AdminTab? tab;

  /// Kulüpler bölmesinin açılacak sekmesi (`?clubsTab=`).
  final AdminClubsTab? clubsTab;

  /// Şikayetler bölmesinin açılacak sekmesi (`?reportsTab=`).
  final AdminReportsTab? reportsTab;

  /// Şikayetler bölmesinde SHT-26'sı açılacak grup (`?reportId=`).
  final String? reportId;

  /// Kullanıcılar bölmesinin seçilecek süzgeci (`?filter=`).
  final AdminUsersFilter? filter;

  @override
  ConsumerState<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends ConsumerState<AdminView> with AdminViewMixin {
  /// Bölmeli geçiş seçenek anahtarı — bölmenin ekran kimliği önekiyle
  /// (envanter: `ADM-01.seg.*`, `ADM-02.seg.*`, `ADM-04.seg.*`,
  /// `ADM-05.seg.*`).
  Key _segmentKey(AdminTab tab, String screenId) => switch (tab) {
    AdminTab.overview => GuKey.action('ADM-01.seg.$screenId'),
    AdminTab.clubs => GuKey.action('ADM-02.seg.$screenId'),
    AdminTab.reports => GuKey.action('ADM-04.seg.$screenId'),
    AdminTab.users => GuKey.action('ADM-05.seg.$screenId'),
  };

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final tab = current;

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
            current: AdminSegmentBar.screenOf(tab),
            onSelect: (screenId) => selectTab(AdminSegmentBar.tabOf(screenId)),
            keyOf: (screenId) => _segmentKey(tab, screenId),
          ),
          Expanded(
            child: GuFadeIndexedStack(
              index: tab.index,
              lazy: true,
              children: [
                for (final section in AdminTab.values)
                  switch (section) {
                    AdminTab.overview => AdminOverviewView(
                      active: tab == section,
                      onOpen: selectTab,
                    ),
                    AdminTab.clubs => AdminClubsView(
                      tab: widget.clubsTab,
                      active: tab == section,
                    ),
                    AdminTab.reports => AdminReportsView(
                      tab: widget.reportsTab,
                      reportId: widget.reportId,
                      active: tab == section,
                    ),
                    AdminTab.users => AdminUsersView(
                      filter: widget.filter,
                      active: tab == section,
                    ),
                  },
              ],
            ),
          ),
        ],
      ),
    );
  }
}
