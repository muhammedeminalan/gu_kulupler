import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/onboarding/provider/onboarding_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_view_model.g.dart';

/// Tanıtım ekranının ViewModel'i (ONB-01; PLAN §12.4).
///
/// Slayt sırasını tutar ve tanıtımı bitirir. Bitiş bayrağının tek sahibi
/// `SessionViewModel`'dir (`markOnboardingSeen`, CD-52): depoya yazar,
/// `SessionState.onboardingSeen`'i yükseltir; router `/onboarding`'den
/// `/login`'e yönlendirir (R2 → R3). Gezinme çağrısı view mixin'indedir.
@riverpod
final class OnboardingViewModel extends _$OnboardingViewModel {
  @override
  OnboardingState build() => const OnboardingState();

  /// Görünen slaytı [index] yapar (kaydırma ve "İleri"). Aralık dışı değer
  /// uca çekilir; aynı slayt yeniden yazılmaz.
  void setPage(int index) {
    final page = index.clamp(0, OnboardingState.pageCount - 1);
    if (page == state.pageIndex) return;
    state = state.copyWith(pageIndex: page);
  }

  /// Bir sonraki slayt; son slaytta etkisizdir.
  void next() => setPage(state.pageIndex + 1);

  /// Tanıtımı bitirir ("Atla" ve "Başla"): tanıtım bayrağını yazar. Sürerken
  /// gelen ikinci çağrı (çift dokunma) yok sayılır.
  ///
  /// Bayrak kalıcı yazılamasa da oturum boyunca geçerlidir
  /// (`markOnboardingSeen` fırlatmaz); kullanıcı tanıtımda kilitli kalmaz.
  Future<void> finish() async {
    if (state.isFinishing) return;
    state = state.copyWith(isFinishing: true);
    try {
      await ref.read(sessionViewModelProvider.notifier).markOnboardingSeen();
    } finally {
      // Yönlendirme ekranı söktüyse sağlayıcı da gitmiştir.
      if (ref.mounted) state = state.copyWith(isFinishing: false);
    }
  }
}
