// ONB-01 · OnboardingState: varsayılanlar, `isLastPage`, `props` ve
// `copyWith` tüm alanlar (PLAN §12.4).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/features/onboarding/provider/onboarding_state.dart';

void main() {
  group('ONB-01 · OnboardingState', () {
    test('varsayılan: ilk slayt, bitiş başlamadı; üç slayt', () {
      const state = OnboardingState();
      expect(state.pageIndex, 0);
      expect(state.isFinishing, isFalse);
      expect(state.isLastPage, isFalse);
      expect(OnboardingState.pageCount, 3);
    });

    test('isLastPage yalnızca son slaytta', () {
      expect(const OnboardingState(pageIndex: 1).isLastPage, isFalse);
      expect(const OnboardingState(pageIndex: 2).isLastPage, isTrue);
    });

    test('props tüm alanları içerir: her alan eşitliği tek başına bozar', () {
      const base = OnboardingState();
      expect(base, const OnboardingState());
      expect(base.props, [0, false]);
      expect(base, isNot(const OnboardingState(pageIndex: 1)));
      expect(base, isNot(const OnboardingState(isFinishing: true)));
    });

    test('copyWith her alanı değiştirir; verilmeyen alan korunur', () {
      const base = OnboardingState(pageIndex: 1, isFinishing: true);
      expect(base.copyWith(), base);
      expect(
        base.copyWith(pageIndex: 2),
        const OnboardingState(pageIndex: 2, isFinishing: true),
      );
      expect(
        base.copyWith(isFinishing: false),
        const OnboardingState(pageIndex: 1),
      );
    });
  });
}
