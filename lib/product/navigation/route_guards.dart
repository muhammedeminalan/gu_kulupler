import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';

/// Bir rotaya kimin girebileceği — navigation.md §2 / PLAN §13.3 "Guard"
/// sütununun kod hali.
enum RouteAccess {
  /// Guard yok (`—`): `/splash`, sistem ekranları, `/legal/:tip`.
  public,

  /// Misafir (`G`): oturum yokken açık (tanıtım, giriş, kayıt, sıfırlama).
  guest,

  /// Oturum var, e-posta doğrulanmamış (`/verify`).
  unverified,

  /// Doğrulanmış, profil eksik (`/setup-profile`).
  profileIncomplete,

  /// Aktif oturum (`A`): doğrulanmış + profil tamam.
  active,

  /// O kulübün içini gören (`üye`; Rules `seesInside`).
  member,

  /// O kulüpte yönetici (`M`; `board` / `president`).
  manager,

  /// Yönetim panelini gören (`V`; yönetici ya da salt okunur danışman).
  managerOrAdvisor,

  /// Süper admin (`S`).
  superAdmin,

  /// Yalnızca `AppEnvironment.debugMenuEnabled` iken (`/debug`, CD-69).
  debugOnly,
}

/// Bir guard'ın yönlendirme kararı: gidilecek yol ve varsa gösterilecek toast.
typedef GuardRedirect = ({String location, ToastId? toast});

/// [RouteAccessTable.match] sonucu.
final class RouteAccessMatch {
  /// Eşleşme sonucu oluşturur.
  const RouteAccessMatch({
    required this.access,
    required this.path,
    this.pattern,
    this.pathParameters = const <String, String>{},
  });

  /// Yolun erişim kuralı.
  final RouteAccess access;

  /// Sondaki `/` ve boş parçalar atılmış yol.
  final String path;

  /// Eşleşen kalıp; tabloda karşılığı olmayan yolda `null`.
  final String? pattern;

  /// Kalıptaki `:ad` parçalarının değerleri.
  final Map<String, String> pathParameters;

  /// Yoldaki kulüp kimliği (`:clubId`); yoksa `null`.
  String? get clubId => pathParameters[RouteAccessTable.clubIdParameter];
}

/// Yol kalıbı → [RouteAccess] tablosu (PLAN §13.3; 57 kalıp).
///
/// Rota sınıfları sahip task'larında eklenir; guard tablosu ise baştan
/// tamdır — bir ekranın rotası eklendiği anda koruması hazırdır.
abstract final class RouteAccessTable {
  /// Kulüp kimliği yol parametresinin adı.
  static const String clubIdParameter = 'clubId';

  /// `/legal/:tip` parametresinin adı.
  static const String legalTabParameter = 'tip';

  /// Yasal metin rotasının kalıbı (AUT-06).
  static const String legalPattern = '/legal/:tip';

  /// Kalıp → erişim; sıra PLAN §13.3 tablolarıyla aynıdır (eşit puanlı iki
  /// kalıpta önce yazılan kazanır — go_router'ın eşleme sırası).
  static const Map<String, RouteAccess> patterns = <String, RouteAccess>{
    // Kabuksuz (12)
    AppPaths.splash: RouteAccess.public,
    AppPaths.error: RouteAccess.public,
    AppPaths.offline: RouteAccess.public,
    AppPaths.notFound: RouteAccess.public,
    AppPaths.debug: RouteAccess.debugOnly,
    AppPaths.onboarding: RouteAccess.guest,
    AppPaths.login: RouteAccess.guest,
    '/login/register': RouteAccess.guest,
    '/login/reset': RouteAccess.guest,
    AppPaths.verify: RouteAccess.unverified,
    AppPaths.setupProfile: RouteAccess.profileIncomplete,
    legalPattern: RouteAccess.public,
    // Kulüpler (20)
    AppPaths.clubs: RouteAccess.active,
    '/clubs/search': RouteAccess.active,
    '/clubs/user/:userId': RouteAccess.active,
    '/clubs/:clubId': RouteAccess.active,
    '/clubs/:clubId/applied': RouteAccess.active,
    '/clubs/:clubId/application': RouteAccess.active,
    '/clubs/:clubId/members': RouteAccess.member,
    '/clubs/:clubId/posts/:postId': RouteAccess.member,
    '/clubs/:clubId/compose': RouteAccess.manager,
    '/clubs/:clubId/manage': RouteAccess.managerOrAdvisor,
    '/clubs/:clubId/manage/applications': RouteAccess.managerOrAdvisor,
    '/clubs/:clubId/manage/members': RouteAccess.managerOrAdvisor,
    '/clubs/:clubId/manage/events': RouteAccess.managerOrAdvisor,
    '/clubs/:clubId/manage/events/new': RouteAccess.manager,
    '/clubs/:clubId/manage/events/:eventId/edit': RouteAccess.manager,
    '/clubs/:clubId/manage/events/:eventId/attendance':
        RouteAccess.managerOrAdvisor,
    '/clubs/:clubId/manage/events/:eventId/attendance/scan':
        RouteAccess.manager,
    '/clubs/:clubId/manage/content': RouteAccess.managerOrAdvisor,
    '/clubs/:clubId/manage/settings': RouteAccess.managerOrAdvisor,
    '/clubs/:clubId/manage/activity': RouteAccess.managerOrAdvisor,
    // Etkinlikler (5)
    AppPaths.events: RouteAccess.active,
    '/events/:eventId': RouteAccess.active,
    '/events/:eventId/ticket': RouteAccess.active,
    '/events/mine': RouteAccess.active,
    '/events/search': RouteAccess.active,
    // Bildirimler (2)
    AppPaths.notifications: RouteAccess.active,
    '/notifications/preferences': RouteAccess.active,
    // Profil (11)
    AppPaths.profile: RouteAccess.active,
    '/profile/edit': RouteAccess.active,
    '/profile/clubs': RouteAccess.active,
    '/profile/saved': RouteAccess.active,
    '/profile/settings': RouteAccess.active,
    '/profile/settings/notifications': RouteAccess.active,
    '/profile/settings/blocked': RouteAccess.active,
    '/profile/settings/blocked/:userId': RouteAccess.active,
    '/profile/settings/delete': RouteAccess.active,
    '/profile/settings/about': RouteAccess.active,
    '/profile/settings/support': RouteAccess.active,
    // Admin (7)
    AppPaths.admin: RouteAccess.superAdmin,
    '/admin/clubs': RouteAccess.superAdmin,
    '/admin/clubs/new': RouteAccess.superAdmin,
    '/admin/clubs/:clubId/edit': RouteAccess.superAdmin,
    '/admin/reports': RouteAccess.superAdmin,
    '/admin/users': RouteAccess.superAdmin,
    '/admin/users/:userId': RouteAccess.superAdmin,
  };

  static const String _parameterPrefix = ':';
  static const String _manageSegment = 'manage';

  /// [location] yolunun erişim kuralı ([match]`.access`).
  static RouteAccess accessOf(Uri location) => match(location).access;

  /// [location] yolunu tabloyla eşler.
  ///
  /// Aynı uzunluktaki kalıplardan sabit parçası en çok olan kazanır
  /// (`/clubs/search`, `/clubs/:clubId`'den önce gelir). Tabloda olmayan yol
  /// **korumalı** sayılır: `/admin/**` süper admin, `/clubs/:clubId/manage/**`
  /// yönetim, kalan her şey aktif oturum ister (bilinmeyen yol oturumsuzken
  /// içerik göstermez; oturum açıkken SYS-04'e düşer).
  static RouteAccessMatch match(Uri location) {
    final segments = _segmentsOf(location.path);
    final path = '/${segments.join('/')}';
    String? bestPattern;
    var bestParameters = const <String, String>{};
    var bestScore = -1;
    for (final pattern in patterns.keys) {
      final patternSegments = _segmentsOf(pattern);
      if (patternSegments.length != segments.length) continue;
      final parameters = <String, String>{};
      var score = 0;
      var matched = true;
      for (var index = 0; index < segments.length; index++) {
        final expected = patternSegments[index];
        if (expected.startsWith(_parameterPrefix)) {
          parameters[expected.substring(_parameterPrefix.length)] =
              segments[index];
        } else if (expected == segments[index]) {
          score++;
        } else {
          matched = false;
          break;
        }
      }
      if (matched && score > bestScore) {
        bestPattern = pattern;
        bestParameters = parameters;
        bestScore = score;
      }
    }
    if (bestPattern != null) {
      return RouteAccessMatch(
        access: patterns[bestPattern]!,
        path: path,
        pattern: bestPattern,
        pathParameters: bestParameters,
      );
    }
    return _fallback(path, segments);
  }

  static RouteAccessMatch _fallback(String path, List<String> segments) {
    final root = segments.isEmpty ? '' : '/${segments.first}';
    if (root == AppPaths.admin) {
      return RouteAccessMatch(access: RouteAccess.superAdmin, path: path);
    }
    const manageIndex = 2;
    if (root == AppPaths.clubs &&
        segments.length > manageIndex &&
        segments[manageIndex] == _manageSegment) {
      return RouteAccessMatch(
        access: RouteAccess.managerOrAdvisor,
        path: path,
        pathParameters: <String, String>{clubIdParameter: segments[1]},
      );
    }
    return RouteAccessMatch(access: RouteAccess.active, path: path);
  }

  static List<String> _segmentsOf(String path) =>
      path.split('/').where((segment) => segment.isNotEmpty).toList();
}

/// Oturum durumuna göre yönlendirme — PLAN §13.4 satır R1–R7.
abstract final class AuthGuard {
  /// [session] durumundaki kullanıcı [location] yoluna girebilir mi? Giremezse
  /// gideceği yer; girebilirse `null`.
  ///
  /// Oturum guard'ından **muaf** yollar: `/debug` (yalnızca R14),
  /// `/legal/:tip` (yalnızca R12) ve kabuksuz sistem ekranları (`/error`,
  /// `/offline`, `/not-found`) — SYS-02 oturum çözülemediğinde, SYS-04 R12
  /// hedefi olarak oturumsuzken de gösterilebilmelidir.
  static GuardRedirect? check(SessionState session, Uri location) {
    final match = RouteAccessTable.match(location);
    final path = match.path;
    final isSplash = path == AppPaths.splash;
    if (match.access == RouteAccess.debugOnly) return null;
    if (match.access == RouteAccess.public && !isSplash) return null;

    switch (session.status) {
      case AuthStatus.unknown:
        // R1
        return isSplash ? null : _to(AppPaths.splash);
      case AuthStatus.signedOut:
        if (!session.onboardingSeen) {
          // R2
          return path == AppPaths.onboarding ? null : _to(AppPaths.onboarding);
        }
        // R3
        if (match.access == RouteAccess.guest && path != AppPaths.onboarding) {
          return null;
        }
        return _to(loginLocation(from: location));
      case AuthStatus.unverified:
        // R4
        return path == AppPaths.verify ? null : _to(AppPaths.verify);
      case AuthStatus.profileIncomplete:
        // R5
        return path == AppPaths.setupProfile
            ? null
            : _to(AppPaths.setupProfile);
      case AuthStatus.suspended:
        // R6 — oturumu kapatma ve DLG-01 yan etkisi oturum katmanındadır.
        return path == AppPaths.login ? null : _to(AppPaths.login);
      case AuthStatus.active:
        // R7
        if (!isSplash && !_authOnly.contains(match.access)) return null;
        return _to(returnLocation(location) ?? AppPaths.clubs);
    }
  }

  /// Giriş yolu; [from] bir uygulama (kabuk) rotasıysa dönüş adresi olarak
  /// `from` sorgusuna yazılır (`Uri.encodeQueryComponent`).
  static String loginLocation({required Uri from}) {
    if (GuTab.ofLocation(from) == null) return AppPaths.login;
    // Yalnızca yol + sorgu taşınır (şema / alan adı dönüş adresine girmez).
    final target = from.hasQuery ? '${from.path}?${from.query}' : from.path;
    final encoded = Uri.encodeQueryComponent(target);
    return '${AppPaths.login}?$fromParameter=$encoded';
  }

  /// [location]'ın `from` sorgusundaki dönüş adresi; yalnızca `/` ile
  /// başlayan bir uygulama (kabuk) yoluysa geçerlidir. Dış adres
  /// (`http://…`, `//host`) ve oturum öncesi yollar (`/login`) `null` verir.
  static String? returnLocation(Uri location) {
    final from = location.queryParameters[fromParameter];
    if (from == null || !from.startsWith('/') || from.startsWith('//')) {
      return null;
    }
    final target = Uri.tryParse(from);
    if (target == null || target.hasScheme || target.hasAuthority) return null;
    return GuTab.ofLocation(target) == null ? null : from;
  }

  /// Dönüş adresi sorgu parametresi (`/login?from=`, `/error?from=`).
  static const String fromParameter = 'from';

  /// Aktif oturumun işinin olmadığı (R7) erişim türleri.
  static const Set<RouteAccess> _authOnly = <RouteAccess>{
    RouteAccess.guest,
    RouteAccess.unverified,
    RouteAccess.profileIncomplete,
  };

  static GuardRedirect _to(String location) =>
      (location: location, toast: null);
}

/// Role göre yönlendirme — PLAN §13.4 satır R8–R11. Yalnızca aktif oturumda
/// çalışır; karar `RolePolicy` ile verilir (Rules ile aynı matris).
///
/// Arayüz koruması yetkinin kendisi değildir: yetkiyi Security Rules uygular.
abstract final class RoleGuard {
  /// [session] rolüyle [location] yoluna girilemiyorsa gidilecek yer ve
  /// gösterilecek toast; girilebiliyorsa `null`.
  static GuardRedirect? check(SessionState session, Uri location) {
    if (session.status != AuthStatus.active) return null;
    final match = RouteAccessTable.match(location);
    final isSuper = session.isSuperAdmin;
    if (match.access == RouteAccess.superAdmin) {
      // R8
      return isSuper ? null : (location: AppPaths.clubs, toast: ToastId.tstX18);
    }
    final clubId = match.clubId;
    if (clubId == null) return null;
    final role = session.roleIn(clubId);
    final clubLocation = '${AppPaths.clubs}/$clubId';
    final manageLocation = '$clubLocation/$_manageSegment';
    bool can(ClubPermission permission) =>
        RolePolicy.can(permission, role, isSuper: isSuper);

    switch (match.access) {
      case RouteAccess.managerOrAdvisor:
        // R9
        return can(ClubPermission.viewManagement)
            ? null
            : (location: clubLocation, toast: ToastId.tstX18);
      case RouteAccess.manager:
        // Yazma ekranları (gönderi, etkinlik formu, QR): Rules `isManager`.
        if (can(ClubPermission.createPost)) return null;
        if (!can(ClubPermission.viewManagement)) {
          // R9 (yönetimi hiç göremeyen)
          return (location: clubLocation, toast: ToastId.tstX18);
        }
        // R11 — danışman salt okunur; kulüpte rolü olmayan süper admin de
        // yönetimi görür ama yazamaz (danışman metni ona gösterilmez).
        return (
          location: manageLocation,
          toast: role == ClubRole.advisor ? ToastId.tst26 : ToastId.tstX18,
        );
      case RouteAccess.member:
        // R10 — toast yok: CLB-03 üyelik bandını gösterir.
        return can(ClubPermission.viewInside)
            ? null
            : (location: clubLocation, toast: null);
      case RouteAccess.public:
      case RouteAccess.guest:
      case RouteAccess.unverified:
      case RouteAccess.profileIncomplete:
      case RouteAccess.active:
      case RouteAccess.superAdmin:
      case RouteAccess.debugOnly:
        return null;
    }
  }

  static const String _manageSegment = 'manage';
}

/// Yol parametresi denetimi — PLAN §13.4 satır R12 (K-06).
abstract final class RouteParamGuard {
  /// `/legal/:tip` için geçerli değerler (AUT-06 sekmeleri).
  static const Set<String> legalTabs = <String>{
    'kosullar',
    'gizlilik',
    'kvkk',
  };

  /// [location] geçersiz bir yol parametresi taşıyorsa SYS-04'e yönlendirir.
  static GuardRedirect? check(Uri location) {
    final match = RouteAccessTable.match(location);
    if (match.pattern != RouteAccessTable.legalPattern) return null;
    final tab = match.pathParameters[RouteAccessTable.legalTabParameter];
    return legalTabs.contains(tab)
        ? null
        : (location: AppPaths.notFound, toast: null);
  }
}

/// DebugMenu rotasının guard'ı — PLAN §13.4 satır R14 (CD-69).
abstract final class DebugRouteGuard {
  /// `/debug` yalnızca `AppEnvironment.debugMenuEnabled` iken açılır; değilse
  /// SYS-04. [enabled] yalnızca testte verilir (bayrak derleme sabitidir).
  static GuardRedirect? check(
    Uri location, {
    bool enabled = AppEnvironment.debugMenuEnabled,
  }) {
    if (RouteAccessTable.accessOf(location) != RouteAccess.debugOnly) {
      return null;
    }
    return enabled ? null : (location: AppPaths.notFound, toast: null);
  }
}
