// AUT-04 · ResetPasswordViewModel: başlangıç, alan mutasyonu, doğrulama
// kuralları, gönderim (başarı / çevrimdışı / ağ / sunucu kısıtı / adres
// hatası / diğer), hesabın sızdırılmaması, yeniden gönderim ve 60 sn bekleme,
// art arda tetik, ekran kapanınca yazmama (PLAN §12.5). Bekleme sahte saatle
// (`FakeAppClock`), kimlik `FakeAuthRepository` ile.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/auth/provider/reset_password_state.dart';
import 'package:gu_kulupler/features/auth/provider/reset_password_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/test_container.dart';

const String _email = 'ayse.demir@ogr.gumushane.edu.tr';
const Duration _cooldown = Duration(seconds: 60);

void main() {
  late FakeAuthRepository auth;
  late FakeFeedbackService feedback;
  late FakeAppClock clock;
  late FakeConnectivityService connectivity;
  late List<String> logs;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    auth = GetIt.I<AuthRepository>() as FakeAuthRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    clock = GetIt.I<AppClock>() as FakeAppClock;
    connectivity = GetIt.I<ConnectivityService>() as FakeConnectivityService;
    logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);
  });

  /// Dinlenen (ömrü test boyunca süren) ViewModel'li kapsayıcı; [states]
  /// verilirse her state değişimi sırayla eklenir.
  ProviderContainer containerOf({List<ResetPasswordState>? states}) {
    final container = createContainer();
    addTearDown(
      container
          .listen(
            resetPasswordViewModelProvider,
            (_, next) => states?.add(next),
          )
          .close,
    );
    return container;
  }

  ResetPasswordViewModel vmOf(ProviderContainer container) =>
      container.read(resetPasswordViewModelProvider.notifier);

  ResetPasswordState stateOf(ProviderContainer container) =>
      container.read(resetPasswordViewModelProvider);

  List<Object?> sentTo() => [
    for (final call in auth.callsTo('sendPasswordReset')) call.args.single,
  ];

  /// Geçerli adresle formu gönderir ("gönderildi" görünümüne geçer).
  Future<ProviderContainer> sentContainer({
    List<ResetPasswordState>? states,
  }) async {
    final container = containerOf(states: states);
    vmOf(container).setEmail(_email);
    await vmOf(container).submit();
    expect(stateOf(container).isSent, isTrue);
    states?.clear();
    return container;
  }

  group('AUT-04 · ResetPasswordViewModel · alan', () {
    test('ilk state: boş form', () {
      expect(stateOf(containerOf()), const ResetPasswordState());
    });

    test('setEmail değeri yazar; aynı değer state yayınlamaz', () {
      final states = <ResetPasswordState>[];
      final container = containerOf(states: states);
      vmOf(container).setEmail(_email);
      expect(stateOf(container), const ResetPasswordState(email: _email));
      vmOf(container).setEmail(_email);
      expect(states, hasLength(1));
    });

    test('setEmail alan hatasını ve gönderim hatasını temizler', () async {
      final container = containerOf();
      await vmOf(container).submit();
      expect(stateOf(container).errors, {
        ResetField.email: FormFieldError.required,
      });
      vmOf(container).setEmail('a');
      expect(stateOf(container).errors, isEmpty);

      vmOf(container).setEmail(_email);
      auth.failNext(AuthError.unknown);
      await vmOf(container).submit();
      expect(stateOf(container).submitError, SubmitError.unknown);
      vmOf(container).setEmail('$_email ');
      expect(stateOf(container).submitError, isNull);
    });
  });

  group('AUT-04 · ResetPasswordViewModel · doğrulama', () {
    for (final (value, error) in [
      ('', FormFieldError.required),
      ('   ', FormFieldError.required),
      ('ayse', FormFieldError.invalidEmail),
      ('ayse@', FormFieldError.invalidEmail),
      ('ayse@ogr', FormFieldError.invalidEmail),
      ('ayse demir@ogr.gumushane.edu.tr', FormFieldError.invalidEmail),
      ('ayse@gmail.com', FormFieldError.domainNotAllowed),
      ('ayse@gumushane.edu.tr.evil.com', FormFieldError.domainNotAllowed),
    ]) {
      test('"$value" → ${error.name}', () {
        final container = containerOf();
        vmOf(container).setEmail(value);
        expect(vmOf(container).validate(), isFalse);
        expect(stateOf(container).errors, {ResetField.email: error});
      });
    }

    for (final value in [
      _email,
      'ali.veli@gumushane.edu.tr',
      '  $_email  ',
      'AYSE.DEMIR@OGR.GUMUSHANE.EDU.TR',
    ]) {
      test('"$value" geçerli; eski hata silinir', () {
        final container = containerOf();
        expect(vmOf(container).validate(), isFalse);
        vmOf(container).setEmail(value);
        expect(vmOf(container).validate(), isTrue);
        expect(stateOf(container).errors, isEmpty);
      });
    }

    test(
      'geçersiz form gönderilmez: istek, toast ve görünüm değişimi yok',
      () async {
        final container = containerOf();
        vmOf(container).setEmail('ayse@gmail.com');
        await vmOf(container).submit();
        expect(sentTo(), isEmpty);
        expect(feedback.toasts, isEmpty);
        expect(stateOf(container).isSent, isFalse);
        expect(stateOf(container).isSubmitting, isFalse);
        expect(stateOf(container).resendAvailableAt, isNull);
      },
    );
  });

  group('AUT-04 · ResetPasswordViewModel · gönderim', () {
    test('başarı: adres kırpılarak gider; meşgul → gönderildi + 60 sn '
        'bekleme; toast yok', () async {
      final states = <ResetPasswordState>[];
      final container = containerOf(states: states);
      vmOf(container).setEmail('  $_email ');
      states.clear();

      await vmOf(container).submit();

      expect(sentTo(), [_email]);
      expect(auth.resetSent, [_email]);
      final until = kDefaultFakeNowUtc.add(_cooldown);
      expect(states, [
        const ResetPasswordState(email: '  $_email ', isSubmitting: true),
        ResetPasswordState(
          email: _email,
          isSent: true,
          resendAvailableAt: until,
        ),
      ]);
      expect(stateOf(container).sentEmail, _email);
      expect(vmOf(container).remainingResend(clock.nowUtc()), _cooldown);
      expect(feedback.toasts, isEmpty);
      expect(logs, isEmpty);
    });

    test('art arda iki gönderim tek istek üretir', () async {
      final container = containerOf();
      vmOf(container).setEmail(_email);
      final first = vmOf(container).submit();
      final second = vmOf(container).submit();
      await Future.wait([first, second]);
      expect(sentTo(), hasLength(1));
      expect(stateOf(container).isSent, isTrue);
    });

    test('gönderildikten sonra submit etkisizdir', () async {
      final states = <ResetPasswordState>[];
      final container = await sentContainer(states: states);
      await vmOf(container).submit();
      expect(sentTo(), hasLength(1));
      expect(states, isEmpty);
      expect(feedback.toasts, isEmpty);
    });

    test('çevrimdışı: TST-24, network; istek gitmez', () async {
      final container = containerOf();
      vmOf(container).setEmail(_email);
      connectivity.isOffline = true;
      await vmOf(container).submit();
      expect(feedback.toasts, [ToastId.tst24]);
      expect(sentTo(), isEmpty);
      expect(
        stateOf(container),
        const ResetPasswordState(
          email: _email,
          submitError: SubmitError.network,
        ),
      );

      // Bağlantı gelince aynı form gönderilir.
      connectivity.isOffline = false;
      await vmOf(container).submit();
      expect(stateOf(container).isSent, isTrue);
      expect(stateOf(container).submitError, isNull);
    });

    test('ağ hatası: TST-24, network; form açık kalır', () async {
      final container = containerOf();
      vmOf(container).setEmail(_email);
      auth.service.failNext(AuthError.network);
      await vmOf(container).submit();
      expect(feedback.toasts, [ToastId.tst24]);
      expect(
        stateOf(container),
        const ResetPasswordState(
          email: _email,
          submitError: SubmitError.network,
        ),
      );
      expect(logs, isEmpty);
    });

    test('sunucu adresi reddederse alan hatası (biçim / alan adı)', () async {
      final container = containerOf();
      vmOf(container).setEmail(_email);
      auth.service.failNext(AuthError.invalidEmail);
      await vmOf(container).submit();
      expect(
        stateOf(container),
        const ResetPasswordState(
          email: _email,
          errors: {ResetField.email: FormFieldError.invalidEmail},
        ),
      );

      auth.failNext(AuthError.domainNotAllowed);
      await vmOf(container).submit();
      expect(
        stateOf(container),
        const ResetPasswordState(
          email: _email,
          errors: {ResetField.email: FormFieldError.domainNotAllowed},
        ),
      );
      expect(feedback.toasts, isEmpty);
    });

    test('sunucu kısıtı (çok fazla istek): 60 sn bekleme + TST-X3; bekleme '
        'sürerken istek gitmez', () async {
      final container = containerOf();
      vmOf(container).setEmail(_email);
      auth.service.failNext(AuthError.tooManyRequests);
      await vmOf(container).submit();
      expect(feedback.toasts, [ToastId.tstX3]);
      expect(feedback.toastParams.single.s, '60');
      expect(
        stateOf(container),
        ResetPasswordState(
          email: _email,
          resendAvailableAt: kDefaultFakeNowUtc.add(_cooldown),
        ),
      );

      // 12,3 sn sonra: kalan 47,7 → "48".
      clock.advance(const Duration(milliseconds: 12300));
      await vmOf(container).submit();
      expect(sentTo(), hasLength(1));
      expect(feedback.toasts, [ToastId.tstX3, ToastId.tstX3]);
      expect(feedback.toastParams.last.s, '48');
      expect(stateOf(container).isSubmitting, isFalse);

      // Bekleme dolunca gönderilir.
      clock.advance(const Duration(seconds: 48));
      await vmOf(container).submit();
      expect(sentTo(), hasLength(2));
      expect(stateOf(container).isSent, isTrue);
    });

    for (final error in [
      AuthError.unknown,
      AuthError.operationNotAllowed,
      AuthError.emailAlreadyInUse,
      AuthError.weakPassword,
      AuthError.requiresRecentLogin,
      AuthError.sessionExpired,
      AuthError.invalidActionCode,
      AuthError.lockedOut,
      AuthError.resendCooldown,
      AuthError.emailNotVerified,
    ]) {
      test('${error.name}: unknown; günlüğe düşer, adres günlüğe yazılmaz; '
          'toast yok', () async {
        final container = containerOf();
        vmOf(container).setEmail(_email);
        auth.failNext(error);
        await vmOf(container).submit();
        expect(
          stateOf(container),
          const ResetPasswordState(
            email: _email,
            submitError: SubmitError.unknown,
          ),
        );
        expect(feedback.toasts, isEmpty);
        expect(logs.last, contains(error.name));
        expect(logs.join('\n'), isNot(contains(_email)));
      });
    }

    test('hatadan sonra yeniden gönderim hatayı temizler', () async {
      final states = <ResetPasswordState>[];
      final container = containerOf(states: states);
      vmOf(container).setEmail(_email);
      auth.failNext(AuthError.unknown);
      await vmOf(container).submit();
      states.clear();
      await vmOf(container).submit();
      expect(states.first.submitError, isNull);
      expect(states.first.isSubmitting, isTrue);
      expect(stateOf(container).isSent, isTrue);
    });

    test(
      'istek sürerken ekran kapanırsa state yazılmaz, hata fırlamaz',
      () async {
        final container = createContainer();
        final subscription = container.listen(
          resetPasswordViewModelProvider,
          (_, _) {},
        );
        final viewModel = vmOf(container)..setEmail(_email);
        final pending = viewModel.submit();
        subscription.close();
        container.dispose();
        await expectLater(pending, completes);
        expect(feedback.toasts, isEmpty);
      },
    );
  });

  group('AUT-04 · ResetPasswordViewModel · hesap sızdırılmaz', () {
    test('kayıtlı olmayan adres: kayıtlı adresle aynı sonuç', () async {
      final known = containerOf();
      vmOf(known).setEmail(_email);
      await vmOf(known).submit();

      final unknown = containerOf();
      vmOf(unknown).setEmail(_email);
      // SDK "kullanıcı yok" der; repository başarıya çevirir.
      auth.service.failNext(AuthError.invalidCredentials);
      await vmOf(unknown).submit();

      expect(stateOf(unknown), stateOf(known));
      expect(feedback.toasts, isEmpty);
      expect(logs, isEmpty);
    });

    for (final error in [
      AuthError.invalidCredentials,
      AuthError.userDisabled,
    ]) {
      test(
        '${error.name} cevabı da "gönderildi" görünümüne çevrilir',
        () async {
          final container = containerOf();
          vmOf(container).setEmail(_email);
          auth.failNext(error);
          await vmOf(container).submit();
          expect(
            stateOf(container),
            ResetPasswordState(
              email: _email,
              isSent: true,
              resendAvailableAt: kDefaultFakeNowUtc.add(_cooldown),
            ),
          );
          expect(feedback.toasts, isEmpty);
          expect(logs, isEmpty);
        },
      );
    }

    test(
      'yeniden gönderimde askıdaki hesap cevabı: başarıyla aynı (TST-03)',
      () async {
        final container = await sentContainer();
        clock.advance(_cooldown);
        auth.failNext(AuthError.userDisabled);
        await vmOf(container).resend();
        expect(feedback.toasts, [ToastId.tst03]);
        expect(
          stateOf(container).resendAvailableAt,
          clock.nowUtc().add(_cooldown),
        );
        expect(stateOf(container).submitError, isNull);
      },
    );
  });

  group('AUT-04 · ResetPasswordViewModel · yeniden gönderim', () {
    test('form gönderilmeden etkisizdir', () async {
      final states = <ResetPasswordState>[];
      final container = containerOf(states: states);
      vmOf(container).setEmail(_email);
      states.clear();
      await vmOf(container).resend();
      expect(states, isEmpty);
      expect(sentTo(), isEmpty);
      expect(feedback.toasts, isEmpty);
    });

    test(
      'bekleme sürerken: TST-X3 {s} (yukarı yuvarlanır), istek gitmez',
      () async {
        final states = <ResetPasswordState>[];
        final container = await sentContainer(states: states);

        await vmOf(container).resend();
        expect(feedback.toastParams.last.s, '60');

        clock.advance(const Duration(milliseconds: 500));
        await vmOf(container).resend();
        expect(feedback.toastParams.last.s, '60');

        clock.advance(const Duration(milliseconds: 58600));
        await vmOf(container).resend();
        expect(feedback.toastParams.last.s, '1');

        expect(feedback.toasts, [ToastId.tstX3, ToastId.tstX3, ToastId.tstX3]);
        expect(sentTo(), hasLength(1));
        expect(states, isEmpty);
      },
    );

    test('bekleme dolunca: istek gider, TST-03, bekleme yenilenir', () async {
      final states = <ResetPasswordState>[];
      final container = await sentContainer(states: states);
      clock.advance(_cooldown);
      expect(vmOf(container).remainingResend(clock.nowUtc()), Duration.zero);

      await vmOf(container).resend();

      expect(sentTo(), [_email, _email]);
      expect(feedback.toasts, [ToastId.tst03]);
      final first = kDefaultFakeNowUtc.add(_cooldown);
      final second = clock.nowUtc().add(_cooldown);
      expect(states, [
        ResetPasswordState(
          email: _email,
          isSent: true,
          isSubmitting: true,
          resendAvailableAt: first,
        ),
        ResetPasswordState(
          email: _email,
          isSent: true,
          resendAvailableAt: second,
        ),
      ]);
      expect(vmOf(container).remainingResend(clock.nowUtc()), _cooldown);

      // Yeni bekleme içinde yine TST-X3.
      await vmOf(container).resend();
      expect(feedback.toasts, [ToastId.tst03, ToastId.tstX3]);
      expect(sentTo(), hasLength(2));
    });

    test('art arda iki yeniden gönderim tek istek üretir', () async {
      final container = await sentContainer();
      clock.advance(_cooldown);
      final first = vmOf(container).resend();
      final second = vmOf(container).resend();
      await Future.wait([first, second]);
      expect(sentTo(), hasLength(2));
      expect(feedback.toasts, [ToastId.tst03]);
    });

    test(
      'çevrimdışı: TST-24, istek gitmez; görünüm ve bekleme değişmez',
      () async {
        final container = await sentContainer();
        clock.advance(_cooldown);
        connectivity.isOffline = true;
        await vmOf(container).resend();
        expect(feedback.toasts, [ToastId.tst24]);
        expect(sentTo(), hasLength(1));
        expect(stateOf(container).isSent, isTrue);
        expect(stateOf(container).submitError, SubmitError.network);
        expect(
          stateOf(container).resendAvailableAt,
          kDefaultFakeNowUtc.add(_cooldown),
        );
      },
    );

    test(
      'ağ hatası: TST-24; bekleme yenilenmez (hemen yeniden denenebilir)',
      () async {
        final container = await sentContainer();
        clock.advance(_cooldown);
        auth.service.failNext(AuthError.network);
        await vmOf(container).resend();
        expect(feedback.toasts, [ToastId.tst24]);
        expect(stateOf(container).isSubmitting, isFalse);
        expect(stateOf(container).submitError, SubmitError.network);

        await vmOf(container).resend();
        expect(feedback.toasts, [ToastId.tst24, ToastId.tst03]);
        expect(stateOf(container).submitError, isNull);
      },
    );

    test('sunucu kısıtı: bekleme yenilenir + TST-X3 "60"', () async {
      final container = await sentContainer();
      clock.advance(_cooldown);
      auth.service.failNext(AuthError.tooManyRequests);
      await vmOf(container).resend();
      expect(feedback.toasts, [ToastId.tstX3]);
      expect(feedback.toastParams.single.s, '60');
      expect(
        stateOf(container).resendAvailableAt,
        clock.nowUtc().add(_cooldown),
      );
      expect(stateOf(container).isSubmitting, isFalse);
    });

    for (final error in [
      AuthError.unknown,
      AuthError.invalidEmail,
      AuthError.domainNotAllowed,
    ]) {
      test('${error.name}: unknown (alan görünmediği için alan hatası '
          'yazılmaz); günlüğe düşer', () async {
        final container = await sentContainer();
        clock.advance(_cooldown);
        auth.failNext(error);
        await vmOf(container).resend();
        expect(stateOf(container).submitError, SubmitError.unknown);
        expect(stateOf(container).errors, isEmpty);
        expect(stateOf(container).isSent, isTrue);
        expect(stateOf(container).isSubmitting, isFalse);
        expect(feedback.toasts, isEmpty);
        expect(logs.last, contains(error.name));
      });
    }
  });
}
