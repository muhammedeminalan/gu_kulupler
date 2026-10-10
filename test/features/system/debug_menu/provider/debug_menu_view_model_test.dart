// T-11 · DebugMenuViewModel (K-E, CD-69): görünüm tercihleri
// AppPreferencesViewModel'den yansır ve ona (oradan depoya) yazılır.
// T-11 · DebugMenu · demo hesap girişi (CD-132 (23)): yalnızca emülatörde
// `authService.signIn(e-posta, demo parolası)`; hata → `isError`; çıkış.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/system/debug_menu/provider/debug_demo_accounts.dart';
import 'package:gu_kulupler/features/system/debug_menu/provider/debug_menu_state.dart';
import 'package:gu_kulupler/features/system/debug_menu/provider/debug_menu_view_model.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../fakes/fake_auth_service.dart';
import '../../../../fakes/fake_base.dart';
import '../../../../fakes/register_fakes.dart';
import '../../../../helpers/test_container.dart';

FakeAuthService _auth() => GetIt.I<AuthService>() as FakeAuthService;

/// Kapsayıcıyı kurar; DebugMenu ve oturum sağlayıcılarını test boyunca canlı
/// tutar.
ProviderContainer _container() {
  final container = createContainer();
  addTearDown(container.listen(debugMenuViewModelProvider, (_, _) {}).close);
  addTearDown(container.listen(sessionViewModelProvider, (_, _) {}).close);
  return container;
}

void main() {
  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
  });

  group('T-11 · DebugMenuViewModel', () {
    test('ilk state tercihleri yansıtır', () {
      final container = createContainer();
      addTearDown(
        container.listen(debugMenuViewModelProvider, (_, _) {}).close,
      );
      expect(
        container.read(debugMenuViewModelProvider),
        const DebugMenuState(),
      );
    });

    test('setThemeMode / setLocale / setTextScale tercihlere yazar; state '
        'yeniden yansır', () async {
      final container = createContainer();
      addTearDown(
        container.listen(debugMenuViewModelProvider, (_, _) {}).close,
      );
      final viewModel = container.read(debugMenuViewModelProvider.notifier);

      await viewModel.setThemeMode(ThemeMode.dark);
      await viewModel.setLocale(const Locale('en'));
      await viewModel.setTextScale(GuTextScaleLevel.s160);
      expect(
        container.read(debugMenuViewModelProvider),
        const DebugMenuState(
          themeMode: ThemeMode.dark,
          locale: Locale('en'),
          textScale: GuTextScaleLevel.s160,
        ),
      );
      final preferences = container.read(appPreferencesViewModelProvider);
      expect(preferences.themeMode, ThemeMode.dark);
      expect(preferences.locale, const Locale('en'));
      expect(preferences.textScale, GuTextScaleLevel.s160);
      final store = GetIt.I<AppPreferencesStore>();
      expect(store.themeMode, ThemeMode.dark);
      expect(store.locale, const Locale('en'));
      expect(store.textScale, GuTextScaleLevel.s160);

      await container.read(debugMenuViewModelProvider.notifier).setLocale(null);
      expect(container.read(debugMenuViewModelProvider).locale, isNull);
    });
  });

  group('T-11 · DebugMenu · demo hesap girişi', () {
    final account = DebugDemoAccounts.all[2];

    test(
      'emülatör değilken giriş denenmez (demo parolası gönderilmez)',
      () async {
        final container = _container();
        final viewModel = container.read(debugMenuViewModelProvider.notifier);

        expect(await viewModel.signInDemo(account), isFalse);
        expect(_auth().callsTo('signIn'), isEmpty);
        expect(
          container.read(debugMenuViewModelProvider),
          const DebugMenuState(),
        );
      },
    );

    test('başarı: e-posta + demo parolasıyla signIn; oturum çözülür', () async {
      final container = _container();
      _auth()
        ..emailVerified = true
        ..uid = account.id;
      final viewModel = container.read(debugMenuViewModelProvider.notifier);

      final signedIn = viewModel.signInDemo(account, isEmulator: true);
      expect(
        container.read(debugMenuViewModelProvider).signingInId,
        account.id,
      );
      expect(await signedIn, isTrue);
      await pumpEventQueue();

      expect(_auth().callsTo('signIn'), [
        FakeCall('signIn', [account.email, DebugDemoAccounts.password]),
      ]);
      expect(
        container.read(debugMenuViewModelProvider),
        const DebugMenuState(),
      );
      final session = container.read(sessionViewModelProvider);
      expect(session.status, AuthStatus.active);
      expect(session.uid, account.id);
    });

    test('hata: isError + errorCode yazılır, oturum açılmaz; yeni deneme '
        'hatayı temizler', () async {
      final container = _container();
      _auth()
        ..emailVerified = true
        ..failNext(AuthError.network);
      final viewModel = container.read(debugMenuViewModelProvider.notifier);

      expect(await viewModel.signInDemo(account, isEmulator: true), isFalse);
      await pumpEventQueue();
      expect(
        container.read(debugMenuViewModelProvider),
        DebugMenuState(isError: true, errorCode: AuthError.network.name),
      );
      expect(container.read(sessionViewModelProvider).uid, isNull);

      expect(await viewModel.signInDemo(account, isEmulator: true), isTrue);
      expect(
        container.read(debugMenuViewModelProvider),
        const DebugMenuState(),
      );
    });

    test('art arda tetik: süren giriş varken ikincisi başlatılmaz', () async {
      final container = _container();
      _auth().emailVerified = true;
      final viewModel = container.read(debugMenuViewModelProvider.notifier);

      final first = viewModel.signInDemo(account, isEmulator: true);
      final second = viewModel.signInDemo(
        DebugDemoAccounts.all.first,
        isEmulator: true,
      );
      expect(await second, isFalse);
      expect(await first, isTrue);
      expect(_auth().callsTo('signIn'), hasLength(1));
    });

    test('tercih değişince giriş alanları korunur', () async {
      final container = _container();
      _auth().failNext(AuthError.invalidCredentials);
      final viewModel = container.read(debugMenuViewModelProvider.notifier);
      await viewModel.signInDemo(account, isEmulator: true);

      await container
          .read(debugMenuViewModelProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      expect(
        container.read(debugMenuViewModelProvider),
        DebugMenuState(
          themeMode: ThemeMode.dark,
          isError: true,
          errorCode: AuthError.invalidCredentials.name,
        ),
      );
    });

    test('signOut: oturum kapanır; kapatılamazsa false', () async {
      final container = _container();
      _auth().emailVerified = true;
      final viewModel = container.read(debugMenuViewModelProvider.notifier);
      await viewModel.signInDemo(account, isEmulator: true);
      await pumpEventQueue();
      expect(
        container.read(sessionViewModelProvider).status,
        AuthStatus.active,
      );

      _auth().failNext(AuthError.network);
      expect(await viewModel.signOut(), isFalse);
      expect(container.read(sessionViewModelProvider).uid, isNotNull);

      expect(await viewModel.signOut(), isTrue);
      await pumpEventQueue();
      expect(_auth().callsTo('signOut'), hasLength(2));
      final session = container.read(sessionViewModelProvider);
      expect(session.status, AuthStatus.signedOut);
      expect(session.uid, isNull);
    });
  });
}
