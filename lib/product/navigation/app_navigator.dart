import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_navigator.g.dart';

/// Kilitli üst düzey yollar (navigation.md §2) — rota bildirimleri,
/// yönlendirme tablosu ve sekme kökleri aynı sabitleri kullanır.
abstract final class AppPaths {
  /// SYS-01 Açılış.
  static const String splash = '/splash';

  /// SYS-02 Hata.
  static const String error = '/error';

  /// SYS-03 Çevrimdışı (tam ekran).
  static const String offline = '/offline';

  /// SYS-04 İçerik yok.
  static const String notFound = '/not-found';

  /// DebugMenu (tasarım kimliği yok; CD-69).
  static const String debug = '/debug';

  /// ONB-01 Tanıtım.
  static const String onboarding = '/onboarding';

  /// AUT-01 Giriş.
  static const String login = '/login';

  /// AUT-03 E-posta doğrulama.
  static const String verify = '/verify';

  /// AUT-05 Profil kurulumu.
  static const String setupProfile = '/setup-profile';

  /// CLB-01 Kulüpler (sekme kökü).
  static const String clubs = '/clubs';

  /// EVT-01 Etkinlikler (sekme kökü).
  static const String events = '/events';

  /// NTF-01 Bildirimler (sekme kökü).
  static const String notifications = '/notifications';

  /// ADM-01 Admin (sekme kökü).
  static const String admin = '/admin';

  /// PRF-01 Profil (sekme kökü).
  static const String profile = '/profile';
}

/// Alt sekmeler — sıra `registry.json#tabs` ve kabuk dallarıyla aynıdır
/// (PLAN §13.2): `index` dal sırasıdır.
enum GuTab {
  /// Kulüpler (CLB / FED / MGT ekranlarının ev sekmesi).
  clubs(AppPaths.clubs),

  /// Etkinlikler (EVT).
  events(AppPaths.events),

  /// Bildirimler (NTF).
  notifications(AppPaths.notifications),

  /// Admin (ADM) — yalnızca süper admine görünür.
  admin(AppPaths.admin),

  /// Profil (PRF / SET).
  profile(AppPaths.profile);

  const GuTab(this.rootPath);

  /// Sekme kökünün yolu.
  final String rootPath;

  /// Sekmenin dal gezgini.
  GlobalKey<NavigatorState> get navigatorKey => switch (this) {
    GuTab.clubs => clubsNavigatorKey,
    GuTab.events => eventsNavigatorKey,
    GuTab.notifications => notificationsNavigatorKey,
    GuTab.admin => adminNavigatorKey,
    GuTab.profile => profileNavigatorKey,
  };

  /// [location] hangi sekmenin ağacında (ilk yol parçasına göre); kabuk dışı
  /// yollarda `null`.
  static GuTab? ofLocation(Uri location) {
    final segments = _segments(location);
    if (segments.isEmpty) return null;
    final root = '/${segments.first}';
    for (final tab in values) {
      if (tab.rootPath == root) return tab;
    }
    return null;
  }

  /// [location] bir sekme kökü mü? Alt sekme çubuğu yalnızca burada görünür
  /// (derinlik 1 — navigation.md §1, PLAN §13.10).
  static bool isTabRoot(Uri location) =>
      _segments(location).length == 1 && ofLocation(location) != null;

  static List<String> _segments(Uri location) =>
      location.pathSegments.where((segment) => segment.isNotEmpty).toList();
}

/// Sekmeler arası bağlantı (Q-20 = A; PLAN §13.7).
abstract final class AppNavigator {
  /// [location] ekranını ev sekmesi [tab]'ın ağacında açar.
  ///
  /// `go` hedef dalı kendisi etkinleştirir ve o dalın yığınını rota ağacından
  /// `kök → … → hedef` olarak kurar; çağıran dalın yığını değişmez (alt
  /// çubuktan geri dönülür). Dal değiştirmek için ayrıca `goBranch`
  /// çağrılmaz.
  static void openInTab(BuildContext context, GuTab tab, String location) {
    assert(
      GuTab.ofLocation(Uri.parse(location)) == tab,
      'AppNavigator.openInTab: "$location" ${tab.name} sekmesinin '
      '(${tab.rootPath}) ağacında değil',
    );
    GoRouter.of(context).go(location);
  }
}

/// "Başa kaydır" isteği sayacı (prototip `scrollTopReq`): kullanıcı sekme
/// kökündeyken etkin sekmeye yeniden dokununca kabuk [request] çağırır; kök
/// ekran `ref.listen(scrollTopRequestProvider(tab), …)` ile listesini başa
/// kaydırır.
@Riverpod(keepAlive: true)
final class ScrollTopRequest extends _$ScrollTopRequest {
  @override
  int build(GuTab tab) => 0;

  /// Yeni bir başa kaydırma isteği yayınlar.
  void request() => state = state + 1;
}
