// SHT-05 · JoinApplicationViewModel (kulüp başına aile): kulüp okuma, canlı
// üyelik, not (sınır, doğrulama), gönderim — onaylı kulüpte `apply`, onaysız
// kulüpte `joinInstant`, eski kayıtta yönetici onayı —, reddedilen yollar
// (TST-X1, TST-X4, TST-24, sunucu hataları) ve art arda tetik.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/join_application_state.dart';
import 'package:gu_kulupler/features/clubs/provider/join_application_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../../fakes/fake_auth_service.dart';
import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/test_container.dart';

const String _clubId = 'c03';
const String _email = 'ayse.demir@ogr.gumushane.edu.tr';
final UserModel _user = UserModelFixtures.ayse;
final String _uid = _user.uid;

FakeAuthService _auth() => GetIt.I<AuthService>() as FakeAuthService;
FakeClubRepository _clubs() => GetIt.I<ClubRepository>() as FakeClubRepository;
FakeMembershipRepository _memberships() =>
    GetIt.I<MembershipRepository>() as FakeMembershipRepository;
FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;
FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

/// TST-X4 tarih metni yerine geçen sahte biçim.
String _date(DateTime at) => 'gün:${at.toUtc().toIso8601String()}';

MembershipModel _membership(MembershipStatus status, {DateTime? retryAfter}) =>
    MembershipModel(
      clubId: _clubId,
      userId: _uid,
      applicant: MembershipApplicantModel.fromUser(_user),
      status: status,
      retryAfter: retryAfter,
    );

SessionState _session({MembershipModel? membership, bool withUser = true}) =>
    SessionState(
      status: AuthStatus.active,
      uid: _uid,
      user: withUser ? _user : null,
      onboardingSeen: true,
      memberships: {_clubId: ?membership},
    );

/// Kapsayıcıyı kurar, ViewModel'i canlı tutar ve ilk kulüp okumasını bekler.
Future<ProviderContainer> _container({
  SessionState? session,
  String? email = _email,
}) async {
  _auth().currentUser = AuthUserInfo(
    uid: _uid,
    email: email,
    emailVerified: true,
  );
  final container = createContainer(
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (_, _) => session ?? _session(),
      ),
    ],
  );
  addTearDown(
    container
        .listen(joinApplicationViewModelProvider(_clubId), (_, _) {})
        .close,
  );
  await pumpEventQueue();
  return container;
}

JoinApplicationViewModel _viewModel(ProviderContainer container) =>
    container.read(joinApplicationViewModelProvider(_clubId).notifier);

JoinApplicationState _state(ProviderContainer container) =>
    container.read(joinApplicationViewModelProvider(_clubId));

Future<JoinApplicationOutcome> _submit(ProviderContainer container) =>
    _viewModel(container).submit(formatDate: _date);

List<String> _writes() => [
  for (final call in _memberships().calls)
    if (call.method == 'apply' || call.method == 'joinInstant') call.method,
];

void main() {
  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
  });

  group('SHT-05 · JoinApplicationViewModel · başlangıç', () {
    test('ilk durum okuyor; üyelik oturumdan gelir', () {
      final pending = _membership(MembershipStatus.pending);
      _clubs().put(_clubId);
      final container = createContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (_, _) => _session(membership: pending),
          ),
        ],
      );
      addTearDown(
        container
            .listen(joinApplicationViewModelProvider(_clubId), (_, _) {})
            .close,
      );
      expect(
        _state(container),
        JoinApplicationState(membership: pending, isFetching: true),
      );
    });

    test('kulüp açılışta bir kez okunur', () async {
      final club = _clubs().put(_clubId, requireNote: true);
      final container = await _container();

      expect(_state(container), JoinApplicationState(club: club));
      expect(_clubs().callsTo('getClub'), hasLength(1));
      expect(_clubs().callsTo('getClub').single.args, [_clubId]);
    });

    test('okuma hatası `isError`; "Yeniden dene" kulübü getirir', () async {
      final club = _clubs().put(_clubId);
      _clubs().failNext(FirestoreError.unavailable);
      final container = await _container();
      expect(_state(container), const JoinApplicationState(isError: true));

      final retry = _viewModel(container).fetch();
      expect(_state(container).isFetching, isTrue);
      expect(_state(container).isError, isFalse);
      await retry;
      expect(_state(container), JoinApplicationState(club: club));
    });

    test('silinmiş / olmayan kulüp `isError`', () async {
      _clubs().put(_clubId, isDeleted: true);
      final container = await _container();
      expect(_state(container).club, isNull);
      expect(_state(container).isError, isTrue);
      expect(_state(container).isFetching, isFalse);
    });

    test('süren okuma varken `fetch` yok sayılır', () async {
      _clubs().put(_clubId);
      final container = await _container();
      final first = _viewModel(container).fetch();
      final second = _viewModel(container).fetch();
      await Future.wait([first, second]);
      // Açılış + tek yeniden okuma.
      expect(_clubs().callsTo('getClub'), hasLength(2));
    });

    test(
      'üyelik canlıdır: oturum değişince güncellenir, not korunur',
      () async {
        _clubs().put(_clubId);
        final container = await _container();
        _viewModel(container).setNote('Dağcılığa ilgim var.');
        final rejected = _membership(
          MembershipStatus.rejected,
          retryAfter: kDefaultFakeNowUtc.add(const Duration(days: 3)),
        );

        container.read(sessionViewModelProvider.notifier).state = _session(
          membership: rejected,
        );
        expect(_state(container).membership, rejected);
        expect(_state(container).note, 'Dağcılığa ilgim var.');
        expect(_state(container).isWaiting(kDefaultFakeNowUtc), isTrue);

        container.read(sessionViewModelProvider.notifier).state = _session();
        expect(_state(container).membership, isNull);
        expect(_state(container).isWaiting(kDefaultFakeNowUtc), isFalse);
      },
    );
  });

  group('SHT-05 · JoinApplicationViewModel · not', () {
    test('`setNote` notu yazar; form kirlenir', () async {
      _clubs().put(_clubId);
      final container = await _container();
      expect(_state(container).isDirty, isFalse);

      _viewModel(container).setNote('Merhaba');
      expect(_state(container).note, 'Merhaba');
      expect(_state(container).isDirty, isTrue);

      _viewModel(container).setNote('');
      expect(_state(container).isDirty, isFalse);
    });

    test('sınır `Limits.applicationNoteMax`: fazlası kesilir, yarım emoji '
        'bırakılmaz', () async {
      _clubs().put(_clubId);
      final container = await _container();
      const max = Limits.applicationNoteMax;

      _viewModel(container).setNote('a' * (max + 25));
      expect(_state(container).note, 'a' * max);

      _viewModel(container).setNote('${'a' * (max - 1)}😀b');
      expect(_state(container).note, 'a' * (max - 1));

      expect(JoinApplicationViewModel.clampNote('kısa'), 'kısa');
      expect(JoinApplicationViewModel.clampNote('a' * max), 'a' * max);
      expect(
        JoinApplicationViewModel.clampNote('${'a' * (max - 2)}😀'),
        '${'a' * (max - 2)}😀',
      );
    });

    test('`validate`: not zorunlu kulüpte boş ya da yalnızca boşluk → '
        'zorunlu; yazınca hata silinir', () async {
      _clubs().put(_clubId, requireNote: true);
      final container = await _container();

      expect(_viewModel(container).validate(), isFalse);
      expect(_state(container).errors, {
        JoinApplicationField.note: FormFieldError.required,
      });

      _viewModel(container).setNote('   ');
      expect(_state(container).errors, isEmpty);
      expect(_viewModel(container).validate(), isFalse);

      _viewModel(container).setNote('Katılmak istiyorum.');
      expect(_state(container).errors, isEmpty);
      expect(_viewModel(container).validate(), isTrue);
    });

    test('`validate`: not istemeyen kulüpte boş not geçerlidir', () async {
      _clubs().put(_clubId);
      final container = await _container();
      expect(_viewModel(container).validate(), isTrue);
      expect(_state(container).errors, isEmpty);
    });
  });

  group('SHT-05 · JoinApplicationViewModel · gönderim', () {
    test('onaylı kulüp: `apply` kırpılmış notla çağrılır → applied; toast '
        'yok', () async {
      _clubs().put(_clubId, requireNote: true);
      final container = await _container();
      _viewModel(container).setNote('  Tırmanışa yeni başladım.  ');

      final pending = _submit(container);
      expect(_state(container).isSubmitting, isTrue);
      expect(await pending, JoinApplicationOutcome.applied);

      expect(_writes(), ['apply']);
      expect(_memberships().applied.single, (
        clubId: _clubId,
        userId: _uid,
        email: _email,
        note: 'Tırmanışa yeni başladım.',
        status: MembershipStatus.pending,
      ));
      expect(_state(container).isSubmitting, isFalse);
      expect(_state(container).submitError, isNull);
      expect(_feedback().toasts, isEmpty);
      expect(_feedback().dialogs, isEmpty);
    });

    test('not zorunlu + boş not: invalid; yazım yok', () async {
      _clubs().put(_clubId, requireNote: true);
      final container = await _container();

      expect(await _submit(container), JoinApplicationOutcome.invalid);
      expect(_state(container).errors, {
        JoinApplicationField.note: FormFieldError.required,
      });
      expect(_writes(), isEmpty);
      expect(_feedback().toasts, isEmpty);
    });

    test('not istemeyen onaylı kulüp: boş notla başvurulur', () async {
      _clubs().put(_clubId);
      final container = await _container();
      expect(await _submit(container), JoinApplicationOutcome.applied);
      expect(_memberships().applied.single.note, '');
    });

    test(
      'onaysız kulüp: `joinInstant` → joined; not zorunluluğu aranmaz',
      () async {
        _clubs().put(_clubId, approvalRequired: false, requireNote: true);
        final container = await _container();
        expect(_state(container).isInstant, isTrue);
        expect(_state(container).requireNote, isFalse);

        expect(await _submit(container), JoinApplicationOutcome.joined);
        expect(_writes(), ['joinInstant']);
        expect(_memberships().applied.single.status, MembershipStatus.active);
        expect(_clubs().clubs[_clubId]!.memberCount, 1);
        // TST-34 çağırandadır.
        expect(_feedback().toasts, isEmpty);
      },
    );

    for (final status in JoinApplicationState.reviewStatuses) {
      test('onaysız kulüp + eski kayıt (${status.name}): `apply` ile yönetici '
          'onayına gider', () async {
        _clubs().put(_clubId, approvalRequired: false);
        final old = _membership(status);
        _memberships().put(old, email: _email);
        final container = await _container(session: _session(membership: old));
        expect(_state(container).isInstant, isFalse);

        expect(await _submit(container), JoinApplicationOutcome.applied);
        expect(_writes(), ['apply']);
        expect(_memberships().applied.single.status, MembershipStatus.pending);
      });
    }

    test('onaysız kulüp + oturumdaki üyelik eski: sunucu '
        '`reapplyNeedsReview` der, `apply` ile sürer', () async {
      _clubs().put(_clubId, approvalRequired: false);
      _memberships().put(_membership(MembershipStatus.rejected), email: _email);
      final container = await _container();
      expect(_state(container).isInstant, isTrue);

      expect(await _submit(container), JoinApplicationOutcome.applied);
      expect(_writes(), ['joinInstant', 'apply']);
      expect(_feedback().toasts, isEmpty);
    });

    test('TST-X1: kulüp başvuru almıyor → closed; form açık kalır', () async {
      _clubs().put(_clubId);
      final container = await _container();
      _clubs().put(_clubId, applicationsOpen: false);

      expect(await _submit(container), JoinApplicationOutcome.closed);
      expect(_feedback().toasts, [ToastId.tstX1]);
      expect(_state(container).isSubmitting, isFalse);
      expect(_state(container).submitError, isNull);
      expect(_memberships().applied, isEmpty);
    });

    test('TST-X4: oturumdaki bekleme süresi dolmadı → cooldown; yazım yok, '
        'tarih biçimlenir', () async {
      _clubs().put(_clubId);
      final until = kDefaultFakeNowUtc.add(const Duration(days: 5));
      final container = await _container(
        session: _session(
          membership: _membership(MembershipStatus.rejected, retryAfter: until),
        ),
      );

      expect(await _submit(container), JoinApplicationOutcome.cooldown);
      expect(_feedback().toasts, [ToastId.tstX4]);
      expect(_feedback().toastParams.single, ToastParams(date: _date(until)));
      expect(_writes(), isEmpty);
      expect(_state(container).isSubmitting, isFalse);
    });

    test('bekleme süresi geçmişse başvuru yazılır', () async {
      _clubs().put(_clubId);
      final old = _membership(
        MembershipStatus.rejected,
        retryAfter: kDefaultFakeNowUtc.subtract(const Duration(minutes: 1)),
      );
      _memberships().put(old, email: _email);
      final container = await _container(session: _session(membership: old));

      expect(await _submit(container), JoinApplicationOutcome.applied);
      expect(_feedback().toasts, isEmpty);
    });

    test('TST-X4: bekleme süresini sunucu bildirir (oturum eski) → cooldown, '
        'sunucunun tarihi', () async {
      _clubs().put(_clubId);
      final until = kDefaultFakeNowUtc.add(const Duration(days: 2));
      _memberships().put(
        _membership(MembershipStatus.removed, retryAfter: until),
        email: _email,
      );
      final container = await _container();

      expect(await _submit(container), JoinApplicationOutcome.cooldown);
      expect(_writes(), ['apply']);
      expect(_feedback().toasts, [ToastId.tstX4]);
      expect(_feedback().toastParams.single, ToastParams(date: _date(until)));
      expect(_state(container).isSubmitting, isFalse);
    });

    test('TST-24: çevrimdışıyken yazılmaz → offline', () async {
      _clubs().put(_clubId);
      final container = await _container();
      _connectivity().isOffline = true;

      expect(await _submit(container), JoinApplicationOutcome.offline);
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_writes(), isEmpty);
      expect(_state(container).isSubmitting, isFalse);
    });

    for (final error in [
      FirestoreError.offline,
      FirestoreError.unavailable,
      FirestoreError.timeout,
    ]) {
      test('TST-24: ağ hatası (${error.name}) → offline; form hatası '
          'yazılmaz', () async {
        _clubs().put(_clubId);
        final container = await _container();
        _memberships().failNext(error);

        expect(await _submit(container), JoinApplicationOutcome.offline);
        expect(_feedback().toasts, [ToastId.tst24]);
        expect(_state(container).submitError, isNull);
        expect(_state(container).isSubmitting, isFalse);
      });
    }

    test('sunucu hataları `submitError` olur; not değişince silinir', () async {
      const cases = {
        FirestoreError.permissionDenied: SubmitError.permission,
        FirestoreError.unauthenticated: SubmitError.permission,
        FirestoreError.alreadyExists: SubmitError.conflict,
        FirestoreError.unknown: SubmitError.unknown,
        FirestoreError.notFound: SubmitError.unknown,
      };
      _clubs().put(_clubId);
      final container = await _container();
      for (final MapEntry(key: error, value: expected) in cases.entries) {
        _memberships().failNext(error);
        expect(
          await _submit(container),
          JoinApplicationOutcome.failed,
          reason: error.name,
        );
        expect(_state(container).submitError, expected, reason: error.name);
        expect(_state(container).isSubmitting, isFalse);
      }
      expect(_feedback().toasts, isEmpty);

      _viewModel(container).setNote('yeniden');
      expect(_state(container).submitError, isNull);
    });

    test(
      'zaten bekleyen başvuru (`conflict`) → SubmitError.conflict',
      () async {
        _clubs().put(_clubId);
        _memberships().put(
          _membership(MembershipStatus.pending),
          email: _email,
        );
        final container = await _container();

        expect(await _submit(container), JoinApplicationOutcome.failed);
        expect(_state(container).submitError, SubmitError.conflict);
        expect(_memberships().applied, isEmpty);
      },
    );

    test('kulüp bu arada not zorunlu olduysa sunucu reddi alan hatasına '
        'döner', () async {
      _clubs().put(_clubId);
      final container = await _container();
      _clubs().put(_clubId, requireNote: true);

      expect(await _submit(container), JoinApplicationOutcome.invalid);
      expect(_state(container).errors, {
        JoinApplicationField.note: FormFieldError.required,
      });
      expect(_state(container).submitError, isNull);
      expect(_state(container).isSubmitting, isFalse);
    });

    test('oturumda profil ya da e-posta yoksa yazılmaz → failed', () async {
      _clubs().put(_clubId);
      final noUser = await _container(session: _session(withUser: false));
      expect(await _submit(noUser), JoinApplicationOutcome.failed);
      expect(_state(noUser).submitError, SubmitError.unknown);

      final noEmail = await _container(email: null);
      expect(await _submit(noEmail), JoinApplicationOutcome.failed);
      expect(_state(noEmail).submitError, SubmitError.unknown);
      expect(_writes(), isEmpty);
    });

    test('kulüp yüklenmeden gönderim yok sayılır', () async {
      _clubs().failNext(FirestoreError.unavailable);
      final container = await _container();
      expect(await _submit(container), JoinApplicationOutcome.ignored);
      expect(_writes(), isEmpty);
    });

    test('art arda tetik: süren gönderim varken ikincisi yok sayılır; o '
        'sırada yazılan not gönderimi değiştirmez', () async {
      _clubs().put(_clubId);
      final container = await _container();
      _viewModel(container).setNote('ilk');

      final first = _submit(container);
      final second = _submit(container);
      _viewModel(container).setNote('araya giren');
      expect(_state(container).note, 'araya giren');
      expect(_state(container).isSubmitting, isTrue);

      expect(await second, JoinApplicationOutcome.ignored);
      expect(await first, JoinApplicationOutcome.applied);
      expect(_writes(), ['apply']);
      expect(_memberships().applied.single.note, 'ilk');
    });
  });
}
