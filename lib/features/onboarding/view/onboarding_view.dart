import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/onboarding/provider/onboarding_state.dart';
import 'package:gu_kulupler/features/onboarding/provider/onboarding_view_model.dart';
import 'package:gu_kulupler/features/onboarding/view/mixin/onboarding_view_mixin.dart';
import 'package:gu_kulupler/features/onboarding/view/widget/onboarding_slide.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/widget/system/language_menu_button.dart';
import 'package:gu_ui/gu_ui.dart';

/// Tanıtım ekranı — prototip `Onboarding` (`screens-auth.js:44–51`),
/// `OnboardingRoute` (`/onboarding`; yalnızca ilk açılışta, R2).
///
/// * Üst satır (dolgu 4 / 8 / 0 / 16): solda dil düğmesi (SHT-01 açılır
///   menüsü), sağda "Atla".
/// * Slayt şeridi (`.onb-track`, css:393): üç slayt — Keşfet, Katıl, Takip
///   et; yatay kaydırma slayta oturur.
/// * Alt blok (dolgu 0 / 24 / gerçek alt güvenli alan + 16, aralık 16):
///   sayfa noktaları + "İleri" (son slaytta "Başla").
///
/// "Atla" ve "Başla" tanıtımı bitirir: bayrak yazılır, girişe geçilir.
/// Ekranın yükleniyor / boş / hata / çevrimdışı durumu yoktur (veri okumaz).
///
/// Design: ONB-01
class OnboardingView extends ConsumerStatefulWidget {
  /// Tanıtım ekranı.
  const OnboardingView({super.key});

  /// Slaytlar, sırasıyla (`slides = ['discover', 'join', 'follow']`,
  /// `screens-auth.js:45`): çizim, başlık, açıklama.
  static List<({GuIllustrations illustration, String title, String desc})>
  slidesOf(AppLocalizations l10n) => [
    (
      illustration: GuIllustrations.onbDiscover,
      title: l10n.onbDiscoverTitle,
      desc: l10n.onbDiscoverDesc,
    ),
    (
      illustration: GuIllustrations.onbJoin,
      title: l10n.onbJoinTitle,
      desc: l10n.onbJoinDesc,
    ),
    (
      illustration: GuIllustrations.onbFollow,
      title: l10n.onbFollowTitle,
      desc: l10n.onbFollowDesc,
    ),
  ];

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView>
    with OnboardingViewMixin {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(onboardingViewModelProvider);
    final safeArea = MediaQuery.viewPaddingOf(context);
    final slides = OnboardingView.slidesOf(l10n);
    assert(
      slides.length == OnboardingState.pageCount,
      'ONB-01: slayt sayısı OnboardingState.pageCount ile aynı olmalı',
    );
    return Scaffold(
      backgroundColor: context.gu.colors.bgCanvas,
      body: Padding(
        padding: GuInsets.only(top: safeArea.top),
        child: Column(
          children: [
            Padding(
              padding: GuInsets.only(
                left: GuSpacing.s16,
                top: GuSpacing.s4,
                right: GuSpacing.s8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LanguageMenuButton(key: GuKey.action('ONB-01.lang')),
                  Flexible(
                    child: GuButton(
                      key: GuKey.action('ONB-01.skip'),
                      label: l10n.onbSkip,
                      variant: GuButtonVariant.text,
                      size: GuButtonSize.sm,
                      onPressed: onFinish,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                key: GuKey.action('ONB-01.swipe'),
                controller: pageController,
                onPageChanged: onPageChanged,
                children: [
                  for (final slide in slides)
                    OnboardingSlide(
                      illustration: slide.illustration,
                      title: slide.title,
                      description: slide.desc,
                    ),
                ],
              ),
            ),
            Padding(
              padding: GuInsets.only(
                left: GuSpacing.s24,
                right: GuSpacing.s24,
                bottom: safeArea.bottom + GuSpacing.s16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: GuSpacing.s16,
                children: [
                  GuPageDots(
                    count: OnboardingState.pageCount,
                    index: state.pageIndex,
                  ),
                  if (state.isLastPage)
                    GuButton(
                      key: GuKey.action('ONB-01.start'),
                      label: l10n.onbStart,
                      size: GuButtonSize.lg,
                      full: true,
                      onPressed: onFinish,
                    )
                  else
                    GuButton(
                      key: GuKey.action('ONB-01.next'),
                      label: l10n.onbNext,
                      size: GuButtonSize.lg,
                      full: true,
                      iconTrailing: GuIcons.arrowRight,
                      onPressed: onNext,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
