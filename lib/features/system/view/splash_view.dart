import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/system/provider/splash_view_model.dart';
import 'package:gu_kulupler/features/system/view/mixin/splash_view_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

/// Açılış ekranı — prototip `Splash` (`screens-auth.js:31–34`), CSS `.splash`
/// (css:391–392): ortada logo (96) + ürün adı, altta sürüm.
///
/// Oturum çözülene kadar gösterilir; çıkışı router yönlendirmesi yapar.
/// Davranış (animasyon, zaman aşımı, hata) `SplashViewMixin`'dedir. Blok tüm
/// ekranda ortalanır (`inset:0`); sürüm satırı alttan 40 dp yukarıdadır ve
/// gerçek alt güvenli alanın altına inmez (K-07).
///
/// Design: SYS-01
class SplashView extends ConsumerStatefulWidget {
  /// Açılış ekranı.
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView>
    with SingleTickerProviderStateMixin, SplashViewMixin {
  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final version = ref.watch(
      splashViewModelProvider.select((state) => state.version),
    );
    final versionBottom = math.max(
      GuSizes.splashVersionBottom,
      MediaQuery.viewPaddingOf(context).bottom + GuSpacing.s8,
    );
    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      body: Semantics(
        container: true,
        label: l10n.sysSplashTitle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Padding(
                padding: GuInsets.h24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: GuSizes.splashGap,
                  children: [
                    FadeTransition(
                      opacity: logoOpacity,
                      child: ScaleTransition(
                        scale: logoScale,
                        child: const GuLogo(size: GuSizes.splashLogo),
                      ),
                    ),
                    Text(
                      AppConstants.appName,
                      style: gu.text.splashTitle,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            if (version.isNotEmpty)
              Positioned(
                left: GuSpacing.s24,
                right: GuSpacing.s24,
                bottom: versionBottom,
                child: Text(
                  l10n.sysSplashVersion(version),
                  style: gu.text.caption,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
