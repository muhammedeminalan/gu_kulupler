import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/features/auth/view/legal_view.dart';
import 'package:gu_kulupler/features/auth/view/login_view.dart';
import 'package:gu_kulupler/features/auth/view/register_view.dart';
import 'package:gu_kulupler/features/auth/view/reset_password_view.dart';
import 'package:gu_kulupler/features/auth/view/setup_profile_view.dart';
import 'package:gu_kulupler/features/auth/view/verify_email_view.dart';
import 'package:gu_kulupler/features/onboarding/view/onboarding_view.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/gu_page_transitions.dart';
import 'package:gu_kulupler/product/navigation/legal_tab.dart';
import 'package:gu_kulupler/product/navigation/route_guards.dart';

export 'package:gu_kulupler/product/navigation/legal_tab.dart'
    show LegalOrigin, LegalTab;

part 'auth_routes.g.dart';

// Oturum öncesi rotalar (navigation.md §2.1, PLAN §13.3.1).

/// ONB-01 Tanıtım — `/onboarding`.
@TypedGoRoute<OnboardingRoute>(path: AppPaths.onboarding)
final class OnboardingRoute extends GoRouteData
    with $OnboardingRoute, FadePageMixin {
  /// Tanıtım rotası.
  const OnboardingRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const OnboardingView();
}

/// AUT-01 Giriş — `/login?from=`. Alt rotaları: [RegisterRoute],
/// [ResetPasswordRoute].
@TypedGoRoute<LoginRoute>(
  path: AppPaths.login,
  routes: [
    TypedGoRoute<RegisterRoute>(path: RegisterRoute.segment),
    TypedGoRoute<ResetPasswordRoute>(path: ResetPasswordRoute.segment),
  ],
)
final class LoginRoute extends GoRouteData with $LoginRoute, FadePageMixin {
  /// [from]: giriş sonrası dönülecek uygulama yolu.
  const LoginRoute({this.from});

  /// Giriş sonrası dönüş adresi; yoksa `null`. Yönlendirme (R7) yoldan okur.
  final String? from;

  @override
  Widget build(BuildContext context, GoRouterState state) => const LoginView();
}

/// AUT-02 Kayıt ol — `/login/register`. AUT-01'in alt rotasıdır: `go` ile
/// açılır, geri AUT-01'e döner. Geçiş platform varsayılanıdır (PLAN §13.6).
final class RegisterRoute extends GoRouteData
    with $RegisterRoute, PlatformPageMixin {
  /// Kayıt rotası.
  const RegisterRoute();

  /// `/login` altındaki yol parçası.
  static const String segment = 'register';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const RegisterView();
}

/// AUT-04 Şifre sıfırlama — `/login/reset`. AUT-01'in alt rotasıdır: `go` ile
/// açılır (`AUT-01.forgot`, DLG-02 "Şifremi unuttum"), geri AUT-01'e döner.
/// Geçiş platform varsayılanıdır (PLAN §13.6).
final class ResetPasswordRoute extends GoRouteData
    with $ResetPasswordRoute, PlatformPageMixin {
  /// Şifre sıfırlama rotası.
  const ResetPasswordRoute();

  /// `/login` altındaki yol parçası.
  static const String segment = 'reset';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ResetPasswordView();
}

/// AUT-06 Yasal metinler — `/legal/:tip?from=`.
///
/// Guard'sızdır (her oturum durumunda açılır) ve uygulamada **`push` ile
/// açılan tek rotadır** (CLAUDE.md §5); geri, açan ekrana döner:
///
/// ```dart
/// LegalRoute(tip: LegalTab.kvkk).push<void>(context);
/// ```
///
/// İzinli çağıranlar `push_scan_test` listesindedir (PLAN §13.10). Geçersiz
/// `tip` rotaya ulaşmaz (R12 → SYS-04).
@TypedGoRoute<LegalRoute>(path: RouteAccessTable.legalPattern)
final class LegalRoute extends GoRouteData with $LegalRoute, PlatformPageMixin {
  /// [tip] ilk açılan sekmedir; [from] açan ekrandır (yalnızca kayıt formu
  /// bildirir).
  const LegalRoute({required this.tip, this.from});

  /// İlk açılan sekme (`kvkk` · `gizlilik` · `kosullar`).
  final LegalTab tip;

  /// Açan ekran (`?from=register`); kayıt formundan açılışta ekranın altında
  /// "Okudum, anladım" çubuğu gösterilir (`AUT-06.accept`).
  final LegalOrigin? from;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      LegalView(tip: tip, showAccept: from == LegalOrigin.register);
}

/// AUT-03 E-posta doğrulama — `/verify`.
@TypedGoRoute<VerifyEmailRoute>(path: AppPaths.verify)
final class VerifyEmailRoute extends GoRouteData
    with $VerifyEmailRoute, FadePageMixin {
  /// Doğrulama rotası.
  const VerifyEmailRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const VerifyEmailView();
}

/// AUT-05 Profil kurulumu — `/setup-profile`.
@TypedGoRoute<SetupProfileRoute>(path: AppPaths.setupProfile)
final class SetupProfileRoute extends GoRouteData
    with $SetupProfileRoute, FadePageMixin {
  /// Profil kurulumu rotası.
  const SetupProfileRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SetupProfileView();
}
