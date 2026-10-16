import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/features/admin/view/admin_view.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';

/// Admin kökünün davranışı: seçili bölme ve rota sorgusuyla eşitleme
/// (kullanıcı kararı 2026-10-16 — ADM-01 / 02 / 04 / 05 tek sayfa).
///
/// * Seçili bölme sayfanın hâlidir ([current]); ilk değer rotanın `?tab=`
///   değeri, yoksa genel bakış.
/// * Rota sorgusu komuttur: `?tab=` **değişip dolu** geldiğinde uygulanır
///   (bildirim `new_report` → Şikayetler, ADM-03 kaydı → Kulüpler). Alt
///   sayfaya geçerken ebeveyn sorgusuz kurulur (`tab` boşalır); bu hâli
///   değiştirmez — geri dönüşte aynı bölme açıktır.
/// * Bölme seçimi ([selectTab]: `AdminSegmentBar`, ADM-01 göstergeleri)
///   hâli hemen değiştirir ve adresi `AdminRoute`'a `go` ile eşitler (yığın
///   değişmez: aynı sayfa anahtarı, geçiş yok). Genel bakış sorgusuz yoldur
///   (`/admin`).
mixin AdminViewMixin on ConsumerState<AdminView> {
  late AdminTab _current = widget.tab ?? AdminTab.overview;

  /// Sahnedeki bölme.
  AdminTab get current => _current;

  @override
  void didUpdateWidget(AdminView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tab = widget.tab;
    if (tab != null && tab != oldWidget.tab) _current = tab;
  }

  /// [tab] bölmesini açar; [clubsTab] / [reportsTab] o bölmenin sekmesini
  /// seçer (ADM-01 "Askıdaki kulüp" → Kulüpler › Askıda).
  void selectTab(
    AdminTab tab, {
    AdminClubsTab? clubsTab,
    AdminReportsTab? reportsTab,
  }) {
    if (tab == _current && clubsTab == null && reportsTab == null) return;
    if (tab != _current) setState(() => _current = tab);
    // Router'sız (durum kipi) testlerde adres eşitlenmez; hâl yine değişir.
    GoRouter.maybeOf(context)?.go(
      AdminRoute(
        tab: tab == AdminTab.overview ? null : tab,
        clubsTab: clubsTab,
        reportsTab: reportsTab,
      ).location,
    );
  }
}
