// T-11 / T-12 · SessionViewModel: oturum akışından ve `users/{uid}`
// belgesinden durum çözümü (unknown → signedOut / unverified /
// profileIncomplete / active / suspended; silinmiş hesap → signedOut), claim,
// kullanıcı belgesi yenileme, tanıtım bayrağı, oturum sona erdi, hesap
// değişimi ve yarış koruması (PLAN §12.2; architecture §6; CD-52, CD-133).
// T-15: üyelik akışı (canlı; rol / erişim çözümü, güncelleme, dinleyici
// ömrü, yarış) ve engellenenler (PLAN §10.6 #1, §12.2).
// T-25: yerel hatırlatıcı köprüsü — etkinleşmede / dil değişiminde yeniden
// planlama, çıkışta iptal, soğuk açılış yükü (PLAN §15.6; CD-72).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_gate_view_model.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';

import '../../fakes/fake_account_deletion_repository.dart';
import '../../fakes/fake_app_preferences_store.dart';
import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_block_repository.dart';
import '../../fakes/fake_crash_service.dart';
import '../../fakes/fake_event_repository.dart';
import '../../fakes/fake_feedback_service.dart';
import '../../fakes/fake_local_reminder_service.dart';
import '../../fakes/fake_membership_repository.dart';
import '../../fakes/fake_notification_repository.dart';
import '../../fakes/fake_rsvp_repository.dart';
import '../../fakes/fake_url_launcher_service.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fakes/register_fakes.dart';
import '../../helpers/fake_app_clock.dart';
import '../../helpers/test_container.dart';

const _email = 'mehmet@ogr.gumushane.edu.tr';
const _password = 'Parola123';
const _reason = 'Topluluk kurallarının ihlali.';

AuthUserInfo _user({String uid = 'u1', bool verified = true}) =>
    AuthUserInfo(uid: uid, email: _email, emailVerified: verified);

void main() {
  late FakeAuthRepository auth;
  late FakeUserRepository users;
  late FakeAppPreferencesStore store;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    auth = GetIt.I<AuthRepository>() as FakeAuthRepository;
    users = GetIt.I<UserRepository>() as FakeUserRepository;
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

  /// Doğrulanmış, profili tamam `u1` oturumuyla çözülmüş kapsayıcı.
  Future<ProviderContainer> resolvedActive() {
    users.putActive('u1');
    auth.currentUser = _user();
    return resolved();
  }

  SessionState stateOf(ProviderContainer container) =>
      container.read(sessionViewModelProvider);

  SessionViewModel notifierOf(ProviderContainer container) =>
      container.read(sessionViewModelProvider.notifier);

  group('T-12 · SessionViewModel · ilk çözüm', () {
    test('ilk state eşzamanlıdır: unknown + depodaki tanıtım bayrağı', () {
      store.values[AppPreferenceKeys.onboardingSeen] = true;
      final container = createContainer();
      expect(
        container.read(sessionViewModelProvider),
        const SessionState(onboardingSeen: true),
      );
    });

    test(
      'oturum yok → signedOut (claim ve kullanıcı belgesi okunmaz)',
      () async {
        final container = await resolved();
        expect(
          stateOf(container),
          const SessionState(status: AuthStatus.signedOut),
        );
        expect(auth.callsTo('isSuperAdmin'), isEmpty);
        expect(users.calls, isEmpty);
      },
    );

    test('e-posta doğrulanmamış → unverified (claim ve kullanıcı belgesi '
        'okunmaz)', () async {
      users.putActive('u1');
      auth.currentUser = _user(verified: false);
      final container = await resolved();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.unverified, uid: 'u1'),
      );
      expect(auth.callsTo('isSuperAdmin'), isEmpty);
      expect(users.calls, isEmpty);
    });

    test('doğrulanmış + profili tamam → active ve kullanıcı belgesi; ilk '
        'çözümde jeton sunucudan yenilenir (D-28)', () async {
      final profile = users.putActive('u1');
      auth.currentUser = _user();
      final container = await resolved();
      expect(
        stateOf(container),
        SessionState(status: AuthStatus.active, uid: 'u1', user: profile),
      );
      expect(auth.callsTo('isSuperAdmin').single.args, [true]);
      expect(users.callsTo('getUser').single.args, ['u1']);
    });

    test('süper admin claim’i → isSuperAdmin', () async {
      auth.isSuperAdminResult = true;
      final container = await resolvedActive();
      expect(stateOf(container).isSuperAdmin, isTrue);
      expect(stateOf(container).status, AuthStatus.active);
    });

    test('çözüm sürerken isResolving doğrudur; durum belge okunana kadar '
        'değişmez (doğrulanmış oturum `active` görünüp geri dönmez)', () async {
      final profile = users.putActive('u1');
      auth.currentUser = _user();
      final container = createContainer();
      final seen = <SessionState>[];
      container.listen(
        sessionViewModelProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );
      await pumpEventQueue();
      expect(seen, [
        const SessionState(),
        const SessionState(uid: 'u1', isResolving: true),
        SessionState(status: AuthStatus.active, uid: 'u1', user: profile),
      ]);
    });
  });

  group('T-12 · SessionViewModel · kullanıcı belgesi', () {
    test('belge yok → profileIncomplete (profil akışı oluşturur)', () async {
      auth.currentUser = _user();
      final container = await resolved();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.profileIncomplete, uid: 'u1'),
      );
    });

    test('profileComplete değil → profileIncomplete + belge', () async {
      await users.createProfile(
        uid: 'u1',
        email: _email,
        name: 'Mehmet Kaya',
        nameLower: 'mehmet kaya',
        avatarSeed: 'u1',
      );
      auth.currentUser = _user();
      final container = await resolved();
      expect(stateOf(container).status, AuthStatus.profileIncomplete);
      expect(stateOf(container).user, users.users['u1']);
      expect(stateOf(container).user!.profileComplete, isFalse);
    });

    test('status suspended → suspended + gerekçe (private/account, CD-133); '
        'ardından oturum kapatılır (W-03) ve durum signedOut olur', () async {
      final profile = users
          .putActive('u1')
          .copyWith(
            status: UserStatus.suspended,
          );
      users.users['u1'] = profile;
      users.accounts['u1'] = users.accounts['u1']!.copyWith(
        suspendReason: _reason,
      );
      auth.currentUser = _user();
      final states = <SessionState>[];
      final container = createContainer()
        ..listen(sessionViewModelProvider, (_, next) => states.add(next));
      await pumpEventQueue();
      // Gerekçe oturum kapanmadan önce okunur (belge yalnızca sahibine açık).
      expect(
        states,
        contains(
          SessionState(
            status: AuthStatus.suspended,
            uid: 'u1',
            user: profile,
            suspendReason: _reason,
          ),
        ),
      );
      expect(users.callsTo('getPrivateAccount').single.args, ['u1']);
      expect(auth.callsTo('signOut'), hasLength(1));
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.signedOut),
      );
      expect(auth.currentUser, isNull);
    });

    test('askıdaki oturum kapatılamazsa durum suspended kalır (R6 kullanıcıyı '
        'girişte tutar)', () async {
      final profile = users
          .putActive('u1')
          .copyWith(
            status: UserStatus.suspended,
          );
      users.users['u1'] = profile;
      users.accounts['u1'] = users.accounts['u1']!.copyWith(
        suspendReason: _reason,
      );
      final gate = Completer<void>();
      users.getUserGate = gate;
      auth.currentUser = _user();
      final container = await resolved();
      // Claim okundu; sıradaki kimlik çağrısı `signOut`.
      auth.failNext(AuthError.network);
      gate.complete();
      await pumpEventQueue();
      expect(auth.callsTo('signOut'), hasLength(1));
      expect(
        stateOf(container),
        SessionState(
          status: AuthStatus.suspended,
          uid: 'u1',
          user: profile,
          suspendReason: _reason,
        ),
      );
    });

    test('gerekçe okunamazsa askı gerekçesiz uygulanır', () async {
      users.users['u1'] = users
          .putActive('u1')
          .copyWith(
            status: UserStatus.suspended,
          );
      // `getUser` hatayı tüketmez (kapıda bekler); `getPrivateAccount` alır.
      final gate = Completer<void>();
      users.getUserGate = gate;
      auth.currentUser = _user();
      final states = <SessionState>[];
      final container = createContainer()
        ..listen(sessionViewModelProvider, (_, next) => states.add(next));
      await pumpEventQueue();
      users.failNext(FirestoreError.permissionDenied);
      gate.complete();
      await pumpEventQueue();
      expect(users.callsTo('getPrivateAccount'), hasLength(1));
      final suspended = states.singleWhere(
        (state) => state.status == AuthStatus.suspended,
      );
      expect(suspended.suspendReason, isNull);
      expect(suspended.isError, isFalse);
      expect(auth.callsTo('signOut'), hasLength(1));
      expect(stateOf(container).status, AuthStatus.signedOut);
    });

    test('yeniden etkinleştirilen hesapta gerekçe temizlenir', () async {
      final profile = users.putActive('u1');
      users.users['u1'] = profile.copyWith(status: UserStatus.suspended);
      users.accounts['u1'] = users.accounts['u1']!.copyWith(
        suspendReason: _reason,
      );
      // Oturum kapatılamadı: askıdaki oturum cihazda kaldı.
      final gate = Completer<void>();
      users.getUserGate = gate;
      auth.currentUser = _user();
      final container = await resolved();
      auth.failNext(AuthError.network);
      gate.complete();
      users.getUserGate = null;
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.suspended);
      expect(stateOf(container).suspendReason, _reason);

      users.users['u1'] = profile;
      await notifierOf(container).resolve();
      expect(
        stateOf(container),
        SessionState(status: AuthStatus.active, uid: 'u1', user: profile),
      );
    });

    for (final (title, status, isDeleted) in [
      ('status deleted', UserStatus.deleted, false),
      ('isDeleted', UserStatus.active, true),
    ]) {
      test(
        'silinmiş kullanıcı ($title) → oturum kapatılır, signedOut',
        () async {
          users.users['u1'] = users
              .putActive('u1')
              .copyWith(status: status, isDeleted: isDeleted);
          auth
            ..isSuperAdminResult = true
            ..currentUser = _user();
          final container = await resolved();
          expect(auth.callsTo('signOut'), hasLength(1));
          expect(auth.currentUser, isNull);
          expect(
            stateOf(container),
            const SessionState(status: AuthStatus.signedOut),
          );
        },
      );
    }

    test('T-29 · silinmiş hesapla giriş: yarıda kalmış temizlik sürdürülür '
        '(resumeCleanup), sonra oturum kapanır + TST-22', () async {
      final memberships =
          GetIt.I<MembershipRepository>() as FakeMembershipRepository;
      final deletion =
          GetIt.I<AccountDeletionRepository>() as FakeAccountDeletionRepository;
      final feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
      users.putActive('u1');
      memberships.clubRepository.put('c01', memberCount: 1);
      memberships.put(
        const MembershipModel(
          clubId: 'c01',
          userId: 'u1',
          applicant: MembershipApplicantModel(name: 'Ayşe', avatarSeed: 's'),
          status: MembershipStatus.active,
        ),
      );
      await deletion.markDeleted('u1');
      auth.currentUser = _user();

      final container = await resolved();
      await pumpEventQueue();

      expect(deletion.callsTo('resumeCleanup').single.args, ['u1']);
      expect(
        memberships.memberships['c01_u1']!.status,
        MembershipStatus.left,
      );
      expect(auth.callsTo('signOut'), hasLength(1));
      expect(feedback.toasts, [ToastId.tst22]);
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.signedOut),
      );
    });

    test(
      'T-29 · temizlik hatası oturum kapatmayı engellemez (en iyi çaba)',
      () async {
        final deletion =
            GetIt.I<AccountDeletionRepository>()
                as FakeAccountDeletionRepository;
        users.putActive('u1');
        await deletion.markDeleted('u1');
        deletion.failNext(FirestoreError.unavailable);
        auth.currentUser = _user();

        final container = await resolved();
        await pumpEventQueue();

        expect(auth.callsTo('signOut'), hasLength(1));
        expect(stateOf(container).status, AuthStatus.signedOut);
      },
    );

    test('silinmiş kullanıcının oturumu kapatılamazsa hesap uygulamada '
        'kalmaz: unknown + isError (açık oturum yenilenirken de)', () async {
      auth.isSuperAdminResult = true;
      final container = await resolvedActive();
      users.users['u1'] = users.users['u1']!.copyWith(
        status: UserStatus.deleted,
        isDeleted: true,
      );
      auth.failNext(AuthError.network);

      await notifierOf(container).refreshUser();
      expect(auth.callsTo('signOut'), hasLength(1));
      expect(
        stateOf(container),
        const SessionState(uid: 'u1', isError: true),
      );
    });

    test('belge okunamazsa isError, durum değişmez; resolve() ile '
        'toparlanır', () async {
      final profile = users.putActive('u1');
      users.failNext(FirestoreError.unavailable);
      auth.currentUser = _user();
      final container = await resolved();
      expect(
        stateOf(container),
        const SessionState(uid: 'u1', isError: true),
      );

      await notifierOf(container).resolve();
      expect(
        stateOf(container),
        SessionState(status: AuthStatus.active, uid: 'u1', user: profile),
      );
    });

    test('belge okunurken oturum düşmüşse (unauthenticated) → '
        'sessionExpired + kök kapı (DLG-27)', () async {
      users
        ..putActive('u1')
        ..failNext(FirestoreError.unauthenticated);
      auth.currentUser = _user();
      final container = await resolved();
      expect(stateOf(container).sessionExpired, isTrue);
      expect(stateOf(container).isResolving, isFalse);
      expect(stateOf(container).isError, isFalse);
      expect(
        container.read(appGateViewModelProvider).isSessionExpired,
        isTrue,
      );
    });
  });

  group('T-12 · SessionViewModel · durum geçişleri', () {
    test('signedOut → unverified → profileIncomplete → active → '
        'signedOut', () async {
      final container = await resolved();
      expect(stateOf(container).status, AuthStatus.signedOut);

      // AUT-02: kayıt → doğrulanmamış oturum.
      await auth.register(
        email: _email,
        password: _password,
        name: 'Ayşe Yılmaz',
      );
      await pumpEventQueue();
      final uid = auth.service.uid;
      expect(stateOf(container).status, AuthStatus.unverified);
      expect(stateOf(container).uid, uid);

      // AUT-03 "Doğruladım": reload + refreshUser; profil belgesi henüz yok.
      auth.service.emailVerified = true;
      await auth.reloadUser();
      await notifierOf(container).refreshUser();
      expect(stateOf(container).status, AuthStatus.profileIncomplete);
      expect(stateOf(container).user, isNull);

      // AUT-05: profil oluşturulur ve tamamlanır.
      await users.createProfile(
        uid: uid,
        email: _email,
        name: 'Mehmet Kaya',
        nameLower: 'mehmet kaya',
        avatarSeed: uid,
      );
      await users.updateProfile(
        uid,
        const UserProfilePatch(interests: ['i01'], profileComplete: true),
      );
      await notifierOf(container).refreshUser();
      expect(stateOf(container).status, AuthStatus.active);
      expect(stateOf(container).user, users.users[uid]);

      expect(await notifierOf(container).signOut(), isTrue);
      await pumpEventQueue();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.signedOut),
      );
      expect(auth.callsTo('signOut'), hasLength(1));
    });

    test('giriş (doğrulanmış, profili tamam) → active', () async {
      final container = await resolved();
      users.putActive(auth.service.uid);
      auth.service.emailVerified = true;
      await auth.signIn(email: _email, password: _password);
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.active);
    });

    test('oturum dışarıdan düşerse signedOut olur ve kullanıcı alanları '
        'temizlenir', () async {
      auth.isSuperAdminResult = true;
      final container = await resolvedActive();
      expect(stateOf(container).isSuperAdmin, isTrue);
      expect(stateOf(container).user, isNotNull);

      auth
        ..currentUser = null
        ..watchAuthStateController.add(null);
      await pumpEventQueue();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.signedOut),
      );
    });

    test('başka hesaba geçişte önceki hesabın claim’i ve belgesi '
        'taşınmaz', () async {
      auth.isSuperAdminResult = true;
      final container = await resolvedActive();
      expect(stateOf(container).isSuperAdmin, isTrue);

      final other = _user(uid: 'u2', verified: false);
      auth
        ..currentUser = other
        ..isSuperAdminResult = false
        ..watchAuthStateController.add(other);
      await pumpEventQueue();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.unverified, uid: 'u2'),
      );
    });

    test('yarış: art arda oturum olayında eski çözümün sonucu yenisini '
        'ezmez', () async {
      final container = await resolved();
      users.putActive('u1');
      final user = _user();
      auth
        ..currentUser = user
        ..isSuperAdminResult = true
        // Giriş olayının çözümü claim beklerken oturum kapanır.
        ..watchAuthStateController.add(user)
        ..watchAuthStateController.add(null);
      await pumpEventQueue();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.signedOut),
      );
    });

    test('yarış: kullanıcı belgesi beklenirken oturum kapanırsa geç gelen '
        'belge oturumu `active` yapmaz', () async {
      final gate = Completer<void>();
      users
        ..putActive('u1')
        ..getUserGate = gate;
      auth.currentUser = _user();
      final container = await resolved();
      expect(stateOf(container).isResolving, isTrue);

      auth
        ..currentUser = null
        ..watchAuthStateController.add(null);
      await pumpEventQueue();
      gate.complete();
      await pumpEventQueue();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.signedOut),
      );
    });

    test('signOut başarısızsa `false` döner ve oturum açık kalır', () async {
      final container = await resolvedActive();
      auth.failNext(AuthError.network);
      expect(await notifierOf(container).signOut(), isFalse);
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.active);
      expect(stateOf(container).uid, 'u1');
    });

    test('yarış: claim beklenirken hesap devre dışı kalırsa geç gelen çözüm '
        'askıyı `active` ile ezmez', () async {
      final claimsGate = Completer<void>();
      users.putActive('u1');
      auth
        ..currentUser = _user()
        ..superAdminGate = claimsGate;
      final container = await resolved();
      expect(stateOf(container).isResolving, isTrue);

      // Oturum kapatılamasın: askı durumu yerinde kalsın ve eski çözümün onu
      // ezip ezmediği görülsün.
      auth
        ..failNext(AuthError.network)
        ..tokenErrorController.add(AuthError.userDisabled);
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.suspended);
      expect(auth.callsTo('signOut'), hasLength(1));

      // Önbellekteki jetonla claim okuması başarıyla döner.
      claimsGate.complete();
      await pumpEventQueue();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.suspended, uid: 'u1'),
      );
      expect(auth.callsTo('isSuperAdmin'), hasLength(1));
      expect(users.callsTo('getUser'), isEmpty);
    });

    test('yarış: claim beklenirken hesap devre dışı kalır ve oturum kapanırsa '
        'geç gelen çözüm signedOut durumunu ezmez', () async {
      final claimsGate = Completer<void>();
      users.putActive('u1');
      auth
        ..currentUser = _user()
        ..superAdminGate = claimsGate;
      final container = await resolved();

      auth.tokenErrorController.add(AuthError.userDisabled);
      await pumpEventQueue();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.signedOut),
      );

      claimsGate.complete();
      await pumpEventQueue();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.signedOut),
      );
      expect(users.callsTo('getUser'), isEmpty);
    });
  });

  group('T-12 · SessionViewModel · claim okuma hataları', () {
    test('bilinmeyen hata → isError, durum değişmez; resolve() ile '
        'toparlanır', () async {
      final profile = users.putActive('u1');
      auth
        ..currentUser = _user()
        ..failNext(AuthError.unknown);
      final container = await resolved();
      expect(
        stateOf(container),
        const SessionState(uid: 'u1', isError: true),
      );
      expect(users.callsTo('getUser'), isEmpty);

      await notifierOf(container).resolve();
      expect(
        stateOf(container),
        SessionState(status: AuthStatus.active, uid: 'u1', user: profile),
      );
    });

    test('jeton yenilenemezse (ağ) önbellekteki jetondan okunur; sonraki '
        'çözüm yenilemeyi yeniden dener', () async {
      auth
        ..isSuperAdminResult = true
        ..failNext(AuthError.network);
      final container = await resolvedActive();
      expect(stateOf(container).status, AuthStatus.active);
      expect(stateOf(container).isSuperAdmin, isTrue);
      expect(auth.callsTo('isSuperAdmin').map((call) => call.args), [
        [true],
        [false],
      ]);

      await notifierOf(container).resolve();
      expect(auth.callsTo('isSuperAdmin').last.args, [true]);
    });

    test('ağ hiç yoksa kullanıcı kilitlenmez: claim olmadan çözülür '
        '(Q-12)', () async {
      auth
        ..isSuperAdminResult = true
        // İlki repository, ikincisi servis düzeyinde: iki okuma da düşer.
        ..failNext(AuthError.network)
        ..service.failNext(AuthError.network);
      final container = await resolvedActive();
      expect(stateOf(container).status, AuthStatus.active);
      expect(stateOf(container).isSuperAdmin, isFalse);
      expect(stateOf(container).isError, isFalse);
    });

    test('girişte bir kez: aynı oturumun sonraki çözümü jetonu '
        'yenilemez', () async {
      final container = await resolvedActive();
      await notifierOf(container).resolve();
      expect(auth.callsTo('isSuperAdmin').map((call) => call.args), [
        [true],
        [false],
      ]);
    });

    test('claim okunurken oturum sona ermişse → sessionExpired + kök kapı '
        '(DLG-27)', () async {
      users.putActive('u1');
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

    test('claim okunurken hesap devre dışıysa → suspended, sonra oturum '
        'kapatılır', () async {
      users.putActive('u1');
      auth
        ..currentUser = _user()
        ..failNext(AuthError.userDisabled);
      final states = <SessionState>[];
      final container = createContainer()
        ..listen(sessionViewModelProvider, (_, next) => states.add(next));
      await pumpEventQueue();
      final suspended = states.singleWhere(
        (state) => state.status == AuthStatus.suspended,
      );
      expect(suspended.isResolving, isFalse);
      expect(users.callsTo('getUser'), isEmpty);
      expect(auth.callsTo('signOut'), hasLength(1));
      expect(stateOf(container).status, AuthStatus.signedOut);
    });

    test('oturum akışı hata verirse isError', () async {
      final container = await resolved();
      auth.watchAuthStateController.addError(StateError('akış'));
      await pumpEventQueue();
      expect(stateOf(container).isError, isTrue);
      expect(stateOf(container).status, AuthStatus.signedOut);
    });
  });

  group('T-12 · SessionViewModel · refreshUser', () {
    test('belgeyi yeniden okur; claim yeniden okunmaz', () async {
      final container = await resolvedActive();
      await users.updateProfile('u1', const UserProfilePatch(bio: 'Merhaba.'));

      await notifierOf(container).refreshUser();
      expect(stateOf(container).user!.bio, 'Merhaba.');
      expect(stateOf(container).status, AuthStatus.active);
      expect(auth.callsTo('isSuperAdmin'), hasLength(1));
      expect(users.callsTo('getUser'), hasLength(2));
    });

    test('okunamazsa çözülmüş oturum korunur (isError yazılmaz)', () async {
      final container = await resolvedActive();
      final before = stateOf(container);
      users.failNext(FirestoreError.unavailable);
      await notifierOf(container).refreshUser();
      expect(stateOf(container), before);
    });

    test('yenilemede hesap askıya alınmışsa → suspended, sonra oturum '
        'kapatılır', () async {
      final container = await resolvedActive();
      users.users['u1'] = users.users['u1']!.copyWith(
        status: UserStatus.suspended,
      );
      final statuses = <AuthStatus>[];
      container.listen(
        sessionViewModelProvider.select((state) => state.status),
        (_, next) => statuses.add(next),
      );
      await notifierOf(container).refreshUser();
      await pumpEventQueue();
      expect(statuses, [AuthStatus.suspended, AuthStatus.signedOut]);
      expect(auth.callsTo('signOut'), hasLength(1));
    });

    test('oturum yokken belge okunmaz', () async {
      final container = await resolved();
      await notifierOf(container).refreshUser();
      expect(users.calls, isEmpty);
      expect(stateOf(container).status, AuthStatus.signedOut);
    });

    test('"oturum sona erdi" bayrağını indirmez (yalnızca yeni çözülen '
        'oturum indirir)', () async {
      final container = await resolvedActive();
      notifierOf(container).onTokenExpired();
      await notifierOf(container).refreshUser();
      expect(stateOf(container).sessionExpired, isTrue);
    });
  });

  group('T-11 · SessionViewModel · jeton hataları', () {
    test(
      'sessionExpired → bayrak + kök kapı; ikinci olay tekrar etmez',
      () async {
        final container = await resolvedActive();
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

    test('userDisabled → suspended, sonra oturum kapatılır', () async {
      final container = await resolvedActive();
      final statuses = <AuthStatus>[];
      container.listen(
        sessionViewModelProvider.select((state) => state.status),
        (_, next) => statuses.add(next),
      );
      auth.tokenErrorController.add(AuthError.userDisabled);
      await pumpEventQueue();
      expect(statuses, [AuthStatus.suspended, AuthStatus.signedOut]);
      expect(auth.callsTo('signOut'), hasLength(1));
      expect(stateOf(container).uid, isNull);
    });

    test('oturumu geçersiz kılmayan hata durumu değiştirmez', () async {
      final container = await resolvedActive();
      final before = stateOf(container);
      auth.tokenErrorController.add(AuthError.network);
      await pumpEventQueue();
      expect(stateOf(container), before);
    });

    test('yeni oturum çözülünce sessionExpired temizlenir', () async {
      final container = await resolvedActive();
      notifierOf(container).onTokenExpired();
      expect(stateOf(container).sessionExpired, isTrue);

      // SDK oturumu düşürür: bayrak girişe kadar kalır.
      auth
        ..currentUser = null
        ..watchAuthStateController.add(null);
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.signedOut);
      expect(stateOf(container).sessionExpired, isTrue);

      users.putActive(auth.service.uid);
      auth.service.emailVerified = true;
      await auth.signIn(email: _email, password: _password);
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.active);
      expect(stateOf(container).sessionExpired, isFalse);
    });

    test('signOut bayrağı temizler', () async {
      final container = await resolvedActive();
      notifierOf(container).onTokenExpired();
      await notifierOf(container).signOut();
      await pumpEventQueue();
      expect(stateOf(container).sessionExpired, isFalse);
      expect(stateOf(container).status, AuthStatus.signedOut);
    });

    test('signOut başarısızsa bayrak ve kök kapı açık kalır (DLG-27 yeniden '
        'gösterilebilir)', () async {
      final container = await resolvedActive();
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
      final container = await resolvedActive();
      expect(stateOf(container).isSuperAdmin, isFalse);

      auth.isSuperAdminResult = true;
      await notifierOf(container).refreshClaims();
      expect(stateOf(container).isSuperAdmin, isTrue);
      expect(auth.callsTo('isSuperAdmin').last.args, [true]);

      auth.isSuperAdminResult = false;
      await notifierOf(container).refreshClaims();
      expect(stateOf(container).isSuperAdmin, isFalse);
    });

    test('oturum yokken çağrı yapılmaz', () async {
      final container = await resolved();
      await notifierOf(container).refreshClaims();
      expect(auth.callsTo('isSuperAdmin'), isEmpty);
    });

    test('okunamazsa mevcut değer korunur', () async {
      auth.isSuperAdminResult = true;
      final container = await resolvedActive();
      auth.failNext(AuthError.network);
      await notifierOf(container).refreshClaims();
      expect(stateOf(container).isSuperAdmin, isTrue);
      expect(stateOf(container).isError, isFalse);
    });
  });

  group('T-37 · SessionViewModel · öne gelince claim / hesap tazeleme', () {
    test(
      'ilk çözümden 10 dk geçmeden yenilemez; sonra claim zorlanarak '
      'okunur ve kullanıcı belgesi yeniden okunur (askı yakalanır)',
      () async {
        final clock = GetIt.I<AppClock>() as FakeAppClock;
        final container = await resolvedActive();
        final claimReads = auth.callsTo('isSuperAdmin').length;

        clock.advance(const Duration(minutes: 9));
        await notifierOf(container).onAppResumed();
        expect(auth.callsTo('isSuperAdmin'), hasLength(claimReads));

        clock.advance(const Duration(minutes: 1));
        auth.isSuperAdminResult = true;
        users.users['u1'] = users.users['u1']!.copyWith(
          status: UserStatus.suspended,
        );
        final states = <SessionState>[];
        container.listen(
          sessionViewModelProvider,
          (_, next) => states.add(next),
        );
        await notifierOf(container).onAppResumed();
        await pumpEventQueue();

        expect(auth.callsTo('isSuperAdmin').last.args, [true]);
        expect(states.first.isSuperAdmin, isTrue);
        // Askı yakalanır (DLG-01); askıdaki oturum ardından kapatılır.
        expect(
          states.map((state) => state.status),
          contains(AuthStatus.suspended),
        );
      },
    );

    test('etkin olmayan oturumda çağrı yapılmaz', () async {
      final container = await resolved();
      (GetIt.I<AppClock>() as FakeAppClock).advance(const Duration(hours: 1));

      await notifierOf(container).onAppResumed();

      expect(auth.callsTo('isSuperAdmin'), isEmpty);
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
      auth.isSuperAdminResult = true;
      final container = await resolvedActive();
      final notifier = notifierOf(container);
      expect(notifier.roleIn('c01'), isNull);
      expect(notifier.accessTo('c01'), ClubAccess.superAdmin);
      expect(notifier.isBlocked('u9'), isFalse);
    });

    test('kapsayıcı kapanınca oturum ve jeton akışı bırakılır', () async {
      final container = ProviderContainer()..read(sessionViewModelProvider);
      await pumpEventQueue();
      expect(auth.watchAuthStateController.hasListener, isTrue);
      expect(auth.tokenErrorController.hasListener, isTrue);

      container.dispose();
      await pumpEventQueue();
      expect(auth.watchAuthStateController.hasListener, isFalse);
      expect(auth.tokenErrorController.hasListener, isFalse);
    });
  });

  group('T-15 · SessionViewModel · üyelik akışı ve roller', () {
    late FakeMembershipRepository memberships;

    setUp(() {
      memberships = GetIt.I<MembershipRepository>() as FakeMembershipRepository;
    });

    MembershipModel membership(
      String clubId, {
      String uid = 'u1',
      MembershipStatus status = MembershipStatus.active,
      ClubRole role = ClubRole.member,
    }) => MembershipModel(
      clubId: clubId,
      userId: uid,
      applicant: const MembershipApplicantModel(
        name: 'Mehmet',
        avatarSeed: 's',
      ),
      status: status,
      role: role,
    );

    test('aktif oturumda üyelikler canlı dinlenir ve kulüp kimliğiyle '
        'eşlenir; üye / yönetici / başvuran rolleri çözülür', () async {
      memberships
        ..put(membership('c_member'))
        ..put(membership('c_board', role: ClubRole.board))
        ..put(membership('c_president', role: ClubRole.president))
        ..put(membership('c_advisor', role: ClubRole.advisor))
        ..put(membership('c_pending', status: MembershipStatus.pending))
        ..put(membership('c_rejected', status: MembershipStatus.rejected))
        ..put(membership('c_left', status: MembershipStatus.left))
        // Başka kullanıcının üyeliği akışa girmez.
        ..put(membership('c_other', uid: 'u2', role: ClubRole.president));
      final container = await resolvedActive();
      final notifier = notifierOf(container);

      expect(memberships.callsTo('watchMyMemberships').single.args, ['u1']);
      expect(memberships.activeListeners, 1);
      expect(stateOf(container).memberships.keys, {
        'c_member',
        'c_board',
        'c_president',
        'c_advisor',
        'c_pending',
        'c_rejected',
        'c_left',
      });
      expect(
        {
          for (final clubId in [
            ...stateOf(container).memberships.keys,
            'c_other',
          ])
            clubId: (notifier.roleIn(clubId), notifier.accessTo(clubId)),
        },
        {
          'c_member': (ClubRole.member, ClubAccess.member),
          'c_board': (ClubRole.board, ClubAccess.manager),
          'c_president': (ClubRole.president, ClubAccess.manager),
          'c_advisor': (ClubRole.advisor, ClubAccess.advisor),
          // Yalnızca `active` üyelik rol taşır.
          'c_pending': (null, ClubAccess.pending),
          'c_rejected': (null, ClubAccess.rejected),
          'c_left': (null, ClubAccess.visitor),
          'c_other': (null, ClubAccess.visitor),
        },
      );
    });

    test('akış güncellemesi: başvuru onaylanınca rol kendiliğinden gelir; '
        'ayrılınca düşer', () async {
      memberships.put(membership('c01', status: MembershipStatus.pending));
      final container = await resolvedActive();
      expect(notifierOf(container).accessTo('c01'), ClubAccess.pending);

      memberships.put(membership('c01', role: ClubRole.board));
      await pumpEventQueue();
      expect(notifierOf(container).roleIn('c01'), ClubRole.board);
      expect(notifierOf(container).accessTo('c01'), ClubAccess.manager);

      memberships.put(membership('c01', status: MembershipStatus.left));
      await pumpEventQueue();
      expect(notifierOf(container).roleIn('c01'), isNull);
      expect(notifierOf(container).accessTo('c01'), ClubAccess.visitor);
    });

    test('süper admin üyelikten bağımsız superAdmin erişimi alır', () async {
      auth.isSuperAdminResult = true;
      memberships.put(membership('c01'));
      final container = await resolvedActive();
      expect(notifierOf(container).roleIn('c01'), ClubRole.member);
      expect(notifierOf(container).accessTo('c01'), ClubAccess.superAdmin);
    });

    test('doğrulanmamış ve profili eksik oturumda dinleyici açılmaz; profil '
        'tamamlanınca (refreshUser) açılır', () async {
      memberships.put(membership('c01'));
      auth.currentUser = _user(verified: false);
      final container = await resolved();
      expect(memberships.activeListeners, 0);

      auth.currentUser = _user();
      await notifierOf(container).resolve();
      expect(stateOf(container).status, AuthStatus.profileIncomplete);
      expect(memberships.activeListeners, 0);
      expect(stateOf(container).memberships, isEmpty);

      users.putActive('u1');
      await notifierOf(container).refreshUser();
      await pumpEventQueue();
      expect(memberships.activeListeners, 1);
      expect(notifierOf(container).roleIn('c01'), ClubRole.member);
    });

    test('oturum kapanınca dinleyici bırakılır, üyelikler temizlenir; '
        'kapanan oturumun geç gelen olayı yazılmaz', () async {
      memberships.put(membership('c01'));
      final container = await resolvedActive();
      expect(stateOf(container).memberships, isNotEmpty);

      auth
        ..currentUser = null
        ..watchAuthStateController.add(null);
      await pumpEventQueue();
      expect(memberships.activeListeners, 0);
      expect(stateOf(container).memberships, isEmpty);

      memberships.put(membership('c01', role: ClubRole.president));
      await pumpEventQueue();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.signedOut),
      );
    });

    test('başka hesaba geçiş: eski dinleyici kapanır, yeni hesabın '
        'üyelikleri dinlenir; eski hesabın olayı karışmaz', () async {
      memberships
        ..put(membership('c01', role: ClubRole.president))
        ..put(membership('c02', uid: 'u2'));
      final container = await resolvedActive();
      expect(notifierOf(container).roleIn('c01'), ClubRole.president);

      users.putActive('u2');
      final other = _user(uid: 'u2');
      auth
        ..currentUser = other
        ..watchAuthStateController.add(other);
      await pumpEventQueue();
      expect(memberships.activeListeners, 1);
      expect(stateOf(container).uid, 'u2');
      expect(stateOf(container).memberships.keys, {'c02'});

      // Eski hesabın akışına düşen olay yeni oturuma yazılmaz.
      memberships.put(membership('c03', role: ClubRole.board));
      await pumpEventQueue();
      expect(stateOf(container).memberships.keys, {'c02'});
      expect(notifierOf(container).roleIn('c01'), isNull);
    });

    test('yarış: yeni hesap çözülürken (belge bekleniyor) eski hesabın '
        'üyelikleri görünmez ve olayı yazılmaz', () async {
      memberships.put(membership('c01', role: ClubRole.president));
      final container = await resolvedActive();
      final gate = Completer<void>();
      users
        ..putActive('u2')
        ..getUserGate = gate;

      final other = _user(uid: 'u2');
      auth
        ..currentUser = other
        ..watchAuthStateController.add(other);
      await pumpEventQueue();
      expect(stateOf(container).isResolving, isTrue);
      expect(stateOf(container).memberships, isEmpty);
      expect(memberships.activeListeners, 0);

      memberships.put(membership('c09', role: ClubRole.board));
      await pumpEventQueue();
      expect(stateOf(container).memberships, isEmpty);

      gate.complete();
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.active);
      expect(stateOf(container).memberships, isEmpty);
      expect(memberships.callsTo('watchMyMemberships').last.args, ['u2']);
    });

    test('akış hatası rolleri düşürmez; kopan dinleyiciyi refreshUser '
        'yeniden bağlar', () async {
      memberships.put(membership('c01', role: ClubRole.board));
      final container = await resolvedActive();

      memberships
          .watchMyMembershipsController('u1')
          .add(const FirebaseFailure(FirestoreError.unavailable));
      await pumpEventQueue();
      expect(notifierOf(container).roleIn('c01'), ClubRole.board);
      expect(stateOf(container).isError, isFalse);
      expect(memberships.activeListeners, 0);

      memberships.memberships.clear();
      await notifierOf(container).refreshUser();
      await pumpEventQueue();
      expect(memberships.activeListeners, 1);
      expect(stateOf(container).memberships, isEmpty);
    });

    test('akış oturumun düştüğünü bildirirse (unauthenticated) → '
        'sessionExpired', () async {
      final container = await resolvedActive();
      memberships
          .watchMyMembershipsController('u1')
          .add(const FirebaseFailure(FirestoreError.unauthenticated));
      await pumpEventQueue();
      expect(stateOf(container).sessionExpired, isTrue);
    });

    test('signOut dinleyiciyi çıkıştan önce bırakır; çıkış başarısızsa '
        'yeniden bağlar', () async {
      memberships.put(membership('c01'));
      final container = await resolvedActive();

      auth.failNext(AuthError.network);
      expect(await notifierOf(container).signOut(), isFalse);
      await pumpEventQueue();
      expect(memberships.activeListeners, 1);
      expect(notifierOf(container).roleIn('c01'), ClubRole.member);

      expect(await notifierOf(container).signOut(), isTrue);
      expect(memberships.activeListeners, 0);
    });

    test('hesap askıya alınınca dinleyici bırakılır', () async {
      final container = await resolvedActive();
      expect(memberships.activeListeners, 1);
      users.users['u1'] = users.users['u1']!.copyWith(
        status: UserStatus.suspended,
      );
      await notifierOf(container).refreshUser();
      await pumpEventQueue();
      expect(memberships.activeListeners, 0);
    });

    test('kapsayıcı kapanınca üyelik dinleyicisi bırakılır', () async {
      users.putActive('u1');
      auth.currentUser = _user();
      final container = ProviderContainer()..read(sessionViewModelProvider);
      await pumpEventQueue();
      expect(memberships.activeListeners, 1);

      container.dispose();
      await pumpEventQueue();
      expect(memberships.activeListeners, 0);
    });
  });

  group('T-15 · SessionViewModel · engellenenler', () {
    late FakeBlockRepository blocks;

    setUp(() => blocks = GetIt.I<BlockRepository>() as FakeBlockRepository);

    test('oturum çözülünce yürürlükteki engeller okunur (kaldırılmış engel '
        've başkasının engeli hariç)', () async {
      blocks
        ..put('u1', 'u7')
        ..put('u1', 'u8')
        ..put('u2', 'u9');
      await blocks.softDeleteBlock(blockerId: 'u1', blockedId: 'u8');
      final container = await resolvedActive();

      expect(stateOf(container).blockedUserIds, {'u7'});
      expect(notifierOf(container).isBlocked('u7'), isTrue);
      expect(notifierOf(container).isBlocked('u8'), isFalse);
      expect(notifierOf(container).isBlocked('u9'), isFalse);
    });

    test('refreshUser engelleri yeniden okur; okunamazsa mevcut küme '
        'korunur', () async {
      blocks.put('u1', 'u7');
      final container = await resolvedActive();

      blocks.put('u1', 'u8');
      await notifierOf(container).refreshUser();
      expect(stateOf(container).blockedUserIds, {'u7', 'u8'});

      blocks.failNext(FirestoreError.unavailable);
      await notifierOf(container).refreshUser();
      expect(stateOf(container).blockedUserIds, {'u7', 'u8'});
      expect(stateOf(container).isError, isFalse);
    });

    test('T-18 · setBlocked kümeyi okumadan günceller; aktif olmayan '
        'oturumda etkisizdir', () async {
      blocks.put('u1', 'u7');
      final container = await resolvedActive();
      final reads = blocks.calls.length;

      notifierOf(container).setBlocked('u8', isBlocked: true);
      expect(stateOf(container).blockedUserIds, {'u7', 'u8'});
      notifierOf(container)
        ..setBlocked('u7', isBlocked: false)
        ..setBlocked('u9', isBlocked: false);
      expect(stateOf(container).blockedUserIds, {'u8'});
      expect(blocks.calls, hasLength(reads));

      auth
        ..currentUser = null
        ..watchAuthStateController.add(null);
      await pumpEventQueue();
      notifierOf(container).setBlocked('u7', isBlocked: true);
      expect(stateOf(container).blockedUserIds, isEmpty);
    });

    test('kullanıcı belgesi okunamasa da refreshUser engelleri '
        'yeniler', () async {
      final container = await resolvedActive();
      blocks.put('u1', 'u7');
      users.failNext(FirestoreError.unavailable);
      await notifierOf(container).refreshUser();
      expect(stateOf(container).blockedUserIds, {'u7'});
      expect(stateOf(container).status, AuthStatus.active);
    });

    test('aktif olmayan oturumda engeller okunmaz; oturum kapanınca küme '
        'temizlenir', () async {
      auth.currentUser = _user();
      final container = await resolved();
      expect(stateOf(container).status, AuthStatus.profileIncomplete);
      expect(blocks.calls, isEmpty);

      blocks.put('u1', 'u7');
      users.putActive('u1');
      await notifierOf(container).refreshUser();
      expect(stateOf(container).blockedUserIds, {'u7'});

      auth
        ..currentUser = null
        ..watchAuthStateController.add(null);
      await pumpEventQueue();
      expect(stateOf(container).blockedUserIds, isEmpty);
    });

    test('yarış: engeller okunurken oturum kapanırsa geç gelen sonuç '
        'yazılmaz', () async {
      final gate = Completer<void>();
      blocks
        ..put('u1', 'u7')
        ..fetchActiveBlocksGate = gate;
      final container = await resolvedActive();
      expect(stateOf(container).status, AuthStatus.active);
      expect(stateOf(container).blockedUserIds, isEmpty);

      auth
        ..currentUser = null
        ..watchAuthStateController.add(null);
      await pumpEventQueue();
      gate.complete();
      await pumpEventQueue();
      expect(
        stateOf(container),
        const SessionState(status: AuthStatus.signedOut),
      );
    });

    test('yarış: eski yenilemenin engel sonucu yenisini ezmez', () async {
      blocks.put('u1', 'u7');
      final container = await resolvedActive();
      final gate = Completer<void>();
      blocks.fetchActiveBlocksGate = gate;

      // İlk yenileme {u7} sonucunu kapıda bekletir.
      final first = notifierOf(container).refreshUser();
      await pumpEventQueue();
      blocks
        ..put('u1', 'u8')
        ..fetchActiveBlocksGate = null;
      await notifierOf(container).refreshUser();
      expect(stateOf(container).blockedUserIds, {'u7', 'u8'});

      gate.complete();
      await first;
      expect(stateOf(container).blockedUserIds, {'u7', 'u8'});
    });
  });

  group('T-13 · SessionViewModel · askı bildirimi (W-03, DLG-01)', () {
    FakeFeedbackService feedback() =>
        GetIt.I<FeedbackService>() as FakeFeedbackService;
    FakeUrlLauncherService launcher() =>
        GetIt.I<UrlLauncherService>() as FakeUrlLauncherService;

    /// Askıdaki `u1` oturumuyla çözülmüş kapsayıcı (oturum kapatılmış).
    Future<ProviderContainer> resolvedSuspended() {
      users.users['u1'] = users
          .putActive('u1')
          .copyWith(status: UserStatus.suspended);
      auth.currentUser = _user();
      return resolved();
    }

    test('askı bildirimi kendiliğinden gösterilmez: yönlendirme sürerken '
        'itilen dialog sayfayla birlikte düşerdi', () async {
      final container = await resolvedSuspended();
      expect(stateOf(container).status, AuthStatus.signedOut);
      expect(feedback().dialogs, isEmpty);
    });

    test('showPendingSuspendedNotice bekleyen bildirimi bir kez gösterir '
        '(DLG-01)', () async {
      final container = await resolvedSuspended();
      await notifierOf(container).showPendingSuspendedNotice();
      expect(feedback().dialogs, [DialogId.dlg01]);

      await notifierOf(container).showPendingSuspendedNotice();
      expect(feedback().dialogs, [DialogId.dlg01]);
      expect(launcher().opened, isEmpty);
    });

    test('"Destekle iletişime geç": dış bağlantı onayı (DLG-32) verilince '
        'destek adresine e-posta açar', () async {
      final container = await resolvedSuspended();
      feedback()
        ..nextDialogResult = true
        ..dialogResults[DialogId.dlg32] = true;
      await notifierOf(container).showPendingSuspendedNotice();
      expect(feedback().dialogs, [DialogId.dlg01, DialogId.dlg32]);
      expect(launcher().opened, [AppConstants.supportMailUri]);
    });

    test('bekleyen bildirim yokken çağrı etkisizdir', () async {
      final container = await resolvedActive();
      await notifierOf(container).showPendingSuspendedNotice();
      expect(feedback().dialogs, isEmpty);
    });

    test('durum suspended olduğu anda bildirim hazırdır (durumu dinleyen '
        'giriş ekranı aynı anda isteyebilir)', () async {
      users.users['u1'] = users
          .putActive('u1')
          .copyWith(status: UserStatus.suspended);
      auth.currentUser = _user();
      final container = createContainer();
      container.listen(
        sessionViewModelProvider.select((state) => state.status),
        (_, next) {
          if (next == AuthStatus.suspended) {
            unawaited(notifierOf(container).showPendingSuspendedNotice());
          }
        },
      );
      await pumpEventQueue();
      expect(feedback().dialogs, [DialogId.dlg01]);
      expect(stateOf(container).status, AuthStatus.signedOut);
    });

    test('jeton hatasıyla (userDisabled) gelen askı da bildirimi sıraya alır; '
        'art arda iki olay oturumu bir kez kapatır', () async {
      final container = await resolvedActive();
      auth.tokenErrorController
        ..add(AuthError.userDisabled)
        ..add(AuthError.userDisabled);
      await pumpEventQueue();
      expect(auth.callsTo('signOut'), hasLength(1));
      expect(stateOf(container).status, AuthStatus.signedOut);

      await notifierOf(container).showPendingSuspendedNotice();
      expect(feedback().dialogs, [DialogId.dlg01]);
    });

    test('onSuspended oturumu kapatır ve bildirimi sıraya alır', () async {
      final container = await resolvedActive();
      await notifierOf(container).onSuspended();
      await pumpEventQueue();
      expect(auth.callsTo('signOut'), hasLength(1));
      expect(stateOf(container).status, AuthStatus.signedOut);
      await notifierOf(container).showPendingSuspendedNotice();
      expect(feedback().dialogs, [DialogId.dlg01]);
    });
  });

  group('T-25 · SessionViewModel · hatırlatıcılar (PLAN §15.6)', () {
    late FakeLocalReminderService reminders;
    late FakeRsvpRepository rsvps;
    late FakeEventRepository events;
    late FakeNotificationRepository inbox;

    setUp(() {
      reminders = GetIt.I<LocalReminderService>() as FakeLocalReminderService;
      rsvps = GetIt.I<RsvpRepository>() as FakeRsvpRepository;
      events = GetIt.I<EventRepository>() as FakeEventRepository;
      inbox = GetIt.I<NotificationRepository>() as FakeNotificationRepository;
    });

    /// [startsIn] sonra başlayan, iki saat süren yayındaki etkinlik.
    EventModel eventIn(String id, Duration startsIn) {
      final startsAt = kDefaultFakeNowUtc.add(startsIn);
      return EventModel(
        id: id,
        clubId: 'c01',
        title: 'Etkinlik $id',
        type: EventType.training,
        startsAt: startsAt,
        endsAt: startsAt.add(const Duration(hours: 2)),
        coverPalette: ClubPalette.red,
        coverPattern: ClubPattern.dots,
        status: EventStatus.published,
      );
    }

    void join(EventModel event, {RsvpStatus status = RsvpStatus.going}) {
      events.put(event);
      rsvps.put(
        RsvpModel(
          eventId: event.id,
          clubId: event.clubId,
          userId: 'u1',
          ticketCode: 'GU-AAAA-AAAB',
          status: status,
          reminder: ReminderOption.oneHour,
        ),
      );
    }

    test('oturum etkinleşince kanal kurulur ve yalnızca going kayıtları '
        'yeniden planlanır; tetiklenmiş ama bitmemiş hatırlatıcının liste '
        'belgesi yazılır (geçmiş etkinliğinki değil); yenileme yeniden '
        'planlamaz', () async {
      join(eventIn('e_future', const Duration(days: 2)));
      join(eventIn('e_fired', const Duration(minutes: 30)));
      join(eventIn('e_past', const Duration(days: -1)));
      join(
        eventIn('e_wait', const Duration(days: 3)),
        status: RsvpStatus.waitlist,
      );

      final container = await resolvedActive();
      await pumpEventQueue();

      expect(reminders.channelEnsured, isTrue);
      expect(reminders.callsTo('rescheduleAll').single.args, [3]);
      expect(inbox.notifications.keys, ['event_reminder_e_fired_u1']);

      await notifierOf(container).refreshUser();
      await pumpEventQueue();
      expect(reminders.rescheduleCalls, 1);
    });

    test('T-44 · D3-02 · D2-06: yalnızca going kayıtları okunur; ikinci '
        'kurulumda bitmiş ya da iptal edilmiş etkinlik yeniden okunmaz, '
        'gelecektekiler okunur; planlar aynı', () async {
      join(eventIn('e_future', const Duration(days: 2)));
      join(eventIn('e_past', const Duration(days: -1)));
      join(
        eventIn(
          'e_cancel',
          const Duration(days: 1),
        ).copyWith(status: EventStatus.cancelled),
      );

      final container = await resolvedActive();
      await pumpEventQueue();
      expect(rsvps.callsTo('listMine').single.args, [
        'u1',
        {RsvpStatus.going},
        null,
      ]);
      expect(
        events.callsTo('getEvents').single.args.single,
        unorderedEquals(['e_future', 'e_past', 'e_cancel']),
      );
      final firstPlan = reminders.callsTo('rescheduleAll').single.args;
      final firstEvents = Map.of(reminders.lastEvents);
      events.calls.clear();

      await container
          .read(appPreferencesViewModelProvider.notifier)
          .setLocale(const Locale('en'));
      await pumpEventQueue();

      expect(reminders.rescheduleCalls, 2);
      expect(events.callsTo('getEvents').single.args.single, ['e_future']);
      expect(reminders.callsTo('rescheduleAll').last.args, firstPlan);
      expect(reminders.lastEvents.keys, ['e_future']);
      expect(firstEvents.keys.toSet(), {'e_future', 'e_past', 'e_cancel'});
    });

    test('dil değişince yeni dille yeniden kurulur; çıkışta planlar iptal '
        'edilir', () async {
      final container = await resolvedActive();
      await pumpEventQueue();
      expect(reminders.rescheduleCalls, 1);

      await container
          .read(appPreferencesViewModelProvider.notifier)
          .setLocale(const Locale('en'));
      await pumpEventQueue();
      expect(reminders.rescheduleCalls, 2);
      expect(reminders.l10n?.localeName, 'en');

      final cancelled = reminders.cancelAllCalls;
      await notifierOf(container).signOut();
      await pumpEventQueue();
      expect(reminders.cancelAllCalls, cancelled + 1);
      // Oturum yokken dil değişimi planlamaz.
      await container
          .read(appPreferencesViewModelProvider.notifier)
          .setLocale(const Locale('tr'));
      await pumpEventQueue();
      expect(reminders.rescheduleCalls, 2);
    });

    test('soğuk açılış: hatırlatıcı yükü bir kez döner (liste belgesi ve '
        'yönlendirme NotificationNavigator.openPayload içinde — T-26); '
        'tanınmayan yük null', () async {
      events.put(eventIn('e01', const Duration(minutes: 30)));
      reminders.launchPayload = LocalReminderService.payloadFor('e01');
      final container = await resolvedActive();

      expect(
        await notifierOf(container).takeLaunchReminder(),
        'event_reminder:e01',
      );
      expect(inbox.callsTo('createSelf'), isEmpty);
      expect(await notifierOf(container).takeLaunchReminder(), isNull);
      expect(LocalReminderService.eventIdOfPayload('başka:e01'), isNull);
      expect(LocalReminderService.eventIdOfPayload('event_reminder:'), isNull);
    });

    test('soğuk açılış: tanınmayan yük atılır', () async {
      reminders.launchPayload = 'event:e01';
      final container = await resolvedActive();
      expect(await notifierOf(container).takeLaunchReminder(), isNull);
    });

    test('uygulama açıkken hatırlatıcı dokunuşu yalnızca etkin oturumda '
        'iletilir', () async {
      final container = await resolvedActive();
      final taps = <String>[];
      final subscription = notifierOf(
        container,
      ).reminderTaps.listen(taps.add);
      addTearDown(subscription.cancel);

      reminders.tap(LocalReminderService.payloadFor('e01'));
      await pumpEventQueue();
      expect(taps, ['event_reminder:e01']);

      auth
        ..currentUser = null
        ..watchAuthStateController.add(null);
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.signedOut);
      reminders.tap(LocalReminderService.payloadFor('e02'));
      await pumpEventQueue();
      expect(taps, ['event_reminder:e01']);
    });

    test('oturumsuz açılışta yük atılır: sonradan giriş yapılsa da etkinliğe '
        'gidilmez', () async {
      reminders.launchPayload = LocalReminderService.payloadFor('e01');
      final container = await resolved();
      expect(stateOf(container).status, AuthStatus.signedOut);

      users.putActive('u1');
      final user = _user();
      auth
        ..currentUser = user
        ..watchAuthStateController.add(user);
      await pumpEventQueue();
      expect(stateOf(container).status, AuthStatus.active);
      expect(await notifierOf(container).takeLaunchReminder(), isNull);
      expect(reminders.callsTo('initialLaunchPayload'), isEmpty);
    });
  });

  group('T-44 · SessionViewModel · açılış bütçesi ve önbellek (D2-02)', () {
    testWidgets("claim okuması hiç dönmezse oturum 3 + 3 sn sonra claim'siz "
        'çözülür ve belge okumasına geçer', (tester) async {
      final profile = users.putActive('u1');
      auth
        ..currentUser = _user()
        ..superAdminGate = Completer<void>();
      final container = createContainer()..read(sessionViewModelProvider);
      await tester.pump();
      expect(stateOf(container).isResolving, isTrue);

      await tester.pump(AppDurations.sessionClaimTimeout);
      expect(users.callsTo('getUser'), isEmpty);
      await tester.pump(AppDurations.sessionClaimTimeout);
      await tester.pump();

      expect(
        auth.callsTo('isSuperAdmin').map((call) => call.args.single),
        [true, false],
      );
      expect(users.callsTo('getUser'), hasLength(1));
      expect(stateOf(container).status, AuthStatus.active);
      expect(stateOf(container).user, profile);
      expect(stateOf(container).isSuperAdmin, isFalse);
      // testWidgets değişmezi: grup setUp'ının susturucusu gövde sonunda
      // bağlamanın yazıcısına döner (özgün değeri tearDown geri kurar).
      debugPrint = debugPrintSynchronously;
    });

    test(
      'belge okuması zaman aşımına uğrarsa önbellekteki belgeyle active',
      () async {
        final profile = users.putActive('u1');
        users
          ..cachedUsers['u1'] = profile
          ..failNext(FirestoreError.timeout);
        auth.currentUser = _user();
        final container = await resolved();

        expect(
          stateOf(container),
          SessionState(status: AuthStatus.active, uid: 'u1', user: profile),
        );
        expect(users.callsTo('getUserFromCache').single.args, ['u1']);
      },
    );

    test('sunucu erişilemez (unavailable) ve önbellek boşsa isError '
        '(SYS-02)', () async {
      users
        ..putActive('u1')
        ..failNext(FirestoreError.unavailable);
      auth.currentUser = _user();
      final container = await resolved();

      expect(
        stateOf(container),
        const SessionState(uid: 'u1', isError: true),
      );
      expect(users.callsTo('getUserFromCache'), hasLength(1));
    });

    test('başka hatalarda (yetki) önbelleğe düşülmez', () async {
      users
        ..putActive('u1')
        ..cachedUsers['u1'] = users.users['u1']!
        ..failNext(FirestoreError.permissionDenied);
      auth.currentUser = _user();
      final container = await resolved();

      expect(stateOf(container).isError, isTrue);
      expect(users.callsTo('getUserFromCache'), isEmpty);
    });

    testWidgets('SYS-02 "Yeniden dene" ile yeniden çözüm splash sınırının '
        '(Limits.splashTimeout) altında biter', (tester) async {
      users.putActive('u1');
      auth
        ..currentUser = _user()
        ..superAdminGate = Completer<void>();
      final container = createContainer();

      /// Sunucuya ulaşamayan cihaz: claim okumaları askıda, belge okuması
      /// `Limits.firestoreTimeout` sonra zaman aşımı, önbellek boş. Çözümün
      /// bittiği ana kadar geçen (sahte) süreyi döndürür.
      Future<Duration> resolveOnce(void Function() start) async {
        final gate = Completer<void>();
        final before = users.callsTo('getUser').length;
        users
          ..getUserGate = gate
          ..failNext(FirestoreError.timeout);
        start();
        await tester.pump();
        await tester.pump(AppDurations.sessionClaimTimeout);
        await tester.pump(AppDurations.sessionClaimTimeout);
        await tester.pump();
        expect(users.callsTo('getUser'), hasLength(before + 1));
        await tester.pump(Limits.firestoreTimeout);
        gate.complete();
        await tester.pump();
        expect(stateOf(container).isResolving, isFalse);
        return AppDurations.sessionClaimTimeout * 2 + Limits.firestoreTimeout;
      }

      final first = await resolveOnce(
        () => container.read(sessionViewModelProvider),
      );
      expect(stateOf(container).isError, isTrue);
      expect(first, lessThan(Limits.splashTimeout));

      final retry = await resolveOnce(
        () => unawaited(notifierOf(container).resolve()),
      );
      expect(stateOf(container).isError, isTrue);
      expect(retry, lessThan(Limits.splashTimeout));
      debugPrint = debugPrintSynchronously;
    });
  });

  group('T-44 · SessionViewModel · Crashlytics kullanıcı kimliği (D2-11)', () {
    test('oturum açılınca uid bağlanır, kapanınca temizlenir; aynı uid '
        'yeniden yazılmaz', () async {
      final crash = GetIt.I<CrashService>() as FakeCrashService;
      final container = await resolvedActive();
      await notifierOf(container).refreshUser();
      await notifierOf(container).resolve();

      auth
        ..currentUser = null
        ..watchAuthStateController.add(null);
      await pumpEventQueue();

      expect(stateOf(container).status, AuthStatus.signedOut);
      expect(
        crash.callsTo('setUserId').map((call) => call.args.single),
        ['u1', null],
      );
    });

    test('oturumsuz açılışta kimlik yazılmaz', () async {
      final crash = GetIt.I<CrashService>() as FakeCrashService;
      await resolved();
      expect(crash.callsTo('setUserId'), isEmpty);
    });
  });

  group('T-45 · SessionViewModel · son aramalar hesaba özeldir (A3-02)', () {
    const terms = ['hackathon', 'satranç'];

    test('signOut son aramaları sessizce siler (toast yok)', () async {
      final container = await resolvedActive();
      store.values[AppPreferenceKeys.recentSearches] = terms;

      expect(await notifierOf(container).signOut(), isTrue);
      await pumpEventQueue();

      expect(stateOf(container).status, AuthStatus.signedOut);
      expect(store.recentSearches, isEmpty);
      expect(
        (GetIt.I<FeedbackService>() as FakeFeedbackService).toasts,
        isEmpty,
      );
    });

    test('oturum dışarıdan kapanınca da silinir', () async {
      final container = await resolvedActive();
      store.values[AppPreferenceKeys.recentSearches] = terms;

      auth
        ..currentUser = null
        ..watchAuthStateController.add(null);
      await pumpEventQueue();

      expect(stateOf(container).status, AuthStatus.signedOut);
      expect(store.recentSearches, isEmpty);
    });

    test('hesap değişiminde (A → B, arada çıkış olayı olmadan) silinir; aynı '
        'hesabın yeniden çözümünde korunur', () async {
      final container = await resolvedActive();
      store.values[AppPreferenceKeys.recentSearches] = terms;
      await notifierOf(container).resolve();
      await notifierOf(container).refreshUser();
      expect(store.recentSearches, terms);
      expect(store.callsTo('setRecentSearches'), isEmpty);

      users.putActive('u2');
      auth
        ..currentUser = _user(uid: 'u2')
        ..watchAuthStateController.add(_user(uid: 'u2'));
      await pumpEventQueue();

      expect(stateOf(container).uid, 'u2');
      expect(store.recentSearches, isEmpty);
    });

    test('boş liste yeniden yazılmaz (oturumsuz açılış)', () async {
      await resolved();
      expect(store.callsTo('setRecentSearches'), isEmpty);
    });
  });
}
