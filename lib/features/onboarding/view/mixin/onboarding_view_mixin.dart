import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/features/onboarding/provider/onboarding_view_model.dart';
import 'package:gu_kulupler/features/onboarding/view/onboarding_view.dart';
import 'package:gu_kulupler/product/navigation/routes/auth_routes.dart';
import 'package:gu_ui/gu_ui.dart';

/// ONB-01 ekranının etkileşim mantığı — prototip `Onboarding`
/// (`screens-auth.js:44–51`): slayt şeridinin denetleyicisi, "İleri" ve
/// tanıtımın bitişi ("Atla" / "Başla").
mixin OnboardingViewMixin on ConsumerState<OnboardingView> {
  /// Slayt şeridinin denetleyicisi (`.onb-track`, css:393).
  late final PageController pageController;

  @override
  void initState() {
    super.initState();
    pageController = PageController(
      initialPage: ref.read(onboardingViewModelProvider).pageIndex,
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  /// `ONB-01.swipe` — kaydırma yeni slayta oturdu (`onScroll`, `:48`).
  void onPageChanged(int index) =>
      ref.read(onboardingViewModelProvider.notifier).setPage(index);

  /// `ONB-01.next` — sıradaki slayta yumuşak geçiş (`go(i + 1)`, `:46`).
  void onNext() {
    ref.read(onboardingViewModelProvider.notifier).next();
    final target = ref.read(onboardingViewModelProvider).pageIndex;
    if (!pageController.hasClients) return;
    final duration = context.gu.duration(GuMotion.base);
    if (duration == Duration.zero) {
      // Hareket azaltılmış: geçiş animasyonsuz.
      pageController.jumpToPage(target);
      return;
    }
    unawaited(
      pageController.animateToPage(
        target,
        duration: duration,
        curve: GuMotion.easeStandard,
      ),
    );
  }

  /// `ONB-01.skip` / `ONB-01.start` — tanıtımı bitirir ve girişe geçer
  /// (`finish`, `:47`). Bitiş sürerken gelen dokunuş yok sayılır.
  ///
  /// Bayrak yazılınca router da `/onboarding`'den çıkarır (R3); buradaki `go`
  /// aynı hedefe gider, ekran o sırada sökülmüşse atlanır.
  Future<void> onFinish() async {
    if (ref.read(onboardingViewModelProvider).isFinishing) return;
    await ref.read(onboardingViewModelProvider.notifier).finish();
    if (!mounted) return;
    const LoginRoute().go(context);
  }
}
