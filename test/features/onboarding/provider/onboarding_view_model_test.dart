// ONB-01 · OnboardingViewModel: slayt sırası (kaydırma / "İleri"), tanıtımın
// bitişi (`SessionViewModel.markOnboardingSeen`, CD-52), çift dokunma, kalıcı
// yazma hatası (PLAN §12.4).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/onboarding/provider/onboarding_state.dart';
import 'package:gu_kulupler/features/onboarding/provider/onboarding_view_model.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../onboarding_test_support.dart';

void main() {
  late FakeAppPreferencesStore store;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    store = GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;
  });

  /// Sağlayıcıyı canlı tutan kapsayıcı + state günlüğü.
  (ProviderContainer, List<OnboardingState>) containerWithLog() {
    final container = createContainer();
    final log = <OnboardingState>[];
    addTearDown(
      container
          .listen(onboardingViewModelProvider, (_, next) => log.add(next))
          .close,
    );
    return (container, log);
  }

  OnboardingViewModel notifierOf(ProviderContainer container) =>
      container.read(onboardingViewModelProvider.notifier);

  OnboardingState stateOf(ProviderContainer container) =>
      container.read(onboardingViewModelProvider);

  group('ONB-01 · OnboardingViewModel · slayt', () {
    test('ilk state: ilk slayt, bitiş başlamadı', () {
      final (container, _) = containerWithLog();
      expect(stateOf(container), const OnboardingState());
    });

    test('setPage slaytı değiştirir; aynı slayt yeniden yazılmaz', () {
      final (container, log) = containerWithLog();
      notifierOf(container).setPage(2);
      expect(stateOf(container), const OnboardingState(pageIndex: 2));
      notifierOf(container).setPage(2);
      notifierOf(container).setPage(1);
      expect(log, const [
        OnboardingState(pageIndex: 2),
        OnboardingState(pageIndex: 1),
      ]);
    });

    test('setPage aralık dışı değeri uca çeker', () {
      final (container, _) = containerWithLog();
      notifierOf(container).setPage(9);
      expect(stateOf(container).pageIndex, OnboardingState.pageCount - 1);
      notifierOf(container).setPage(-3);
      expect(stateOf(container).pageIndex, 0);
    });

    test('next sırayla ilerler; son slaytta etkisizdir', () {
      final (container, log) = containerWithLog();
      notifierOf(container).next();
      expect(stateOf(container).pageIndex, 1);
      notifierOf(container).next();
      expect(stateOf(container).pageIndex, 2);
      expect(stateOf(container).isLastPage, isTrue);
      notifierOf(container).next();
      expect(stateOf(container).pageIndex, 2);
      expect(log, hasLength(2));
    });
  });

  group('ONB-01 · OnboardingViewModel · bitiş', () {
    test('finish tanıtım bayrağını depoya, oturuma ve tercihlere yazar; '
        'bitiş bayrağı açılıp kapanır, slayt korunur', () async {
      final (container, log) = containerWithLog();
      container
        ..read(sessionViewModelProvider)
        ..read(appPreferencesViewModelProvider);
      notifierOf(container).setPage(1);
      expect(container.read(sessionViewModelProvider).onboardingSeen, isFalse);

      await notifierOf(container).finish();

      expect(store.onboardingSeen, isTrue);
      expect(store.callsTo('setOnboardingSeen'), hasLength(1));
      expect(store.callsTo('setOnboardingSeen').single.args, [true]);
      expect(container.read(sessionViewModelProvider).onboardingSeen, isTrue);
      expect(
        container.read(appPreferencesViewModelProvider).onboardingSeen,
        isTrue,
      );
      expect(log, const [
        OnboardingState(pageIndex: 1),
        OnboardingState(pageIndex: 1, isFinishing: true),
        OnboardingState(pageIndex: 1),
      ]);
    });

    test('finish sürerken ikinci çağrı (çift dokunma) yok sayılır', () async {
      final controlled = await ControlledPreferencesStore.install();
      controlled.gate = Completer<void>();
      final (container, _) = containerWithLog();

      final first = notifierOf(container).finish();
      expect(stateOf(container).isFinishing, isTrue);
      final second = notifierOf(container).finish();
      await second;
      // İkinci çağrı beklemeden döndü; yazım hâlâ tek ve sürüyor.
      expect(controlled.onboardingWrites, 1);
      expect(stateOf(container).isFinishing, isTrue);
      expect(container.read(sessionViewModelProvider).onboardingSeen, isFalse);

      controlled.gate!.complete();
      await first;
      expect(controlled.onboardingWrites, 1);
      expect(stateOf(container).isFinishing, isFalse);
      expect(container.read(sessionViewModelProvider).onboardingSeen, isTrue);
    });

    test('bitiş tamamlandıktan sonra finish yeniden çağrılabilir', () async {
      final (container, _) = containerWithLog();
      await notifierOf(container).finish();
      await notifierOf(container).finish();
      expect(store.callsTo('setOnboardingSeen'), hasLength(2));
      expect(stateOf(container).isFinishing, isFalse);
    });

    test('kalıcı yazım başarısız (false): bayrak oturum boyunca yine '
        'geçerli, kullanıcı tanıtımda kilitlenmez', () async {
      store.failNext();
      final (container, _) = containerWithLog();
      await notifierOf(container).finish();
      expect(container.read(sessionViewModelProvider).onboardingSeen, isTrue);
      expect(stateOf(container).isFinishing, isFalse);
    });

    test('yazım fırlatırsa hata yutulmaz; bitiş bayrağı geri iner', () async {
      (await ControlledPreferencesStore.install()).error = StateError('disk');
      final (container, _) = containerWithLog();
      await expectLater(notifierOf(container).finish(), throwsStateError);
      expect(stateOf(container).isFinishing, isFalse);
      expect(container.read(sessionViewModelProvider).onboardingSeen, isFalse);
      // Sonraki deneme kilitli değildir.
      expect(stateOf(container), const OnboardingState());
    });

    test('bitiş sürerken sağlayıcı sökülürse state’e yazılmaz', () async {
      final controlled = await ControlledPreferencesStore.install();
      controlled.gate = Completer<void>();
      final container = createContainer();
      final subscription = container.listen(
        onboardingViewModelProvider,
        (_, _) {},
      );
      // Oturum sağlayıcısı (keepAlive) yaşamaya devam eder.
      container.read(sessionViewModelProvider);

      final pending = notifierOf(container).finish();
      subscription.close();
      await container.pump();
      controlled.gate!.complete();
      await pending;

      expect(container.read(sessionViewModelProvider).onboardingSeen, isTrue);
      expect(stateOf(container), const OnboardingState());
    });
  });
}
