// T-11 · SessionViewModel: oturum akışından durum çözümü (unknown →
// signedOut / unverified / active / suspended), claim, tanıtım bayrağı,
// oturum sona erdi, hesap değişimi ve yarış koruması (PLAN §12.2;
// architecture §6; CD-52).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/init/app_gate_view_model.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';

import '../../fakes/fake_app_preferences_store.dart';
import '../../fakes/fake_auth_service.dart';
import '../../fakes/register_fakes.dart';
import '../../helpers/test_container.dart';

const _email = 'mehmet@ogr.gumushane.edu.tr';
const _password = 'Parola123';

AuthUserInfo _user({String uid = 'u1', bool verified = true}) =>
    AuthUserInfo(uid: uid, email: _email, emailVerified: verified);

void main() {
  late FakeAuthService auth;
  late FakeAppPreferencesStore store;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    auth = GetIt.I<AuthService>() as FakeAuthService;
    store = GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  });

  /// Kapsayıcıyı kurar, oturum akışının ilk olayını işler ve durumu döndürür.
  Future<ProviderContainer> resolved() async {
    final container = createContainer()..read(sessionViewModelProvider);
    await pumpEventQueue();
    return container;
  }

  SessionState stateOf(ProviderContainer container) =>
      container.read(sessionViewModelProvider);

  SessionViewModel notifierOf(ProviderContainer container) =>
      container.read(sessionViewModelProvider.notifier);

  group('T-11 · SessionViewModel · ilk çözüm', () {
    test('ilk state eşzamanlıdır: unknown + depodaki tanıtım bayrağı', () {
      store.values[AppPreferenceKeys.onboardingSeen] = true;
      final container = createContainer();
      expect(
        container.read(sessionViewModelProvider),
        const SessionState(onboardingSeen: true),
      );
    });

    test('oturum yok → signedOut', () async {
      final container = await resolved();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.signedOut),
      );
      expect(auth.callsTo('idTokenClaims'), isEmpty);
    });

    test('e-posta doğrulanmamış → unverified (claim okunmaz)', () async {
      auth.currentUser = _user(verified: false);
      final container = await resolved();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.unverified, uid: 'u1'),
      );
      expect(auth.callsTo('idTokenClaims'), isEmpty);
    });

    test('doğrulanmış → active; claim sunucudan zorlanmadan okunur', () async {
      auth.currentUser = _user();
      final container = await resolved();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.active, uid: 'u1'),
      );
      expect(auth.callsTo('idTokenClaims').single.args, [false]);
    });

    test('`superadmin: true` claim → isSuperAdmin', () async {
      auth
        ..currentUser = _user()
        ..claims = {RoleCodes.superadmin: true};
      final container = await resolved();
      expect(stateOf(container).isSuperAdmin, isTrue);
      expect(stateOf(container).status, AuthStatus.active);
    });

    test('claim yalnızca `true` (bool) ise sayılır', () async {
      auth
        ..currentUser = _user()
        ..claims = {RoleCodes.superadmin: 'true'};
      final container = await resolved();
      expect(stateOf(container).isSuperAdmin, isFalse);
    });

    test('çözüm sürerken isResolving doğrudur, durum henüz değişmez', () async {
      auth.currentUser = _user();
      final container = createContainer();
      final seen = <SessionState>[];
      container.listen(
        sessionViewModelProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );
      await pumpEventQueue();
      expect(seen, const [
        SessionState(),
        SessionState(uid: 'u1', isResolving: true),
        SessionState(status: AuthStatus.active, uid: 'u1'),
      ]);
    });
  });

  group('T-11 · SessionViewModel · durum geçişleri', () {
    test('signedOut → unverified → active → signedOut', () async {
      final container = await resolved();
      expect(stateOf(container).status, AuthStatus.signedOut);

      await auth.register(email: _email, password: _password);
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.unverified);
      expect(stateOf(container).uid, auth.uid);

      // Kullanıcı bağlantıya tıkladı; "Doğruladım" → reload + resolve.
      auth.emailVerified = true;
      await auth.reload();
      await notifierOf(container).resolve();
      expect(stateOf(container).status, AuthStatus.active);
      expect(stateOf(container).uid, auth.uid);

      expect(await notifierOf(container).signOut(), isTrue);
      await pumpEventQueue();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.signedOut),
      );
      expect(auth.callsTo('signOut'), hasLength(1));
    });

    test('giriş (doğrulanmış) → active', () async {
      final container = await resolved();
      auth.emailVerified = true;
      await auth.signIn(email: _email, password: _password);
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.active);
    });

    test('oturum dışarıdan düşerse signedOut olur ve kullanıcı alanları '
        'temizlenir', () async {
      auth
        ..currentUser = _user()
        ..claims = {RoleCodes.superadmin: true};
      final container = await resolved();
      expect(stateOf(container).isSuperAdmin, isTrue);

      auth
        ..currentUser = null
        ..authStateController.add(null);
      await pumpEventQueue();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.signedOut),
      );
    });

    test('başka hesaba geçişte önceki hesabın claim’i taşınmaz', () async {
      auth
        ..currentUser = _user()
        ..claims = {RoleCodes.superadmin: true};
      final container = await resolved();
      expect(stateOf(container).isSuperAdmin, isTrue);

      final other = _user(uid: 'u2', verified: false);
      auth
        ..currentUser = other
        ..claims = {}
        ..authStateController.add(other);
      await pumpEventQueue();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.unverified, uid: 'u2'),
      );
    });

    test('yarış: eski çözümün sonucu yenisini ezmez', () async {
      final container = await resolved();
      final user = _user();
      auth
        ..currentUser = user
        ..claims = {RoleCodes.superadmin: true}
        // Giriş olayının çözümü claim beklerken oturum kapanır.
        ..authStateController.add(user)
        ..authStateController.add(null);
      await pumpEventQueue();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.signedOut),
      );
    });

    test('signOut başarısızsa `false` döner ve oturum açık kalır', () async {
      auth.currentUser = _user();
      final container = await resolved();
      auth.failNext(AuthError.network);
      expect(await notifierOf(container).signOut(), isFalse);
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.active);
      expect(stateOf(container).uid, 'u1');
    });

    test('yarış: claim beklenirken hesap devre dışı kalırsa geç gelen çözüm '
        'askıyı `active` ile ezmez', () async {
      final claimsGate = Completer<void>();
      auth
        ..currentUser = _user()
        ..claimsGate = claimsGate;
      final container = await resolved();
      expect(stateOf(container).isResolving, isTrue);

      auth.tokenErrorController.add(AuthError.userDisabled);
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.suspended);

      // Önbellekteki jetonla claim okuması başarıyla döner.
      claimsGate.complete();
      await pumpEventQueue();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.suspended, uid: 'u1'),
      );
      expect(auth.callsTo('idTokenClaims'), hasLength(1));
    });
  });

  group('T-11 · SessionViewModel · çözüm hataları', () {
    test('bilinmeyen hata → isError, durum değişmez; resolve() ile '
        'toparlanır', () async {
      auth
        ..currentUser = _user()
        ..failNext(AuthError.unknown);
      final container = await resolved();
      expect(
        stateOf(container),
        const SessionState(uid: 'u1', isError: true),
      );

      await notifierOf(container).resolve();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.active, uid: 'u1'),
      );
    });

    test(
      'ağ hatası kullanıcıyı kilitlemez: claim olmadan active (Q-12)',
      () async {
        auth
          ..currentUser = _user()
          ..claims = {RoleCodes.superadmin: true}
          ..failNext(AuthError.network);
        final container = await resolved();
        expect(
          stateOf(container),
          const SessionState(status: AuthStatus.active, uid: 'u1'),
        );
      },
    );

    test('claim okunurken oturum sona ermişse → sessionExpired + kök kapı '
        '(DLG-27)', () async {
      auth
        ..currentUser = _user()
        ..failNext(AuthError.sessionExpired);
      final container = await resolved();
      expect(stateOf(container).sessionExpired, isTrue);
      expect(stateOf(container).isResolving, isFalse);
      expect(stateOf(container).isError, isFalse);
      expect(
        container.read(appGateViewModelProvider).isSessionExpired,
        isTrue,
      );
    });

    test('claim okunurken hesap devre dışıysa → suspended', () async {
      auth
        ..currentUser = _user()
        ..failNext(AuthError.userDisabled);
      final container = await resolved();
      expect(stateOf(container).status, AuthStatus.suspended);
      expect(stateOf(container).isResolving, isFalse);
    });

    test('oturum akışı hata verirse isError', () async {
      final container = await resolved();
      auth.authStateController.addError(StateError('akış'));
      await pumpEventQueue();
      expect(stateOf(container).isError, isTrue);
      expect(stateOf(container).status, AuthStatus.signedOut);
    });
  });

  group('T-11 · SessionViewModel · jeton hataları', () {
    test(
      'sessionExpired → bayrak + kök kapı; ikinci olay tekrar etmez',
      () async {
        auth.currentUser = _user();
        final container = await resolved();
        var gateChanges = 0;
        container.listen(
          appGateViewModelProvider.select((gate) => gate.isSessionExpired),
          (_, _) => gateChanges++,
        );

        auth.tokenErrorController.add(AuthError.sessionExpired);
        await pumpEventQueue();
        expect(stateOf(container).sessionExpired, isTrue);
        expect(stateOf(container).status, AuthStatus.active);
        expect(
          container.read(appGateViewModelProvider).isSessionExpired,
          isTrue,
        );

        auth.tokenErrorController.add(AuthError.sessionExpired);
        await pumpEventQueue();
        expect(gateChanges, 1);
      },
    );

    test('userDisabled → suspended', () async {
      auth.currentUser = _user();
      final container = await resolved();
      auth.tokenErrorController.add(AuthError.userDisabled);
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.suspended);
      expect(stateOf(container).uid, 'u1');
    });

    test('oturumu geçersiz kılmayan hata durumu değiştirmez', () async {
      auth.currentUser = _user();
      final container = await resolved();
      final before = stateOf(container);
      auth.tokenErrorController.add(AuthError.network);
      await pumpEventQueue();
      expect(stateOf(container), before);
    });

    test('yeni oturum çözülünce sessionExpired temizlenir', () async {
      auth.currentUser = _user();
      final container = await resolved();
      notifierOf(container).onTokenExpired();
      expect(stateOf(container).sessionExpired, isTrue);

      // SDK oturumu düşürür: bayrak girişe kadar kalır.
      auth
        ..currentUser = null
        ..authStateController.add(null);
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.signedOut);
      expect(stateOf(container).sessionExpired, isTrue);

      auth.emailVerified = true;
      await auth.signIn(email: _email, password: _password);
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.active);
      expect(stateOf(container).sessionExpired, isFalse);
    });

    test('signOut bayrağı temizler', () async {
      auth.currentUser = _user();
      final container = await resolved();
      notifierOf(container).onTokenExpired();
      await notifierOf(container).signOut();
      await pumpEventQueue();
      expect(stateOf(container).sessionExpired, isFalse);
      expect(stateOf(container).status, AuthStatus.signedOut);
    });

    test('signOut başarısızsa bayrak ve kök kapı açık kalır (DLG-27 yeniden '
        'gösterilebilir)', () async {
      auth.currentUser = _user();
      final container = await resolved();
      notifierOf(container).onTokenExpired();
      auth.failNext(AuthError.network);
      expect(await notifierOf(container).signOut(), isFalse);
      await pumpEventQueue();
      expect(stateOf(container).sessionExpired, isTrue);
      expect(stateOf(container).status, AuthStatus.active);
      expect(
        container.read(appGateViewModelProvider).isSessionExpired,
        isTrue,
      );
    });
  });

  group('T-11 · SessionViewModel · claim yenileme', () {
    test('refreshClaims jetonu zorlayarak okur ve değeri günceller', () async {
      auth.currentUser = _user();
      final container = await resolved();
      expect(stateOf(container).isSuperAdmin, isFalse);

      auth.claims = {RoleCodes.superadmin: true};
      await notifierOf(container).refreshClaims();
      expect(stateOf(container).isSuperAdmin, isTrue);
      expect(auth.callsTo('idTokenClaims').last.args, [true]);

      auth.claims = {};
      await notifierOf(container).refreshClaims();
      expect(stateOf(container).isSuperAdmin, isFalse);
    });

    test('oturum yokken çağrı yapılmaz', () async {
      final container = await resolved();
      await notifierOf(container).refreshClaims();
      expect(auth.callsTo('idTokenClaims'), isEmpty);
    });

    test('okunamazsa mevcut değer korunur', () async {
      auth
        ..currentUser = _user()
        ..claims = {RoleCodes.superadmin: true};
      final container = await resolved();
      auth.failNext(AuthError.network);
      await notifierOf(container).refreshClaims();
      expect(stateOf(container).isSuperAdmin, isTrue);
      expect(stateOf(container).isError, isFalse);
    });
  });

  group('T-11 · SessionViewModel · tanıtım bayrağı (CD-52)', () {
    test('markOnboardingSeen depoya, oturuma ve tercihlere yazar', () async {
      final container = await resolved();
      expect(
        container.read(appPreferencesViewModelProvider).onboardingSeen,
        isFalse,
      );

      await notifierOf(container).markOnboardingSeen();
      expect(store.onboardingSeen, isTrue);
      expect(stateOf(container).onboardingSeen, isTrue);
      expect(
        container.read(appPreferencesViewModelProvider).onboardingSeen,
        isTrue,
      );
    });

    test('kalıcı yazılamasa da bayrak oturum boyunca geçerlidir', () async {
      final container = await resolved();
      store.failNext();
      await notifierOf(container).markOnboardingSeen();
      expect(store.callsTo('setOnboardingSeen').single.args, [true]);
      expect(stateOf(container).onboardingSeen, isTrue);
      expect(
        container.read(appPreferencesViewModelProvider).onboardingSeen,
        isTrue,
      );
    });

    test('bayrak her çözümün başında depodan okunur', () async {
      final container = await resolved();
      expect(stateOf(container).onboardingSeen, isFalse);
      store.values[AppPreferenceKeys.onboardingSeen] = true;
      await notifierOf(container).resolve();
      expect(stateOf(container).onboardingSeen, isTrue);
    });
  });

  group('T-11 · SessionViewModel · rol kısayolları ve ömür', () {
    test('roleIn / accessTo / isBlocked state’e delege eder', () async {
      auth
        ..currentUser = _user()
        ..claims = {RoleCodes.superadmin: true};
      final container = await resolved();
      final notifier = notifierOf(container);
      expect(notifier.roleIn('c01'), isNull);
      expect(notifier.accessTo('c01'), ClubAccess.superAdmin);
      expect(notifier.isBlocked('u9'), isFalse);
    });

    test('kapsayıcı kapanınca oturum ve jeton akışı bırakılır', () async {
      final container = ProviderContainer()..read(sessionViewModelProvider);
      await pumpEventQueue();
      expect(auth.authStateController.hasListener, isTrue);
      expect(auth.tokenErrorController.hasListener, isTrue);

      container.dispose();
      await pumpEventQueue();
      expect(auth.authStateController.hasListener, isFalse);
      expect(auth.tokenErrorController.hasListener, isFalse);
    });
  });
}
