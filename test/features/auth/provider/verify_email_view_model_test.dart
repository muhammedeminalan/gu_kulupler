// AUT-03 · VerifyEmailViewModel: başlangıç (adres + kayıttan kalan bekleme),
// "Doğruladım" (doğrulanmamış → TST-02; doğrulanmış → başarı görünümü →
// oturum çözümü; çevrimdışı / ağ / diğer; oturum çözülemedi), "Tekrar gönder"
// (TST-03 + 60 sn bekleme, TST-X3 kalan saniye, sunucu kısıtı), art arda
// tetikleme, beklemenin kalkması (PLAN §12.5; W-56c). Bekleme sahte saatle
// (`FakeAppClock`), kimlik `FakeAuthRepository` ile (gerçek 60 sn kuralı).
//
// Başarı görünümü bir süre ekranda kalır (`successHold`): o yolun testleri
// sahte zamanla (`testWidgets` + `tester.pump`) koşar.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/auth/provider/verify_email_state.dart';
import 'package:gu_kulupler/features/auth/provider/verify_email_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/test_container.dart';

const String _email = 'ayse.demir@ogr.gumushane.edu.tr';
const String _password = 'Sifre123';
const String _name = 'Ayşe Demir';
const String _uid = 'u1';
const Duration _cooldown = Limits.verificationResendCooldown;

AuthUserInfo _user({bool verified = false}) =>
    AuthUserInfo(uid: _uid, email: _email, emailVerified: verified);

void main() {
  late FakeAuthRepository auth;
  late FakeUserRepository users;
  late FakeFeedbackService feedback;
  late FakeAppClock clock;
  late FakeConnectivityService connectivity;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    auth = GetIt.I<AuthRepository>() as FakeAuthRepository;
    users = GetIt.I<UserRepository>() as FakeUserRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    clock = GetIt.I<AppClock>() as FakeAppClock;
    connectivity = GetIt.I<ConnectivityService>() as FakeConnectivityService;
    auth.service.uid = _uid;
  });

  /// Günlük satırlarını toplar (konsola düşmez). Dönen işlev özgün
  /// `debugPrint`'i geri kurar; `testWidgets` gövdesi bitmeden çağrılmalıdır.
  (List<String>, VoidCallback) captureLogs() {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    return (logs, () => debugPrint = original);
  }

  /// Dinlenen (ömrü test boyunca süren) ViewModel'li ve oturumu dinleyen
  /// kapsayıcı; [states] verilirse her state değişimi sırayla eklenir.
  ProviderContainer containerOf({List<VerifyEmailState>? states}) {
    final container = createContainer();
    addTearDown(container.listen(sessionViewModelProvider, (_, _) {}).close);
    addTearDown(
      container
          .listen(verifyEmailViewModelProvider, (_, next) => states?.add(next))
          .close,
    );
    return container;
  }

  VerifyEmailViewModel vmOf(ProviderContainer container) =>
      container.read(verifyEmailViewModelProvider.notifier);

  VerifyEmailState stateOf(ProviderContainer container) =>
      container.read(verifyEmailViewModelProvider);

  SessionState sessionOf(ProviderContainer container) =>
      container.read(sessionViewModelProvider);

  /// Hesabı kayıt akışıyla açar: oturum doğrulanmamıştır, doğrulama e-postası
  /// gönderilmiş ve 60 sn bekleme başlamıştır.
  Future<void> register() async {
    final result = await auth.register(
      email: _email,
      password: _password,
      name: _name,
    );
    expect(result.isSuccess, isTrue);
    auth.resetFake();
  }

  group('AUT-03 · VerifyEmailViewModel · başlangıç', () {
    test('adres oturumdaki kullanıcıdan gelir; bekleme yok', () {
      auth.currentUser = _user();
      expect(stateOf(containerOf()), const VerifyEmailState(email: _email));
    });

    test('kayıttan gelen kullanıcı: 60 sn bekleme başlamıştır', () async {
      await register();
      final container = containerOf();
      final now = clock.nowUtc();
      expect(
        stateOf(container),
        VerifyEmailState(email: _email, resendAvailableAt: now.add(_cooldown)),
      );
      expect(vmOf(container).remainingResend(now), _cooldown);
    });

    test('bekleme sürerken açılırsa kalan süre korunur', () async {
      await register();
      final registeredAt = clock.nowUtc();
      clock.advance(const Duration(seconds: 18));
      final container = containerOf();
      expect(stateOf(container).resendAvailableAt, registeredAt.add(_cooldown));
      expect(
        vmOf(container).remainingResend(clock.nowUtc()),
        const Duration(seconds: 42),
      );
    });

    test('oturum yoksa adres boştur', () {
      expect(stateOf(containerOf()), const VerifyEmailState());
    });
  });

  group('AUT-03 · VerifyEmailViewModel · checkVerified (AUT-03.confirm)', () {
    test('hâlâ doğrulanmamış → TST-02; oturum yeniden çözülmez', () async {
      auth.currentUser = _user();
      final states = <VerifyEmailState>[];
      final container = containerOf(states: states);
      await pumpEventQueue();
      auth.resetFake();

      final outcome = await vmOf(container).checkVerified();

      expect(outcome, VerifyOutcome.unverified);
      expect(states, const [
        VerifyEmailState(email: _email, isChecking: true),
        VerifyEmailState(email: _email, lastCheckWasUnverified: true),
      ]);
      expect(feedback.toasts, [ToastId.tst02]);
      expect(auth.callsTo('reloadUser'), hasLength(1));
      expect(auth.callsTo('isSuperAdmin'), isEmpty);
      expect(sessionOf(container).status, AuthStatus.unverified);
    });

    testWidgets('doğrulanmış → başarı görünümü → bekleme → oturum çözülür '
        '(profil yok: profileIncomplete)', (tester) async {
      auth.currentUser = _user();
      final states = <VerifyEmailState>[];
      final container = containerOf(states: states);
      await tester.pump();
      auth.service.emailVerified = true;

      VerifyOutcome? outcome;
      final pending = vmOf(
        container,
      ).checkVerified().then((value) => outcome = value);
      await tester.pump();

      // Başarı görünümü açık; oturum henüz çözülmedi (yönlendirme yok).
      expect(states, const [
        VerifyEmailState(email: _email, isChecking: true),
        VerifyEmailState(email: _email, isVerified: true),
      ]);
      expect(outcome, isNull);
      expect(sessionOf(container).status, AuthStatus.unverified);

      await tester.pump(
        VerifyEmailViewModel.successHold - const Duration(milliseconds: 1),
      );
      expect(outcome, isNull);
      expect(sessionOf(container).status, AuthStatus.unverified);

      await tester.pump(const Duration(milliseconds: 1));
      await pending;

      expect(outcome, VerifyOutcome.verified);
      expect(sessionOf(container).status, AuthStatus.profileIncomplete);
      expect(sessionOf(container).uid, _uid);
      expect(stateOf(container).isVerified, isTrue);
      expect(stateOf(container).isError, isFalse);
      expect(feedback.toasts, isEmpty);
      // Kimlik jetonu doğrulama sonrası yenilenir (Rules `email_verified`).
      expect(auth.service.callsTo('idTokenClaims').first.args, [true]);
    });

    testWidgets('doğrulanmış + profili tamam → oturum active', (tester) async {
      users.putActive(_uid);
      auth.currentUser = _user();
      final container = containerOf();
      await tester.pump();
      auth.service.emailVerified = true;

      final pending = vmOf(container).checkVerified();
      await tester.pump();
      await tester.pump(VerifyEmailViewModel.successHold);

      expect(await pending, VerifyOutcome.verified);
      expect(sessionOf(container).status, AuthStatus.active);
    });

    testWidgets('önce doğrulanmamış, sonra doğrulanmış: bayrak sıfırlanır', (
      tester,
    ) async {
      auth.currentUser = _user();
      final container = containerOf();
      await tester.pump();

      expect(await vmOf(container).checkVerified(), VerifyOutcome.unverified);
      expect(stateOf(container).lastCheckWasUnverified, isTrue);

      auth.service.emailVerified = true;
      final pending = vmOf(container).checkVerified();
      await tester.pump();
      expect(stateOf(container).lastCheckWasUnverified, isFalse);
      expect(stateOf(container).isVerified, isTrue);
      await tester.pump(VerifyEmailViewModel.successHold);
      expect(await pending, VerifyOutcome.verified);
      expect(feedback.toasts, [ToastId.tst02]);
    });

    testWidgets('başarı görünümünde yeni denetim ve yeniden gönderme yok '
        'sayılır', (tester) async {
      auth.currentUser = _user();
      final container = containerOf();
      await tester.pump();
      auth.service.emailVerified = true;

      final pending = vmOf(container).checkVerified();
      await tester.pump();
      expect(stateOf(container).isVerified, isTrue);
      auth.resetFake();

      expect(await vmOf(container).checkVerified(), VerifyOutcome.failed);
      await vmOf(container).resend();
      expect(auth.callsTo('reloadUser'), isEmpty);
      expect(auth.callsTo('sendEmailVerification'), isEmpty);
      expect(feedback.toasts, isEmpty);

      await tester.pump(VerifyEmailViewModel.successHold);
      expect(await pending, VerifyOutcome.verified);
    });

    testWidgets('oturum çözülemezse başarı görünümü geri alınır, hata satırı '
        'açılır; yeniden deneme başarır', (tester) async {
      final (logs, restoreLogs) = captureLogs();
      try {
        auth.currentUser = _user();
        final container = containerOf();
        await tester.pump();
        auth.service.emailVerified = true;
        users.failNext(FirestoreError.unavailable);

        final failing = vmOf(container).checkVerified();
        await tester.pump();
        await tester.pump(VerifyEmailViewModel.successHold);

        expect(await failing, VerifyOutcome.failed);
        expect(sessionOf(container).status, AuthStatus.unverified);
        expect(sessionOf(container).isError, isTrue);
        expect(
          stateOf(container),
          const VerifyEmailState(email: _email, isError: true),
        );
        expect(
          logs,
          contains(contains('E-posta doğrulandı ama oturum çözülemedi')),
        );

        final retry = vmOf(container).checkVerified();
        await tester.pump();
        expect(stateOf(container).isError, isFalse);
        await tester.pump(VerifyEmailViewModel.successHold);
        expect(await retry, VerifyOutcome.verified);
        expect(sessionOf(container).status, AuthStatus.profileIncomplete);
      } finally {
        restoreLogs();
      }
    });

    testWidgets('bekleme sürerken ViewModel bırakılırsa zamanlayıcı kalmaz ve '
        'oturum çözülmez', (tester) async {
      auth.currentUser = _user();
      final container = ProviderContainer();
      final session = container.listen(sessionViewModelProvider, (_, _) {});
      final viewModel = container.listen(
        verifyEmailViewModelProvider,
        (_, _) {},
      );
      await tester.pump();
      auth.service.emailVerified = true;

      final pending = vmOf(container).checkVerified();
      await tester.pump();
      expect(stateOf(container).isVerified, isTrue);
      auth.resetFake();

      viewModel.close();
      session.close();
      container.dispose();
      expect(await pending, VerifyOutcome.verified);
      expect(auth.callsTo('isSuperAdmin'), isEmpty);
      // Bekleyen zamanlayıcı kalsaydı test bağlayıcısı testi düşürürdü.
    });

    test('çevrimdışı → TST-24; sunucuya gidilmez', () async {
      auth.currentUser = _user();
      final states = <VerifyEmailState>[];
      final container = containerOf(states: states);
      connectivity.isOffline = true;

      expect(await vmOf(container).checkVerified(), VerifyOutcome.failed);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(auth.callsTo('reloadUser'), isEmpty);
      expect(states, isEmpty);
    });

    test('ağ hatası → TST-24; hata satırı açılmaz', () async {
      auth.currentUser = _user();
      final container = containerOf();
      auth.failNext(AuthError.network);

      expect(await vmOf(container).checkVerified(), VerifyOutcome.failed);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(stateOf(container), const VerifyEmailState(email: _email));
    });

    test('beklenmeyen hata → hata satırı + günlük; sonraki denetim satırı '
        'kapatır', () async {
      final (logs, restoreLogs) = captureLogs();
      addTearDown(restoreLogs);
      auth.currentUser = _user();
      final states = <VerifyEmailState>[];
      final container = containerOf(states: states);
      auth.failNext(AuthError.unknown);

      expect(await vmOf(container).checkVerified(), VerifyOutcome.failed);
      expect(
        stateOf(container),
        const VerifyEmailState(email: _email, isError: true),
      );
      expect(feedback.toasts, isEmpty);
      expect(
        logs.single,
        contains('E-posta doğrulaması denetlenemedi: unknown'),
      );
      // Günlüğe kişisel veri (adres) yazılmaz.
      expect(logs.single, isNot(contains(_email)));

      states.clear();
      expect(await vmOf(container).checkVerified(), VerifyOutcome.unverified);
      expect(
        states.first,
        const VerifyEmailState(email: _email, isChecking: true),
      );
      expect(stateOf(container).isError, isFalse);
    });

    for (final error in [AuthError.sessionExpired, AuthError.userDisabled]) {
      test('${error.name}: sessiz kalır (oturum katmanı ele alır)', () async {
        auth.currentUser = _user();
        final container = containerOf();
        auth.failNext(error);

        expect(await vmOf(container).checkVerified(), VerifyOutcome.failed);
        expect(feedback.toasts, isEmpty);
        expect(feedback.dialogs, isEmpty);
        expect(stateOf(container), const VerifyEmailState(email: _email));
      });
    }

    test(
      'art arda tetikleme: süren denetim varken ikinci çağrı yok sayılır',
      () async {
        auth.currentUser = _user();
        final container = containerOf();

        final first = vmOf(container).checkVerified();
        expect(stateOf(container).isChecking, isTrue);
        expect(await vmOf(container).checkVerified(), VerifyOutcome.failed);
        expect(await first, VerifyOutcome.unverified);

        expect(auth.callsTo('reloadUser'), hasLength(1));
        expect(feedback.toasts, [ToastId.tst02]);
        // Bittikten sonra yeniden denetlenebilir.
        expect(await vmOf(container).checkVerified(), VerifyOutcome.unverified);
        expect(auth.callsTo('reloadUser'), hasLength(2));
      },
    );
  });

  group('AUT-03 · VerifyEmailViewModel · resend (AUT-03.resend)', () {
    test('gönderildi → TST-03 + 60 sn bekleme', () async {
      auth.currentUser = _user();
      final states = <VerifyEmailState>[];
      final container = containerOf(states: states);
      final until = clock.nowUtc().add(_cooldown);

      await vmOf(container).resend();

      expect(states, [
        const VerifyEmailState(email: _email, isResending: true),
        VerifyEmailState(email: _email, resendAvailableAt: until),
      ]);
      expect(feedback.toasts, [ToastId.tst03]);
      expect(auth.callsTo('sendEmailVerification'), hasLength(1));
      expect(vmOf(container).remainingResend(clock.nowUtc()), _cooldown);
    });

    test(
      'bekleme sürerken → TST-X3 kalan saniyeyle; gönderim yapılmaz',
      () async {
        await register();
        final states = <VerifyEmailState>[];
        final container = containerOf(states: states);

        await vmOf(container).resend();
        clock.advance(const Duration(seconds: 18));
        await vmOf(container).resend();
        // Kesirli saniye yukarı yuvarlanır (düğmedeki geri sayımla aynı).
        clock.advance(const Duration(milliseconds: 41500));
        await vmOf(container).resend();

        expect(feedback.toasts, [ToastId.tstX3, ToastId.tstX3, ToastId.tstX3]);
        expect(feedback.toastParams, const [
          ToastParams(s: '60'),
          ToastParams(s: '42'),
          ToastParams(s: '1'),
        ]);
        expect(auth.callsTo('sendEmailVerification'), isEmpty);
        expect(states, isEmpty);
      },
    );

    test(
      'bekleme dolunca yeniden gönderilir ve bekleme baştan başlar',
      () async {
        await register();
        final container = containerOf();
        clock.advance(_cooldown);

        await vmOf(container).resend();

        expect(feedback.toasts, [ToastId.tst03]);
        expect(auth.callsTo('sendEmailVerification'), hasLength(1));
        expect(
          stateOf(container).resendAvailableAt,
          clock.nowUtc().add(_cooldown),
        );

        clock.advance(const Duration(seconds: 59));
        await vmOf(container).resend();
        expect(feedback.toasts.last, ToastId.tstX3);
        expect(feedback.toastParams.last, const ToastParams(s: '1'));
        expect(auth.callsTo('sendEmailVerification'), hasLength(1));
      },
    );

    test('repository beklemeyi bildirirse (ekran bilmiyordu) → bekleme kurulur '
        '+ TST-X3', () async {
      auth.currentUser = _user();
      final container = containerOf();
      expect(stateOf(container).resendAvailableAt, isNull);
      // Ekran açıkken başka bir yoldan gönderildi: bekleme repository'de.
      expect((await auth.sendEmailVerification()).isSuccess, isTrue);
      final until = clock.nowUtc().add(_cooldown);
      clock.advance(const Duration(seconds: 10));
      auth.resetFake();

      await vmOf(container).resend();

      expect(
        stateOf(container),
        VerifyEmailState(email: _email, resendAvailableAt: until),
      );
      expect(feedback.toasts, [ToastId.tstX3]);
      expect(feedback.toastParams, const [ToastParams(s: '50')]);
      // SDK'ya gidilmedi (bekleme repository'de kesildi).
      expect(auth.service.callsTo('sendEmailVerification'), hasLength(1));
    });

    test(
      'sunucu kısıtı (tooManyRequests) → yerel 60 sn bekleme + TST-X3',
      () async {
        auth.currentUser = _user();
        final container = containerOf();
        auth.failNext(AuthError.tooManyRequests);

        await vmOf(container).resend();

        expect(
          stateOf(container),
          VerifyEmailState(
            email: _email,
            resendAvailableAt: clock.nowUtc().add(_cooldown),
          ),
        );
        expect(feedback.toasts, [ToastId.tstX3]);
        expect(feedback.toastParams, const [ToastParams(s: '60')]);
      },
    );

    test('çevrimdışı → TST-24; gönderim yapılmaz', () async {
      auth.currentUser = _user();
      final states = <VerifyEmailState>[];
      final container = containerOf(states: states);
      connectivity.isOffline = true;

      await vmOf(container).resend();

      expect(feedback.toasts, [ToastId.tst24]);
      expect(auth.callsTo('sendEmailVerification'), isEmpty);
      expect(states, isEmpty);
    });

    test('ağ hatası → TST-24; bekleme başlamaz', () async {
      auth.currentUser = _user();
      final container = containerOf();
      auth.failNext(AuthError.network);

      await vmOf(container).resend();

      expect(feedback.toasts, [ToastId.tst24]);
      expect(stateOf(container), const VerifyEmailState(email: _email));
    });

    test('beklenmeyen hata → hata satırı + günlük; sonraki gönderim satırı '
        'kapatır', () async {
      final (logs, restoreLogs) = captureLogs();
      addTearDown(restoreLogs);
      auth.currentUser = _user();
      final container = containerOf();
      auth.failNext(AuthError.unknown);

      await vmOf(container).resend();

      expect(
        stateOf(container),
        const VerifyEmailState(email: _email, isError: true),
      );
      expect(feedback.toasts, isEmpty);
      expect(
        logs.single,
        contains('Doğrulama e-postası gönderilemedi: unknown'),
      );

      await vmOf(container).resend();
      expect(stateOf(container).isError, isFalse);
      expect(feedback.toasts, [ToastId.tst03]);
    });

    test('sessionExpired: sessiz kalır (oturum katmanı ele alır)', () async {
      auth.currentUser = _user();
      final container = containerOf();
      auth.failNext(AuthError.sessionExpired);

      await vmOf(container).resend();

      expect(feedback.toasts, isEmpty);
      expect(stateOf(container), const VerifyEmailState(email: _email));
    });

    test(
      'art arda tetikleme: süren gönderim varken ikinci çağrı yok sayılır',
      () async {
        auth.currentUser = _user();
        final container = containerOf();

        final first = vmOf(container).resend();
        expect(stateOf(container).isResending, isTrue);
        await vmOf(container).resend();
        await first;

        expect(auth.callsTo('sendEmailVerification'), hasLength(1));
        expect(feedback.toasts, [ToastId.tst03]);
      },
    );
  });

  group('AUT-03 · VerifyEmailViewModel · bekleme', () {
    test(
      'clearResendCooldown: bekleme sürerken etkisiz; dolunca kaldırır',
      () async {
        await register();
        final states = <VerifyEmailState>[];
        final container = containerOf(states: states);

        clock.advance(const Duration(seconds: 59));
        vmOf(container).clearResendCooldown();
        expect(states, isEmpty);
        expect(stateOf(container).resendAvailableAt, isNotNull);

        clock.advance(const Duration(seconds: 1));
        vmOf(container).clearResendCooldown();
        expect(states, const [VerifyEmailState(email: _email)]);
      },
    );

    test('clearResendCooldown: bekleme yoksa state yayınlamaz', () {
      auth.currentUser = _user();
      final states = <VerifyEmailState>[];
      final container = containerOf(states: states);

      vmOf(container).clearResendCooldown();

      expect(states, isEmpty);
    });

    test('remainingResend: bekleme yoksa sıfır; eksi olmaz', () async {
      auth.currentUser = _user();
      final container = containerOf();
      expect(vmOf(container).remainingResend(clock.nowUtc()), Duration.zero);

      await vmOf(container).resend();
      expect(
        vmOf(
          container,
        ).remainingResend(clock.nowUtc().add(const Duration(seconds: 25))),
        const Duration(seconds: 35),
      );
      expect(
        vmOf(
          container,
        ).remainingResend(clock.nowUtc().add(const Duration(minutes: 3))),
        Duration.zero,
      );
    });

    test('successHold: onay işareti çizimi kadar (daire + gecikme + tik)', () {
      expect(
        VerifyEmailViewModel.successHold,
        const Duration(milliseconds: 1020),
      );
    });
  });
}
