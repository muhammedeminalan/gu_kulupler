import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/system/view/widget/system_screen_scaffold.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/route_guards.dart';
import 'package:gu_ui/gu_ui.dart';

/// Hata ekranı — prototip `ErrorScreen` (`screens-auth.js:36`) +
/// `ErrorState` (`ui.js:104`). Oturum çözülemediğinde (açılış zaman aşımı,
/// oturum hatası) ve kurtarılamayan ekran hatalarında gösterilir.
///
/// * "Yeniden dene": oturumu yeniden çözer, sonra [from] yoluna (yoksa ana
///   sayfaya) gider; nereye varılacağına router karar verir.
/// * "Ana sayfaya dön" ve geri: ana sayfa (yığında sayfa varsa geri).
///
/// Design: SYS-02
class ErrorView extends ConsumerWidget {
  /// [from]: "Yeniden dene" ile dönülecek yol (`/error?from=`).
  const ErrorView({this.from, super.key});

  /// Yeniden denenecek yol; yoksa `null`.
  final String? from;

  /// [from] geçerli bir uygulama yoluysa o, değilse ana sayfa (dış adres ve
  /// oturum öncesi yollar dönüş adresi olamaz).
  String get retryLocation {
    final uri = Uri(
      path: AppPaths.error,
      queryParameters: {if (from != null) AuthGuard.fromParameter: from},
    );
    return AuthGuard.returnLocation(uri) ?? AppPaths.clubs;
  }

  Future<void> _retry(BuildContext context, WidgetRef ref) async {
    await ref.read(sessionViewModelProvider.notifier).resolve();
    if (!context.mounted) return;
    context.go(retryLocation);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SystemScreenScaffold(
      backActionKey: GuKey.action('SYS-02.back'),
      child: GuErrorState(
        title: l10n.sysErrorTitle,
        description: l10n.sysErrorDesc,
        retryLabel: l10n.commonRetry,
        retryActionKey: GuKey.action('SYS-02.retry'),
        onRetry: () => _retry(context, ref),
        homeLabel: l10n.sysErrorHome,
        homeActionKey: GuKey.action('SYS-02.home'),
        onHome: () => SystemScreenScaffold.goHome(context),
      ),
    );
  }
}
