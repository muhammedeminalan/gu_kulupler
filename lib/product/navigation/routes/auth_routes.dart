import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/gu_page_transitions.dart';
import 'package:gu_kulupler/product/navigation/routes/route_placeholder_view.dart';

part 'auth_routes.g.dart';

// Oturum öncesi rotalar (navigation.md §2.1). T-11 yalnızca yönlendirme
// hedeflerini kurar; kalan rota sınıfları sahip task'larında eklenir:
// TODO(T-13): `RegisterRoute` (`/login/register`), `LegalRoute`
// (`/legal/:tip`).
// TODO(T-14): `ResetPasswordRoute` (`/login/reset`).

/// ONB-01 Tanıtım — `/onboarding`.
@TypedGoRoute<OnboardingRoute>(path: AppPaths.onboarding)
final class OnboardingRoute extends GoRouteData
    with $OnboardingRoute, FadePageMixin {
  /// Tanıtım rotası.
  const OnboardingRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      // TODO(T-13): `OnboardingView` (W-01).
      RoutePlaceholderView(title: (l10n) => l10n.onbTitle);
}

/// AUT-01 Giriş — `/login?from=`.
@TypedGoRoute<LoginRoute>(path: AppPaths.login)
final class LoginRoute extends GoRouteData with $LoginRoute, FadePageMixin {
  /// [from]: giriş sonrası dönülecek uygulama yolu.
  const LoginRoute({this.from});

  /// Giriş sonrası dönüş adresi; yoksa `null`.
  final String? from;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      // TODO(T-13): `LoginView` (W-01).
      RoutePlaceholderView(title: (l10n) => l10n.authLoginTitle);
}

/// AUT-03 E-posta doğrulama — `/verify`.
@TypedGoRoute<VerifyEmailRoute>(path: AppPaths.verify)
final class VerifyEmailRoute extends GoRouteData
    with $VerifyEmailRoute, FadePageMixin {
  /// Doğrulama rotası.
  const VerifyEmailRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      // TODO(T-14): `VerifyEmailView` (W-02).
      RoutePlaceholderView(title: (l10n) => l10n.authVerifyTitle);
}

/// AUT-05 Profil kurulumu — `/setup-profile`.
@TypedGoRoute<SetupProfileRoute>(path: AppPaths.setupProfile)
final class SetupProfileRoute extends GoRouteData
    with $SetupProfileRoute, FadePageMixin {
  /// Profil kurulumu rotası.
  const SetupProfileRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      // TODO(T-14): `SetupProfileView` (W-02).
      RoutePlaceholderView(title: (l10n) => l10n.authSetupTitle);
}
