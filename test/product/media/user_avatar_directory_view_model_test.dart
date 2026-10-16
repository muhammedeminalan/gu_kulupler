// Tasarım hataları turu · madde 5 · UserAvatarDirectoryViewModel: kimliği
// bilinen ama belgesi elde olmayan avatar yerlerinin fotoğraf yolu dizini.
// Aynı turda istenen kimlikler tek `getUsers` çağrısında okunur (N+1 yok);
// çözülen kimlik `CachePolicy.userTtl` süresince yeniden okunmaz; hata baş
// harflerde kalır ve bekleme süresinden sonra yeniden denenir.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/media/constants/media_constants.dart';
import 'package:gu_kulupler/product/media/user_avatar_directory_state.dart';
import 'package:gu_kulupler/product/media/user_avatar_directory_view_model.dart';

import '../../fakes/fake_user_repository.dart';
import '../../fakes/register_fakes.dart';
import '../../fixtures/user_model_fixtures.dart';
import '../../helpers/fake_app_clock.dart';
import '../../helpers/test_container.dart';

const String _aysePath = 'users/u_ayse/20261013T090000Z_0001020304050607.jpg';

void main() {
  late FakeUserRepository users;
  late FakeAppClock clock;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    users = GetIt.I<UserRepository>() as FakeUserRepository;
    clock = GetIt.I<AppClock>() as FakeAppClock;
    users.users
      ..['u_ayse'] = UserModelFixtures.ayse.copyWith(avatarPath: _aysePath)
      ..['u_mehmet'] = UserModelFixtures.byId('u_mehmet')
      ..['u_deleted'] =
          UserModelFixtures.byId(
            'u_elif',
          ).copyWith(
            uid: 'u_deleted',
            avatarPath: 'users/u_deleted/x.jpg',
            isDeleted: true,
          );
  });

  List<List<String>> batches() => [
    for (final call in users.callsTo('getUsers'))
      List<String>.of(call.args.single! as List<String>),
  ];

  group('UserAvatarDirectoryViewModel', () {
    test(
      'aynı turda istenen kimlikler tek getUsers çağrısında çözülür',
      () async {
        final container = createContainer();
        container.read(userAvatarDirectoryViewModelProvider.notifier)
          ..request(['u_ayse'])
          ..request(['u_mehmet', 'u_yok'])
          ..request(['u_ayse']);
        // İstek eşzamanlıdır ve state'i değiştirmez (build içinde güvenli).
        expect(
          container.read(userAvatarDirectoryViewModelProvider),
          const UserAvatarDirectoryState(),
        );
        await pumpEventQueue();

        expect(batches(), [
          ['u_ayse', 'u_mehmet', 'u_yok'],
        ]);
        final state = container.read(userAvatarDirectoryViewModelProvider);
        expect(state.avatarPathOf('u_ayse'), _aysePath);
        // Fotoğrafsız kimlik çözülür (baş harfler); sonuçta dönmeyen kimlik
        // çözülmüş sayılmaz (kısa bekleme sonra yeniden istenir).
        expect(state.isResolved('u_mehmet'), isTrue);
        expect(state.avatarPathOf('u_mehmet'), isNull);
        expect(state.isResolved('u_yok'), isFalse);
        expect(state.isFetching, isFalse);
        expect(state.isError, isFalse);
      },
    );

    test('silinmiş / anonim kullanıcının fotoğrafı çözülmez', () async {
      final container = createContainer();
      container.read(userAvatarDirectoryViewModelProvider.notifier).request([
        'u_deleted',
      ]);
      await pumpEventQueue();

      final state = container.read(userAvatarDirectoryViewModelProvider);
      expect(state.isResolved('u_deleted'), isTrue);
      expect(state.avatarPathOf('u_deleted'), isNull);
    });

    test('çözülen kimlik süre dolmadan yeniden okunmaz; süre dolunca '
        'yenilenir, eski yol yenisi gelene dek kalır', () async {
      final container = createContainer();
      final directory = container.read(
        userAvatarDirectoryViewModelProvider.notifier,
      )..request(['u_ayse']);
      await pumpEventQueue();
      directory.request(['u_ayse']);
      await pumpEventQueue();
      expect(batches(), hasLength(1));

      const newPath = 'users/u_ayse/20261014T090000Z_0001020304050607.jpg';
      users.users['u_ayse'] = UserModelFixtures.ayse.copyWith(
        avatarPath: newPath,
      );
      clock.advance(CachePolicy.userTtl);
      directory.request(['u_ayse']);
      expect(
        container
            .read(userAvatarDirectoryViewModelProvider)
            .avatarPathOf('u_ayse'),
        _aysePath,
      );
      await pumpEventQueue();

      expect(batches(), hasLength(2));
      expect(
        container
            .read(userAvatarDirectoryViewModelProvider)
            .avatarPathOf('u_ayse'),
        newPath,
      );
    });

    test('okuma hatası: isError, kimlik çözülmez ve bekleme süresi dolmadan '
        'yeniden istenmez', () async {
      final container = createContainer();
      users.failNext(FirestoreError.unavailable);
      final directory = container.read(
        userAvatarDirectoryViewModelProvider.notifier,
      )..request(['u_ayse']);
      await pumpEventQueue();

      var state = container.read(userAvatarDirectoryViewModelProvider);
      expect(state.isError, isTrue);
      expect(state.isFetching, isFalse);
      expect(state.isResolved('u_ayse'), isFalse);

      directory.request(['u_ayse']);
      await pumpEventQueue();
      expect(batches(), hasLength(1));

      clock.advance(MediaConstants.imageUrlRetryAfter);
      directory.request(['u_ayse']);
      await pumpEventQueue();
      expect(batches(), hasLength(2));
      state = container.read(userAvatarDirectoryViewModelProvider);
      expect(state.isError, isFalse);
      expect(state.avatarPathOf('u_ayse'), _aysePath);
    });

    test('sonuçta dönmeyen kimlik (çevrimdışı eksik sonuç): önceki yol kalır, '
        'userTtl değil imageUrlRetryAfter sonra yeniden istenir', () async {
      final container = createContainer();
      final directory = container.read(
        userAvatarDirectoryViewModelProvider.notifier,
      )..request(['u_ayse']);
      await pumpEventQueue();
      expect(
        container
            .read(userAvatarDirectoryViewModelProvider)
            .avatarPathOf('u_ayse'),
        _aysePath,
      );

      // Süre doldu; yenileme okuması çevrimdışı önbellekten boş döner.
      clock.advance(CachePolicy.userTtl);
      final ayse = users.users.remove('u_ayse')!;
      directory.request(['u_ayse', 'u_mehmet']);
      await pumpEventQueue();
      expect(batches(), hasLength(2));
      var state = container.read(userAvatarDirectoryViewModelProvider);
      expect(state.avatarPathOf('u_ayse'), _aysePath, reason: 'eski yol kalır');
      expect(state.isError, isFalse);

      // Bekleme süresinde yeniden istenmez…
      directory.request(['u_ayse']);
      await pumpEventQueue();
      expect(batches(), hasLength(2));

      // …bağlantı döndü: 30 sn sonra (10 dk değil) yeniden okunur.
      users.users['u_ayse'] = ayse.copyWith(avatarPath: 'users/u_ayse/b.jpg');
      clock.advance(MediaConstants.imageUrlRetryAfter);
      expect(MediaConstants.imageUrlRetryAfter, lessThan(CachePolicy.userTtl));
      directory.request(['u_ayse']);
      await pumpEventQueue();
      expect(batches().last, ['u_ayse']);
      state = container.read(userAvatarDirectoryViewModelProvider);
      expect(state.avatarPathOf('u_ayse'), 'users/u_ayse/b.jpg');
    });

    test('oturum kullanıcısı değişince dizin boşalır, süren okumanın sonucu '
        'atılır', () async {
      final container = createContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => const SessionState(uid: 'u_me'),
          ),
        ],
      );
      addTearDown(
        container.listen(userAvatarDirectoryViewModelProvider, (_, _) {}).close,
      );
      container.read(userAvatarDirectoryViewModelProvider.notifier).request([
        'u_ayse',
      ]);
      await pumpEventQueue();
      expect(
        container
            .read(userAvatarDirectoryViewModelProvider)
            .avatarPathOf('u_ayse'),
        _aysePath,
      );

      // Okuma sürerken hesap değişir.
      final gate = users.getUsersGate = Completer<void>();
      container.read(userAvatarDirectoryViewModelProvider.notifier).request([
        'u_mehmet',
      ]);
      await pumpEventQueue();
      container.read(sessionViewModelProvider.notifier).state =
          const SessionState(uid: 'u_other');
      await pumpEventQueue();
      expect(
        container.read(userAvatarDirectoryViewModelProvider),
        const UserAvatarDirectoryState(),
      );
      gate.complete();
      await pumpEventQueue();
      expect(
        container.read(userAvatarDirectoryViewModelProvider),
        const UserAvatarDirectoryState(),
        reason: 'eski hesabın okuması yazılmaz',
      );

      // Yeni oturumda süre dolmadan da yeniden okunur.
      users.getUsersGate = null;
      container.read(userAvatarDirectoryViewModelProvider.notifier).request([
        'u_ayse',
      ]);
      await pumpEventQueue();
      expect(batches().last, ['u_ayse']);
      expect(
        container
            .read(userAvatarDirectoryViewModelProvider)
            .avatarPathOf('u_ayse'),
        _aysePath,
      );
    });

    test('geçersiz kimlik okunmaz (toplu okumayı bozmaz)', () async {
      final container = createContainer();
      container.read(userAvatarDirectoryViewModelProvider.notifier).request([
        '',
        'a/b',
        'u_ayse',
      ]);
      await pumpEventQueue();

      expect(batches(), [
        ['u_ayse'],
      ]);
    });

    test('boş istek okuma yapmaz', () async {
      final container = createContainer();
      container
          .read(userAvatarDirectoryViewModelProvider.notifier)
          .request(const []);
      await pumpEventQueue();

      expect(users.callsTo('getUsers'), isEmpty);
    });
  });

  group('UserAvatarDirectoryState', () {
    test('varsayılan boş; copyWith yalnızca verilen alanları değiştirir', () {
      const initial = UserAvatarDirectoryState();
      expect(initial.avatarPaths, isEmpty);
      expect(initial.isFetching, isFalse);
      expect(initial.isError, isFalse);

      final next = initial.copyWith(
        avatarPaths: {'u1': 'users/u1/a.jpg', 'u2': null},
        isFetching: true,
        isError: true,
      );
      expect(next.avatarPathOf('u1'), 'users/u1/a.jpg');
      expect(next.isResolved('u2'), isTrue);
      expect(next.avatarPathOf('u2'), isNull);
      expect(next.isResolved('u3'), isFalse);
      expect(next.isFetching, isTrue);
      expect(next.isError, isTrue);
      expect(next.copyWith(), next);
      expect(next.copyWith(isFetching: false).avatarPaths, next.avatarPaths);
    });

    test('props tüm alanları içerir (eşitlik)', () {
      const base = UserAvatarDirectoryState();
      expect(base, const UserAvatarDirectoryState());
      expect(base.copyWith(avatarPaths: {'u1': null}), isNot(base));
      expect(base.copyWith(isFetching: true), isNot(base));
      expect(base.copyWith(isError: true), isNot(base));
      expect(base.props, hasLength(3));
    });
  });
}
