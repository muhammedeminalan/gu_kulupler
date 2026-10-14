// SET-05 · SupportViewModel: SSS araması (Türkçe harf katlama) ve tek açık
// soru, form doğrulaması (konu + kırpılmış mesaj), mesaj sınırı (500),
// ek (en çok 1; SHT-16 kaldır; seçici hataları), gönderim (TST-23
// `#GU-XXXXXX`, başarı kartı, "Yeni talep") ve hata eşlemesi (TST-24,
// TST-X18, form altı hata).
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/settings/provider/support_state.dart';
import 'package:gu_kulupler/features/settings/provider/support_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_auth_service.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_image_picker_service.dart';
import '../../../fakes/fake_support_repository.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/test_container.dart';

const String _uid = 'u_mehmet';
const String _email = 'mehmet.kaya@ogr.gumushane.edu.tr';

FakeSupportRepository _support() =>
    GetIt.I<SupportRepository>() as FakeSupportRepository;

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeImagePickerService _picker() =>
    GetIt.I<ImagePickerService>() as FakeImagePickerService;

void _signIn() {
  final user = UserModelFixtures.byId(_uid);
  (GetIt.I<UserRepository>() as FakeUserRepository)
    ..users[_uid] = user
    ..accounts[_uid] = const UserAccountModel(
      email: _email,
      emailLower: _email,
    );
  (GetIt.I<AuthService>() as FakeAuthService).currentUser = AuthUserInfo(
    uid: _uid,
    email: _email,
    emailVerified: true,
    displayName: user.name,
  );
}

Future<ProviderContainer> _container() async {
  final container = createContainer();
  addTearDown(container.listen(sessionViewModelProvider, (_, _) {}).close);
  await pumpEventQueue();
  expect(container.read(sessionViewModelProvider).status, AuthStatus.active);
  addTearDown(container.listen(supportViewModelProvider, (_, _) {}).close);
  return container;
}

SupportViewModel _vm(ProviderContainer c) =>
    c.read(supportViewModelProvider.notifier);

SupportState _state(ProviderContainer c) => c.read(supportViewModelProvider);

/// Konu + mesaj dolu form.
void _fill(ProviderContainer c, {String message = '  Bildirim gelmiyor.  '}) {
  _vm(c)
    ..setSubject(SupportSubject.bug)
    ..setMessage(message);
}

void main() {
  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    _signIn();
    (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
            .values[AppPreferenceKeys.photoAccessExplained] =
        true;
  });

  group('SET-05 · SupportViewModel · SSS', () {
    test('arama Türkçe harf katlamasıyla soru + cevapta arar; boş arama '
        'hepsini gösterir', () async {
      final c = await _container();
      _vm(c).setFaqQuery('İZNİ');
      final state = _state(c);

      expect(
        state.matchesFaq('Bildirim alamıyorum.', 'Sistem izninin açık'),
        isTrue,
      );
      expect(state.matchesFaq('Hesabımı nasıl silerim?', 'Ayarlar'), isFalse);
      _vm(c).setFaqQuery('');
      expect(_state(c).matchesFaq('x', 'y'), isTrue);
    });

    test('tek açık soru: başka soru açılınca önceki kapanır, ikinci dokunma '
        'kapatır', () async {
      final c = await _container();
      _vm(c).toggleFaq(3);
      expect(_state(c).expandedFaq, 3);
      _vm(c).toggleFaq(5);
      expect(_state(c).expandedFaq, 5);
      _vm(c).toggleFaq(5);
      expect(_state(c).expandedFaq, isNull);
    });
  });

  group('SET-05 · SupportViewModel · form', () {
    test('boş form: konu ve mesaj zorunlu, hiçbir şey gönderilmez', () async {
      final c = await _container();
      _vm(c).setMessage('   ');

      expect(await _vm(c).submit(), SupportSubmitOutcome.invalid);
      expect(_state(c).errors, {
        SupportField.subject: FormFieldError.required,
        SupportField.message: FormFieldError.required,
      });
      expect(_support().callsTo('createTicket'), isEmpty);
    });

    test('alan düzenlemesi kendi hatasını temizler; form kirli', () async {
      final c = await _container();
      await _vm(c).submit();
      _vm(c).setSubject(SupportSubject.club);

      expect(_state(c).errors.keys, [SupportField.message]);
      expect(_state(c).isDirty, isTrue);
    });

    test('mesaj Limits.supportMessageMax (500) karakterde kesilir', () async {
      final c = await _container();
      _vm(c).setMessage('a' * 600);
      expect(_state(c).message.length, Limits.supportMessageMax);
    });

    test('ek (SHT-16 galeri): en çok 1 — yeni seçim öncekinin yerine geçer; '
        'kaldır', () async {
      final c = await _container();
      await _vm(c).attach(MediaSource.gallery);
      final first = _state(c).attachment;
      final second = PickedImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'image/jpeg',
        width: 10,
        height: 10,
      );
      _picker().nextPick = second;
      await _vm(c).attach(MediaSource.gallery);

      expect(first, isNotNull);
      expect(_state(c).attachment, same(second));
      _vm(c).removeAttachment();
      expect(_state(c).attachment, isNull);
      expect(_state(c).isDirty, isFalse);
    });

    test(
      'seçici hatası ek alanına yazılır; vazgeçme durumu değiştirmez',
      () async {
        final c = await _container();
        _picker().nextError = ImagePickError.tooLarge;
        await _vm(c).attach(MediaSource.gallery);
        expect(
          _state(c).errors[SupportField.attachment],
          FormFieldError.limitExceeded,
        );

        _picker().nextPick = null;
        await _vm(c).attach(MediaSource.gallery);
        expect(_state(c).attachment, isNull);
      },
    );
  });

  group('SET-05 · SupportViewModel · gönderim (TST-23)', () {
    test('kırpılmış mesaj + ek gönderilir; TST-23 `#GU-XXXXXX`, başarı '
        'kartı; form kilitlenir; "Yeni talep" formu sıfırlar', () async {
      final c = await _container();
      _vm(c).toggleFaq(2);
      _fill(c);
      await _vm(c).attach(MediaSource.gallery);

      expect(await _vm(c).submit(), SupportSubmitOutcome.sent);

      final call = _support().callsTo('createTicket').single;
      expect(call.args.take(3), [
        _uid,
        SupportSubject.bug,
        'Bildirim gelmiyor.',
      ]);
      final upload = _support().attachments.single;
      expect(upload.uploaderId, _uid);
      expect(upload.attachment.bytes, same(kFakeJpeg.bytes));
      expect(upload.attachment.contentType, kFakeJpeg.contentType);
      expect(_feedback().toasts, [ToastId.tst23]);
      expect(_feedback().toastParams.single.no, '#GU-AAAAAB');
      expect(
        RegExp(
          FirestoreIds.supportTicketNoPattern,
        ).hasMatch(_state(c).ticketNo!),
        isTrue,
      );
      expect(_state(c).displayTicketNo, '#GU-AAAAAB');
      expect(_state(c).isSent, isTrue);
      expect(_state(c).isDirty, isFalse);

      _vm(c).setMessage('değişmez');
      expect(_state(c).message, '  Bildirim gelmiyor.  ');
      expect(await _vm(c).submit(), SupportSubmitOutcome.ignored);

      _vm(c).newRequest();
      expect(_state(c), const SupportState(expandedFaq: 2));
    });

    test('çevrimdışı: TST-24, hiçbir şey gönderilmez', () async {
      final c = await _container();
      (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
          true;
      _fill(c);

      expect(await _vm(c).submit(), SupportSubmitOutcome.offline);
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_support().callsTo('createTicket'), isEmpty);
    });

    test('hata eşlemesi: ağ (yükleme / belge) → TST-24, yetki → TST-X18, '
        'diğerleri → form altı hata; form yerinde kalır', () async {
      final c = await _container();
      _fill(c);
      await _vm(c).attach(MediaSource.gallery);

      _support().failNext(StorageError.timeout);
      expect(await _vm(c).submit(), SupportSubmitOutcome.failed);
      _support().failNext(FirestoreError.unavailable);
      await _vm(c).submit();
      _support().failNext(FirestoreError.permissionDenied);
      await _vm(c).submit();
      expect(_feedback().toasts, [
        ToastId.tst24,
        ToastId.tst24,
        ToastId.tstX18,
      ]);
      expect(_state(c).submitError, isNull);

      _support().failNext(StorageError.unauthorized);
      await _vm(c).submit();
      expect(_state(c).submitError, SupportError.unknown);
      expect(_feedback().toasts, hasLength(3));
      expect(_state(c).isSubmitting, isFalse);
      expect(_state(c).ticketNo, isNull);
      expect(_state(c).subject, SupportSubject.bug);
      expect(_state(c).attachment, isNotNull);

      _vm(c).setMessage('Yeni metin');
      expect(_state(c).submitError, isNull);
    });
  });
}
