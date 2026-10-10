import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';

/// Build sırasında çöken alt ağacın yerine çizilecek görünüm (D-23).
///
/// Üretimde gri/kırmızı çerçeve hatası yerine tasarımın hata durumu
/// ([GuErrorState], SYS-02 gövdesi) gösterilir; debug derlemede geliştirici
/// hatayı görsün diye Flutter'ın kırmızı ekranı korunur.
abstract final class ErrorBoundary {
  /// `ErrorWidget.builder`'ı [builder]'a bağlar (`AppErrorHandler.install`
  /// çağırır).
  static void install() {
    ErrorWidget.builder = builder;
  }

  /// [details] hatası için yer tutucu. [debug] yalnızca testte verilir.
  static Widget builder(
    FlutterErrorDetails details, {
    bool debug = kDebugMode,
  }) => debug
      ? ErrorWidget.withDetails(
          message: details.exceptionAsString(),
          error: details.exception is FlutterError
              ? details.exception as FlutterError
              : null,
        )
      : const ErrorBoundaryFallback();
}

/// Çöken alt ağacın üretimdeki yer tutucusu: [GuErrorState] (liste içi
/// boyut) + "Yeniden dene".
///
/// Yeniden deneme, bu öğenin atalarını yeniden kurar: çöken `build` yeniden
/// çalışır; başarılıysa yer tutucu kendiliğinden kalkar. Tema ya da
/// yerelleştirme ağaçta yoksa (hata `MaterialApp`'in üstünde oluştuysa) boş
/// alan çizilir — yer tutucunun kendisi asla fırlatmamalıdır.
class ErrorBoundaryFallback extends StatelessWidget {
  /// Yer tutucuyu oluşturur.
  const ErrorBoundaryFallback({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    // ignore-hardcode: context.gu tema yoksa fırlatır; burada yokluk sınanır
    final hasTheme = Theme.of(context).extension<GuColors>() != null;
    if (l10n == null || !hasTheme) return const SizedBox.shrink();
    return SingleChildScrollView(
      child: GuErrorState(
        title: l10n.sysErrorTitle,
        description: l10n.sysErrorDesc,
        retryLabel: l10n.commonRetry,
        inline: true,
        onRetry: () async => _rebuildAncestors(context),
      ),
    );
  }

  static void _rebuildAncestors(BuildContext context) {
    if (!context.mounted) return;
    context.visitAncestorElements((element) {
      element.markNeedsBuild();
      return true;
    });
  }
}
