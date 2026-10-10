import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/route_guards.dart';
import 'package:gu_kulupler/product/navigation/splash_hold.dart';

/// [AppRedirect.resolve] kararı: gidilecek yol ve varsa gösterilecek toast.
final class AppRedirectResult extends Equatable {
  /// Yönlendirme sonucu oluşturur.
  const AppRedirectResult({required this.location, this.toast});

  /// Gidilecek yol (sorgusuyla).
  final String location;

  /// Yönlendirmeyle birlikte gösterilecek toast; yoksa `null`.
  final ToastId? toast;

  @override
  List<Object?> get props => [location, toast];
}

/// Router'ın tek yönlendirme kararı (navigation.md §3, PLAN §13.4).
///
/// Kimlik ve rol kararları **yalnızca** buradadır; view içinden oturum
/// amaçlı `go` yazılmaz.
abstract final class AppRedirect {
  /// [session] durumundaki kullanıcı [location] yoluna girerken nereye
  /// yönlendirilir? Yönlendirme yoksa `null` (R13).
  ///
  /// **Saf fonksiyondur** (tablo testi: `app_redirect_test.dart`). Sıra:
  /// R1 → R14 → R12 → R2–R7 → R8–R11 → R13. `/debug` ve `/legal/:tip` oturum
  /// guard'ından (R1–R7) muaf olduğundan R14 ve R12'nin R1'den önce
  /// değerlendirilmesi aynı sonucu verir.
  ///
  /// [debugMenuEnabled] yalnızca testte verilir (R14 bayrağı derleme
  /// sabitidir).
  static AppRedirectResult? resolve(
    SessionState session,
    Uri location, {
    bool debugMenuEnabled = AppEnvironment.debugMenuEnabled,
  }) {
    final redirect =
        DebugRouteGuard.check(location, enabled: debugMenuEnabled) ??
        RouteParamGuard.check(location) ??
        AuthGuard.check(session, location) ??
        RoleGuard.check(session, location);
    if (redirect == null) return null;
    return AppRedirectResult(
      location: redirect.location,
      toast: redirect.toast,
    );
  }

  /// `GoRouter.redirect` bağlaması: oturumu okur, [resolve] kararını uygular;
  /// kararda toast varsa bir sonraki karede gösterir.
  ///
  /// Açılış beklemesi (`SplashHold`) sürerken `/splash`'ten çıkılmaz: açılış
  /// ekranı en az logo animasyonu kadar görünür (architecture §4). Bekleme
  /// kalkınca yönlendirme yeniden değerlendirilir.
  static String? goRouterRedirect(BuildContext context, GoRouterState state) {
    final container = ProviderScope.containerOf(context, listen: false);
    if (state.uri.path == AppPaths.splash &&
        container.read(splashHoldProvider)) {
      return null;
    }
    final result = resolve(
      container.read(sessionViewModelProvider),
      state.uri,
    );
    if (result == null) return null;
    final toast = result.toast;
    if (toast != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        container.read(feedbackServiceProvider).showToast(toast);
      });
    }
    return result.location;
  }
}
