// T-42 · Push jetonu yaşam döngüsü (Mod F — docs/plans/T-42.md §4 d,
// CD-165): SessionViewModel + SessionPushSync. Etkin oturumda jeton yazılır
// (platform, dil, istemci saati), aynı jeton yeniden yazılmaz, yenilenen
// jeton ve dil değişimi yazılır; izin yoksa yazılmaz (öne gelince yakalanır);
// çıkışta jeton signOut'tan ÖNCE çıkarılır ve geçersiz kılınır; silinmiş
// hesapta yalnızca yerel jeton geçersizleşir; dokunma yükleri yalnızca etkin
// oturumda iletilir.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';

import '../../fakes/fake_app_preferences_store.dart';
import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_messaging_service.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fakes/register_fakes.dart';
import '../../helpers/test_container.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeUserRepository users;
  late FakeMessagingService messaging;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    auth = GetIt.I<AuthRepository>() as FakeAuthRepository;
    users = GetIt.I<UserRepository>() as FakeUserRepository;
    messaging = GetIt.I<MessagingService>() as FakeMessagingService;
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  });

  /// Doğrulanmış, profili tamam `u1` oturumuyla çözülmüş kapsayıcı.
  Future<ProviderContainer> resolvedActive() async {
    users.putActive('u1');
    auth.currentUser = const AuthUserInfo(
      uid: 'u1',
      email: 'mehmet@ogr.gumushane.edu.tr',
      emailVerified: true,
    );
    final container = createContainer()..read(sessionViewModelProvider);
    await pumpEventQueue();
    return container;
  }

  SessionViewModel notifierOf(ProviderContainer container) =>
      container.read(sessionViewModelProvider.notifier);

  List<FcmTokenModel> tokensOf(String uid) => users.accounts[uid]!.fcmTokens;

  group('T-42 · push jetonu', () {
    test('etkin oturum → jeton yazılır (android, uygulama dili, istemci '
        'saati); öne gelince aynı jeton yeniden yazılmaz; yenilenen jeton ve '
        'dil değişimi yazılır; ön plan sunumu bir kez kurulur', () async {
      (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
              .values[AppPreferenceKeys.locale] =
          'tr';
      final container = await resolvedActive();

      expect(tokensOf('u1'), [
        FcmTokenModel(
          token: FakeMessagingService.defaultToken,
          platform: 'android',
          updatedAt: kDefaultFakeNowUtc,
        ),
      ]);
      expect(messaging.foregroundConfigured, isTrue);
      // Jetonun sahibi cihazda saklanır; aynı hesapta geçersiz kılma yok.
      expect(
        GetIt.I<AppPreferencesStore>().pushTokenUid,
        'u1',
      );
      expect(messaging.callsTo('invalidateToken'), isEmpty);

      await notifierOf(container).onAppResumed();
      await pumpEventQueue();
      expect(users.callsTo('upsertFcmToken'), hasLength(1));

      messaging.refreshToken('fcm-yeni');
      await pumpEventQueue();
      expect(tokensOf('u1').map((t) => t.token), [
        FakeMessagingService.defaultToken,
        'fcm-yeni',
      ]);

      await container
          .read(appPreferencesViewModelProvider.notifier)
          .setLocale(const Locale('en'));
      await pumpEventQueue();
      expect(tokensOf('u1').last.token, 'fcm-yeni');
      expect(tokensOf('u1').last.locale, 'en');
      expect(messaging.callsTo('configureForeground'), hasLength(1));
    });

    test('izin yoksa jeton istenmez ve yazılmaz; izin verilip uygulama öne '
        'gelince yazılır', () async {
      messaging.authorized = false;
      final container = await resolvedActive();

      expect(messaging.callsTo('token'), isEmpty);
      expect(tokensOf('u1'), isEmpty);

      messaging.authorized = true;
      await notifierOf(container).onAppResumed();
      await pumpEventQueue();
      expect(tokensOf('u1').single.token, FakeMessagingService.defaultToken);
    });

    test('çıkış: jeton signOut’tan ÖNCE hesaptan çıkarılır ve geçersiz '
        'kılınır; sonraki yenileme yazılmaz', () async {
      final container = await resolvedActive();
      final gate = Completer<void>();
      messaging.invalidateGate = gate;

      final signedOut = notifierOf(container).signOut();
      await pumpEventQueue();
      // Hesaptan çıkarıldı, geçersiz kılma bekliyor; oturum henüz açık.
      expect(tokensOf('u1'), isEmpty);
      expect(auth.callsTo('signOut'), isEmpty);

      gate.complete();
      expect(await signedOut, isTrue);
      await pumpEventQueue();
      expect(auth.callsTo('signOut'), hasLength(1));
      expect(messaging.callsTo('invalidateToken'), hasLength(1));
      expect(messaging.hasRefreshListener, isFalse);
      expect(
        container.read(sessionViewModelProvider).status,
        AuthStatus.signedOut,
      );
      expect(users.callsTo('upsertFcmToken'), hasLength(1));
    });

    test('silinmiş hesap: hesap belgesine yazılmaz (jetonlar markDeleted ile '
        '[]), yalnızca yerel jeton geçersiz kılınır', () async {
      users.putActive('u1');
      users.users['u1'] = users.users['u1']!.copyWith(
        status: UserStatus.deleted,
        isDeleted: true,
      );
      auth.currentUser = const AuthUserInfo(
        uid: 'u1',
        email: 'mehmet@ogr.gumushane.edu.tr',
        emailVerified: true,
      );
      createContainer().read(sessionViewModelProvider);
      await pumpEventQueue();

      expect(auth.callsTo('signOut'), hasLength(1));
      expect(users.callsTo('upsertFcmToken'), isEmpty);
      expect(users.callsTo('removeFcmToken'), isEmpty);
      expect(messaging.callsTo('invalidateToken'), hasLength(1));
    });

    test('güvenlik incelemesi: jeton önceki hesaba yazılmışsa (çevrimdışı '
        'çıkış) yeni hesaba yazılmadan önce geçersiz kılınır', () async {
      final store = GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;
      store.values[AppPreferenceKeys.pushTokenUid] = 'u0';

      await resolvedActive();

      expect(messaging.callsTo('invalidateToken'), hasLength(1));
      expect(tokensOf('u1').single.token, messaging.nextToken);
      expect(
        tokensOf('u1').single.token,
        isNot(FakeMessagingService.defaultToken),
      );
      expect(store.pushTokenUid, 'u1');
    });

    test('güvenlik incelemesi: oturum dışarıdan kapanınca bu oturumda '
        'yazılan yerel jeton geçersiz kılınır', () async {
      await resolvedActive();
      expect(tokensOf('u1'), hasLength(1));

      auth
        ..currentUser = null
        ..watchAuthStateController.add(null);
      await pumpEventQueue();

      expect(messaging.callsTo('invalidateToken'), hasLength(1));
      expect(messaging.hasRefreshListener, isFalse);
      // Oturum yok: hesaba yazılamaz (sunucu eski jetonu ilk gönderimde siler).
      expect(users.callsTo('removeFcmToken'), isEmpty);
    });

    test('dokunma: soğuk açılış yükü bir kez; arka plan dokunuşları yalnızca '
        'etkin oturumda iletilir', () async {
      messaging.launchData = {'notificationId': 'n1'};
      final container = await resolvedActive();
      final taps = <Map<String, String>>[];
      notifierOf(container).pushTaps.listen(taps.add);

      expect(await notifierOf(container).takeLaunchPush(), {
        'notificationId': 'n1',
      });
      expect(await notifierOf(container).takeLaunchPush(), isNull);
      messaging.tap({'notificationId': 'n2'});
      await notifierOf(container).signOut();
      await pumpEventQueue();
      messaging.tap({'notificationId': 'n3'});

      expect(taps, [
        {'notificationId': 'n2'},
      ]);
    });
  });
}
