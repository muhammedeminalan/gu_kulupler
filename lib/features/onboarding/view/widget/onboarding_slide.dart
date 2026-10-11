import 'package:flutter/widgets.dart';
import 'package:gu_ui/gu_ui.dart';

/// ONB-01 tek slaytı — prototip `.onb-track > section` (css:393;
/// `screens-auth.js:48`): 200 px illüstrasyon, `display` başlık, `bodyL`
/// ikincil açıklama; ortalı, yatay dolgu 32, aralık 16.
///
/// İçerik slayt alanında dikeyde ortalanır; alan yetmezse (küçük ekran +
/// büyük yazı) slayt kendi içinde kayar.
class OnboardingSlide extends StatelessWidget {
  /// [title] ve [description] çağırandan (ARB) gelir.
  const OnboardingSlide({
    required this.illustration,
    required this.title,
    required this.description,
    super.key,
  });

  /// `Illustration size=${200}` (`screens-auth.js:48`). Adlı token yok:
  /// değer illüstrasyon boyut listesinin en büyüğüdür (K-48).
  static double get illustrationSize => GuSizes.illustrationSizes.last;

  /// Slaytın çizimi.
  final GuIllustrations illustration;

  /// Başlık (`onb.<slayt>.title`).
  final String title;

  /// Açıklama (`onb.<slayt>.desc`).
  final String description;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: GuInsets.sym(h: GuSizes.onboardingPaddingX),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: GuSizes.onboardingGap,
                children: [
                  GuIllustration(illustration, size: illustrationSize),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: gu.text.display,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Text(
                    description,
                    style: gu.text.bodyL.copyWith(
                      color: gu.colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
