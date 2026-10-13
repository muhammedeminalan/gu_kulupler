// CLB-04 / CLB-05 · ClubApplicationViewModel (kulüp başına aile): açılış
// okuması (kulüp + `private/contact` notu + bildirim izni), canlı üyelik,
// not düzenleme (TST-07), istek iptali (DLG-07 → TST-40), yeniden başvuru
// (TST-X1, TST-X4, SHT-05 yolu, onaysız kulüpte anında katılım → TST-34),
// bildirim izni (DLG-03 → TST-19), reddedilen yollar (TST-24, TST-X18,
// sunucu hataları) ve art arda tetik (PLAN §12.6, CD-137).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_auth_service.dart';
import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/fake_permission_service.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/club_model_fixtures.dart';
import '../../../fixtures/membership_model_fixtures.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/test_container.dart';

const String _clubId = 'c06';
const String _email = 'mehmet.kaya@ogr.gumushane.edu.tr';
const String _note = 'Gitar çalıyorum, jam seanslarına katılmak istiyorum.';
final UserModel _user = UserModelFixtures.byId('u_mehmet');
final String _uid = _user.uid;

/// `c06` — onay isteyen, başvuruya açık, not zorunlu olmayan kulüp.
final ClubModel _club = ClubModelFixtures.byId(_clubId);

/// `c06_u_mehmet` — bekleyen başvuru.
final MembershipModel _pending = MembershipModelFixtures.byId('c06_u_mehmet');

FakeAuthService _auth() => GetIt.I<AuthService>() as FakeAuthService;
FakeClubRepository _clubs() => GetIt.I<ClubRepository>() as FakeClubRepository;
FakeMembershipRepository _memberships() =>
    GetIt.I<MembershipRepository>() as FakeMembershipRepository;
FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;
FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;
FakePermissionService _permissions() =>
    GetIt.I<PermissionService>() as FakePermissionService;
FakeAppPreferencesStore _store() =>
    GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;

/// TST-X4 tarih metni yerine geçen sahte biçim.
String _date(DateTime at) => 'gün:${at.toUtc().toIso8601String()}';

MembershipModel _with(MembershipStatus status, {DateTime? retryAfter}) =>
    _pending.copyWith(
      status: status,
      retryAfter: retryAfter,
      clearRetryAfter: retryAfter == null,
    );

SessionState _session({
  MembershipModel? membership,
  bool withUser = true,
  bool signedIn = true,
}) => SessionState(
  status: signedIn ? AuthStatus.active : AuthStatus.signedOut,
  uid: signedIn ? _uid : null,
  user: withUser ? _user : null,
  onboardingSeen: true,
  memberships: {_clubId: ?membership},
);

/// Kulübü ve (verilirse) üyeliği + iletişim belgesini sahte depolara yazar.
void _seed({
  ClubModel? club,
  MembershipModel? membership,
  String note = _note,
}) {
  _clubs().clubs[_clubId] = club ?? _club;
  if (membership != null) {
    _memberships().put(membership, email: _email, note: note);
  }
}

/// Kapsayıcıyı kurar, ViewModel'i canlı tutar ve açılış okumasını bekler.
/// [states] verilirse her state değişimi sırayla eklenir.
Future<ProviderContainer> _container({
  SessionState? session,
  String? email = _email,
  List<ClubApplicationState>? states,
}) async {
  _auth().currentUser = AuthUserInfo(
    uid: _uid,
    email: email,
    emailVerified: true,
  );
  final container = createContainer(
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (_, _) => session ?? _session(membership: _pending),
      ),
    ],
  );
  addTearDown(
    container
        .listen(
          clubApplicationViewModelProvider(_clubId),
          (_, next) => states?.add(next),
        )
        .close,
  );
  await pumpEventQueue();
  states?.clear();
  _memberships().resetFake();
  _clubs().resetFake();
  return container;
}

ClubApplicationViewModel _viewModel(ProviderContainer container) =>
    container.read(clubApplicationViewModelProvider(_clubId).notifier);

ClubApplicationState _state(ProviderContainer container) =>
    container.read(clubApplicationViewModelProvider(_clubId));

void _setSession(ProviderContainer container, SessionState session) =>
    container.read(sessionViewModelProvider.notifier).state = session;

/// Depoya yazan çağrılar (okumalar hariç), sırasıyla.
List<String> _writes() => [
  for (final call in _memberships().calls)
    if (const {
      'apply',
      'joinInstant',
      'cancelApplication',
      'updateApplicationNote',
      'leave',
    }.contains(call.method))
      call.method,
];

void main() {
  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
  });

  group('CLB-05 · ClubApplicationViewModel · başlangıç', () {
    test('ilk durum okuyor; üyelik oturumdan gelir', () {
      _seed(membership: _pending);
      final container = createContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (_, _) => _session(membership: _pending),
          ),
        ],
      );
      addTearDown(
        container
            .listen(clubApplicationViewModelProvider(_clubId), (_, _) {})
            .close,
      );
      expect(
        _state(container),
        ClubApplicationState(membership: _pending, isFetching: true),
      );
    });

    test('kulüp, not ve bildirim izni açılışta bir kez okunur', () async {
      _seed(membership: _pending);
      _auth().currentUser = const AuthUserInfo(
        uid: 'u_mehmet',
        email: _email,
        emailVerified: true,
      );
      final container = createContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (_, _) => _session(membership: _pending),
          ),
        ],
      );
      addTearDown(
        container
            .listen(clubApplicationViewModelProvider(_clubId), (_, _) {})
            .close,
      );
      await pumpEventQueue();

      expect(
        _state(container),
        ClubApplicationState(
          club: _club,
          membership: _pending,
          note: _note,
          savedNote: _note,
          // İzin verilmemiş (varsayılan): bildirim kartı gösterilir.
          showNotificationPrompt: true,
        ),
      );
      expect(_clubs().callsTo('getClub').single.args, [_clubId]);
      expect(_memberships().callsTo('readContact').single.args, [
        _clubId,
        _uid,
      ]);
      expect(_permissions().callsTo('isGranted').single.args, [
        Permission.notification,
      ]);
      expect(_permissions().requested, isEmpty);
      expect(_feedback().calls, isEmpty);
    });

    test('bildirim izni varsa kart gösterilmez', () async {
      _seed(membership: _pending);
      _permissions().results[Permission.notification] =
          PermissionStatus.granted;
      final container = await _container();
      expect(_state(container).showNotificationPrompt, isFalse);
    });

    test('iletişim belgesi yoksa not boştur', () async {
      _seed();
      final container = await _container(session: _session());
      expect(
        _state(container),
        ClubApplicationState(club: _club, showNotificationPrompt: true),
      );
      expect(_state(container).phase, ApplicationPhase.none);
    });

    test('kulüp yok / silinmiş → isNotFound', () async {
      final container = await _container();
      expect(
        _state(container),
        ClubApplicationState(membership: _pending, isNotFound: true),
      );

      _clubs().clubs[_clubId] = _club.copyWith(isDeleted: true);
      await _viewModel(container).fetch();
      expect(_state(container).isNotFound, isTrue);
      expect(_state(container).club, isNull);
    });

    test('kulüp okunamadı → isError; "Yeniden dene" düzeltir', () async {
      _seed(membership: _pending);
      _clubs().failNext(FirestoreError.unavailable);
      final states = <ClubApplicationState>[];
      final container = await _container(states: states);
      expect(
        _state(container),
        ClubApplicationState(membership: _pending, isError: true),
      );

      await _viewModel(container).fetch();
      expect(states.first.isFetching, isTrue);
      expect(states.first.isError, isFalse);
      expect(_state(container).isError, isFalse);
      expect(_state(container).isFetching, isFalse);
      expect(_state(container).club, _club);
      expect(_state(container).savedNote, _note);
    });

    test('not okunamadı → isError (boş notla düzenleme açılmaz)', () async {
      _seed(membership: _pending);
      _memberships().failNext(FirestoreError.unavailable);
      final container = await _container();
      expect(_state(container).isError, isTrue);
      expect(_state(container).club, isNull);
      expect(_state(container).savedNote, '');
    });

    test('oturum yoksa okuma yapılmaz → isError', () async {
      _seed(membership: _pending);
      final container = createContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (_, _) => _session(signedIn: false, withUser: false),
          ),
        ],
      );
      addTearDown(
        container
            .listen(clubApplicationViewModelProvider(_clubId), (_, _) {})
            .close,
      );
      await pumpEventQueue();
      expect(_state(container), const ClubApplicationState(isError: true));
      expect(_clubs().calls, isEmpty);
      expect(_memberships().calls, isEmpty);
    });

    test('yeniden okuma kullanıcının taslağını ezmez', () async {
      _seed(membership: _pending);
      final container = await _container();
      _viewModel(container).setNote('taslak');
      _memberships().contacts[_pending.id] = _memberships()
          .contacts[_pending.id]!
          .copyWith(note: 'sunucuda değişti');

      await _viewModel(container).fetch();
      expect(_state(container).note, 'taslak');
      expect(_state(container).savedNote, 'sunucuda değişti');
      expect(_state(container).isDirty, isTrue);
    });

    test('art arda okuma: yalnızca son okumanın sonucu yazılır', () async {
      _seed(membership: _pending);
      final states = <ClubApplicationState>[];
      final container = await _container(states: states);

      // İlk okuma hata ile, ikincisi başarıyla biter; ikisi aynı anda sürer.
      _clubs().failNext(FirestoreError.unavailable);
      final first = _viewModel(container).fetch();
      final second = _viewModel(container).fetch();
      await Future.wait([first, second]);

      expect(_state(container).isError, isFalse);
      expect(_state(container).club, _club);
      expect(states.where((state) => state.isError), isEmpty);
    });
  });

  group('CLB-05 · ClubApplicationViewModel · canlı üyelik', () {
    test('karar gelince üyelik ve evre güncellenir (not okunmaz)', () async {
      _seed(membership: _pending);
      final container = await _container();
      expect(_state(container).phase, ApplicationPhase.pending);

      final rejected = _with(MembershipStatus.rejected);
      _setSession(container, _session(membership: rejected));
      await pumpEventQueue();
      expect(_state(container).membership, rejected);
      expect(_state(container).phase, ApplicationPhase.rejected);

      _setSession(
        container,
        _session(membership: _with(MembershipStatus.active)),
      );
      expect(_state(container).phase, ApplicationPhase.approved);
      expect(_memberships().callsTo('readContact'), isEmpty);
    });

    test('üyelik kalkınca (belge yok) evre "yok" olur', () async {
      _seed(membership: _pending);
      final container = await _container();
      _setSession(container, _session());
      expect(_state(container).membership, isNull);
      expect(_state(container).phase, ApplicationPhase.none);
    });

    test("yeni başvuru (pending'e geçiş): not yeniden okunur", () async {
      _seed(membership: _with(MembershipStatus.rejected), note: 'eski not');
      final container = await _container(
        session: _session(membership: _with(MembershipStatus.rejected)),
      );
      expect(_state(container).savedNote, 'eski not');

      _memberships().contacts[_pending.id] = _memberships()
          .contacts[_pending.id]!
          .copyWith(note: 'yeni başvuru notu');
      _setSession(container, _session(membership: _pending));
      await pumpEventQueue();

      expect(_state(container).phase, ApplicationPhase.pending);
      expect(_state(container).savedNote, 'yeni başvuru notu');
      expect(_state(container).note, 'yeni başvuru notu');
      expect(_memberships().callsTo('readContact'), hasLength(1));
    });

    test('oturumun başka alanı değişince state değişmez', () async {
      _seed(membership: _pending);
      final states = <ClubApplicationState>[];
      final container = await _container(states: states);
      _setSession(
        container,
        _session(membership: _pending).copyWith(isSuperAdmin: true),
      );
      await pumpEventQueue();
      expect(states, isEmpty);
    });
  });

  group('CLB-05 · ClubApplicationViewModel · not (TST-07)', () {
    test('setNote: not yazılır, alan ve sunucu hatası silinir', () async {
      _seed(club: _club.copyWith(requireNote: true), membership: _pending);
      final container = await _container();
      final viewModel = _viewModel(container)..setNote('');
      expect(viewModel.validate(), isFalse);
      expect(_state(container).errors, {
        ApplicationField.note: FormFieldError.required,
      });

      viewModel.setNote('Yeni not');
      expect(_state(container).note, 'Yeni not');
      expect(_state(container).errors, isEmpty);
      expect(_state(container).isDirty, isTrue);
    });

    test('validate: not zorunlu değilse boş not geçerlidir', () async {
      _seed(membership: _pending);
      final container = await _container();
      final viewModel = _viewModel(container)..setNote('   ');
      expect(viewModel.validate(), isTrue);
      expect(_state(container).errors, isEmpty);
    });

    test(
      "saveNote: kırpılmış not private/contact'a yazılır → TST-07",
      () async {
        _seed(membership: _pending);
        final states = <ClubApplicationState>[];
        final container = await _container(states: states);
        _viewModel(container).setNote('  Bas gitar da çalıyorum.  ');
        states.clear();

        await _viewModel(container).saveNote();

        expect(_memberships().noteUpdates, [
          (clubId: _clubId, userId: _uid, note: 'Bas gitar da çalıyorum.'),
        ]);
        expect(
          _memberships().contacts[_pending.id]!.note,
          'Bas gitar da çalıyorum.',
        );
        expect(states.map((state) => state.isSaving), [true, false]);
        expect(_state(container).savedNote, 'Bas gitar da çalıyorum.');
        expect(_state(container).isDirty, isFalse);
        expect(_state(container).canSaveNote, isFalse);
        expect(_feedback().toasts, [ToastId.tst07]);
      },
    );

    test('saveNote: not boşaltılabilir (kulüp not istemiyorsa)', () async {
      _seed(membership: _pending);
      final container = await _container();
      _viewModel(container).setNote('');
      await _viewModel(container).saveNote();
      expect(_memberships().noteUpdates.single.note, '');
      expect(_state(container).savedNote, '');
      expect(_feedback().toasts, [ToastId.tst07]);
    });

    test('saveNote: not değişmediyse, sınırı aşıyorsa ya da başvuru '
        'beklemiyorsa yazılmaz', () async {
      _seed(membership: _pending);
      final container = await _container();
      final viewModel = _viewModel(container);

      await viewModel.saveNote();
      viewModel.setNote('$_note  ');
      await viewModel.saveNote();
      viewModel.setNote('a' * (Limits.applicationNoteMax + 1));
      await viewModel.saveNote();

      viewModel.setNote('yeni');
      _setSession(
        container,
        _session(membership: _with(MembershipStatus.active)),
      );
      await viewModel.saveNote();

      expect(_writes(), isEmpty);
      expect(_feedback().toasts, isEmpty);
      expect(_state(container).isSaving, isFalse);
    });

    test('saveNote: kulüp not istiyorsa boş not alan hatasıdır', () async {
      _seed(club: _club.copyWith(requireNote: true), membership: _pending);
      final container = await _container();
      _viewModel(container).setNote('  ');
      await _viewModel(container).saveNote();
      expect(_state(container).errors, {
        ApplicationField.note: FormFieldError.required,
      });
      expect(_writes(), isEmpty);
      expect(_feedback().toasts, isEmpty);
    });

    test('saveNote: çevrimdışı → TST-24, yazılmaz', () async {
      _seed(membership: _pending);
      final container = await _container();
      _viewModel(container).setNote('yeni');
      _connectivity().isOffline = true;
      await _viewModel(container).saveNote();
      expect(_writes(), isEmpty);
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_state(container).savedNote, _note);
      expect(_state(container).isSaving, isFalse);
    });

    for (final (error, toast, submitError) in [
      (FirestoreError.unavailable, ToastId.tst24, null),
      (FirestoreError.timeout, ToastId.tst24, null),
      (FirestoreError.permissionDenied, ToastId.tstX18, null),
      (FirestoreError.unknown, null, SubmitError.unknown),
      (FirestoreError.conflict, null, SubmitError.conflict),
    ]) {
      test('saveNote: sunucu ${error.name} → '
          '${toast?.designId ?? 'submitError ${submitError?.name}'}', () async {
        _seed(membership: _pending);
        final container = await _container();
        _viewModel(container).setNote('yeni');
        _memberships().failNext(error);

        await _viewModel(container).saveNote();

        expect(_feedback().toasts, [?toast]);
        expect(_state(container).submitError, submitError);
        expect(_state(container).isSaving, isFalse);
        expect(_state(container).savedNote, _note);
        expect(_state(container).note, 'yeni');
        expect(_memberships().noteUpdates, isEmpty);
      });
    }

    test(
      'saveNote: başvuru bu arada karara bağlandı (conflict) → sessiz',
      () async {
        _seed(membership: _pending);
        final container = await _container();
        _viewModel(container).setNote('yeni');
        // Sunucuda onaylandı; oturum akışı henüz yetişmedi.
        _memberships().memberships[_pending.id] = _with(
          MembershipStatus.active,
        );

        await _viewModel(container).saveNote();
        expect(_feedback().toasts, isEmpty);
        expect(_state(container).submitError, SubmitError.conflict);
        expect(_memberships().noteUpdates, isEmpty);
      },
    );

    test(
      'saveNote: kulüp bu arada not zorunluluğu getirdi → alan hatası',
      () async {
        _seed(membership: _pending);
        final container = await _container();
        _viewModel(container).setNote('');
        _clubs().clubs[_clubId] = _club.copyWith(requireNote: true);

        await _viewModel(container).saveNote();
        expect(_state(container).errors, {
          ApplicationField.note: FormFieldError.required,
        });
        expect(_feedback().toasts, isEmpty);
        expect(_state(container).isSaving, isFalse);
      },
    );

    test('saveNote: kulüp silinmiş (notFound) → isNotFound', () async {
      _seed(membership: _pending);
      final container = await _container();
      _viewModel(container).setNote('yeni');
      _clubs().clubs.remove(_clubId);

      await _viewModel(container).saveNote();
      expect(_state(container).isNotFound, isTrue);
      expect(_feedback().toasts, isEmpty);
    });

    test('saveNote: art arda dokunuş tek yazım; kayıt sürerken not '
        'değişmez', () async {
      _seed(membership: _pending);
      final container = await _container();
      final viewModel = _viewModel(container)..setNote('yeni');

      final first = viewModel.saveNote();
      expect(_state(container).isSaving, isTrue);
      final second = viewModel.saveNote();
      viewModel.setNote('kayıt sürerken yazıldı');
      await Future.wait([first, second]);

      expect(_memberships().noteUpdates, hasLength(1));
      expect(_state(container).note, 'yeni');
      expect(_feedback().toasts, [ToastId.tst07]);
    });
  });

  group('CLB-05 · ClubApplicationViewModel · iptal (DLG-07, TST-40)', () {
    test('onaylanınca başvuru geri çekilir → TST-40', () async {
      _seed(membership: _pending);
      final states = <ClubApplicationState>[];
      final container = await _container(states: states);
      _feedback().nextDialogResult = true;

      expect(await _viewModel(container).cancel(), isTrue);

      expect(_feedback().dialogs, [DialogId.dlg07]);
      expect(_feedback().dialogParams.single, {
        DialogParamKeys.club: _club.name,
      });
      expect(_memberships().callsTo('cancelApplication').single.args, [
        _clubId,
        _uid,
      ]);
      expect(
        _memberships().memberships[_pending.id]!.status,
        MembershipStatus.cancelled,
      );
      expect(states.map((state) => state.isCancelling), [true, false]);
      expect(_feedback().toasts, [ToastId.tst40]);
    });

    test('"Vazgeç" / kapatma: hiçbir şey yazılmaz', () async {
      _seed(membership: _pending);
      final container = await _container();
      for (final answer in <bool?>[false, null]) {
        _feedback().nextDialogResult = answer;
        expect(await _viewModel(container).cancel(), isFalse);
      }
      expect(_feedback().dialogs, [DialogId.dlg07, DialogId.dlg07]);
      expect(_writes(), isEmpty);
      expect(_feedback().toasts, isEmpty);
    });

    test('onaydan sonra çevrimdışı → TST-24, yazılmaz', () async {
      _seed(membership: _pending);
      final container = await _container();
      _feedback().nextDialogResult = true;
      _connectivity().isOffline = true;

      expect(await _viewModel(container).cancel(), isFalse);
      expect(_feedback().dialogs, [DialogId.dlg07]);
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_writes(), isEmpty);
    });

    test(
      'başvuru beklemiyorsa ya da kulüp yüklenmediyse dialog açılmaz',
      () async {
        _seed(membership: _with(MembershipStatus.rejected));
        final rejected = await _container(
          session: _session(membership: _with(MembershipStatus.rejected)),
        );
        expect(await _viewModel(rejected).cancel(), isFalse);

        _clubs().clubs.clear();
        final missing = await _container();
        expect(await _viewModel(missing).cancel(), isFalse);

        expect(_feedback().dialogs, isEmpty);
        expect(_writes(), isEmpty);
      },
    );

    for (final (error, toast, submitError) in [
      (FirestoreError.unavailable, ToastId.tst24, null),
      (FirestoreError.permissionDenied, ToastId.tstX18, null),
      (FirestoreError.unknown, null, SubmitError.unknown),
    ]) {
      test('sunucu ${error.name} → '
          '${toast?.designId ?? 'submitError ${submitError?.name}'}', () async {
        _seed(membership: _pending);
        final container = await _container();
        _feedback().nextDialogResult = true;
        _memberships().failNext(error);

        expect(await _viewModel(container).cancel(), isFalse);
        expect(_feedback().toasts, [?toast]);
        expect(_state(container).submitError, submitError);
        expect(_state(container).isCancelling, isFalse);
        expect(
          _memberships().memberships[_pending.id]!.status,
          MembershipStatus.pending,
        );
      });
    }

    test('başvuru bu arada karara bağlandı (conflict) → sessiz', () async {
      _seed(membership: _pending);
      final container = await _container();
      _memberships().memberships[_pending.id] = _with(MembershipStatus.active);
      _feedback().nextDialogResult = true;

      expect(await _viewModel(container).cancel(), isFalse);
      expect(_feedback().toasts, isEmpty);
      expect(_state(container).submitError, SubmitError.conflict);
    });

    test('art arda dokunuş: tek dialog, tek yazım', () async {
      _seed(membership: _pending);
      final container = await _container();
      _feedback().dialogResults[DialogId.dlg07] = true;

      final results = await Future.wait([
        _viewModel(container).cancel(),
        _viewModel(container).cancel(),
      ]);
      expect(results, [true, false]);
      expect(_feedback().dialogs, [DialogId.dlg07]);
      expect(_writes(), ['cancelApplication']);
      expect(_feedback().toasts, [ToastId.tst40]);
    });
  });

  group('CLB-05 · ClubApplicationViewModel · yeniden başvuru '
      '(TST-X1, TST-X4, TST-34)', () {
    var openedClub = 0;
    setUp(() => openedClub = 0);

    Future<ReapplyOutcome> reapply(ProviderContainer container) => _viewModel(
      container,
    ).reapply(formatDate: _date, onOpenClub: () => openedClub++);

    final later = kDefaultFakeNowUtc.add(const Duration(days: 3));
    final earlier = kDefaultFakeNowUtc.subtract(const Duration(days: 1));

    /// `c07` biçiminde onaysız kulüp (kimliği testin kulübüyle aynı).
    final instantClub = _club.copyWith(approvalRequired: false);

    test('kulüp başvuru almıyor → TST-X1', () async {
      final rejected = _with(MembershipStatus.rejected, retryAfter: later);
      _seed(
        club: _club.copyWith(applicationsOpen: false),
        membership: rejected,
      );
      final container = await _container(
        session: _session(membership: rejected),
      );
      expect(await reapply(container), ReapplyOutcome.blocked);
      // Kapalı kulüp bekleme süresinden önce söylenir (`screens-clubs.js:135`).
      expect(_feedback().toasts, [ToastId.tstX1]);
      expect(_writes(), isEmpty);
    });

    test('kulüp askıda → TST-X1', () async {
      _seed(club: _club.copyWith(status: ClubStatus.suspended));
      final container = await _container(session: _session());
      expect(await reapply(container), ReapplyOutcome.blocked);
      expect(_feedback().toasts, [ToastId.tstX1]);
    });

    test('bekleme süresi dolmadı → TST-X4 (tarih view biçimiyle)', () async {
      final rejected = _with(MembershipStatus.rejected, retryAfter: later);
      _seed(membership: rejected);
      final container = await _container(
        session: _session(membership: rejected),
      );
      expect(await reapply(container), ReapplyOutcome.blocked);
      expect(_feedback().toasts, [ToastId.tstX4]);
      expect(_feedback().toastParams.single, ToastParams(date: _date(later)));
      expect(_writes(), isEmpty);
      expect(
        _viewModel(container).remainingUntilRetry(kDefaultFakeNowUtc),
        const Duration(days: 3),
      );
    });

    for (final status in [
      MembershipStatus.rejected,
      MembershipStatus.removed,
      MembershipStatus.cancelled,
      MembershipStatus.left,
      null,
    ]) {
      test('onay isteyen kulüp · ${status?.name ?? 'üyelik yok'} → '
          'form (SHT-05)', () async {
        final membership = status == null
            ? null
            : _with(status, retryAfter: earlier);
        _seed(membership: membership);
        final container = await _container(
          session: _session(membership: membership),
        );
        expect(await reapply(container), ReapplyOutcome.openSheet);
        expect(_feedback().calls, isEmpty);
        expect(_writes(), isEmpty);
        expect(_state(container).isJoining, isFalse);
      });
    }

    for (final status in [
      MembershipStatus.rejected,
      MembershipStatus.removed,
      MembershipStatus.cancelled,
    ]) {
      test('onaysız kulüp · eski kayıt ${status.name} → yine form '
          '(yönetici onayı)', () async {
        final membership = _with(status, retryAfter: earlier);
        _seed(club: instantClub, membership: membership);
        final container = await _container(
          session: _session(membership: membership),
        );
        expect(await reapply(container), ReapplyOutcome.openSheet);
        expect(_writes(), isEmpty);
      });
    }

    for (final status in [MembershipStatus.left, null]) {
      test('onaysız kulüp · ${status?.name ?? 'üyelik yok'} → anında '
          'katılım → TST-34', () async {
        final membership = status == null ? null : _with(status);
        _seed(club: instantClub, membership: membership);
        final states = <ClubApplicationState>[];
        final container = await _container(
          session: _session(membership: membership),
          states: states,
        );

        expect(await reapply(container), ReapplyOutcome.joined);

        expect(_memberships().applied.single, (
          clubId: _clubId,
          userId: _uid,
          email: _email,
          note: '',
          status: MembershipStatus.active,
        ));
        expect(_writes(), ['joinInstant']);
        expect(states.map((state) => state.isJoining), [true, false]);
        expect(_feedback().toasts, [ToastId.tst34]);
        expect(_feedback().sheets, isEmpty);
        // "Kulübe git" eylemi view'ın verdiği gezinmeyi çağırır.
        expect(openedClub, 0);
        _feedback().tapToastAction();
        expect(openedClub, 1);
      });
    }

    test('anında katılım: çevrimdışı → TST-24, yazılmaz', () async {
      _seed(club: instantClub);
      final container = await _container(session: _session());
      _connectivity().isOffline = true;
      expect(await reapply(container), ReapplyOutcome.failed);
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_writes(), isEmpty);
    });

    test(
      'anında katılım: oturumda profil ya da e-posta yoksa yazılmaz',
      () async {
        _seed(club: instantClub);
        final noUser = await _container(session: _session(withUser: false));
        expect(await reapply(noUser), ReapplyOutcome.failed);
        expect(_state(noUser).submitError, SubmitError.unknown);

        final noEmail = await _container(session: _session(), email: null);
        expect(await reapply(noEmail), ReapplyOutcome.failed);
        expect(_state(noEmail).submitError, SubmitError.unknown);

        expect(_writes(), isEmpty);
        expect(_feedback().toasts, isEmpty);
      },
    );

    test('anında katılım: sunucuda kulüp kapanmış → TST-X1', () async {
      _seed(club: instantClub);
      final container = await _container(session: _session());
      _clubs().clubs[_clubId] = instantClub.copyWith(applicationsOpen: false);
      expect(await reapply(container), ReapplyOutcome.blocked);
      expect(_feedback().toasts, [ToastId.tstX1]);
      expect(_state(container).isJoining, isFalse);
    });

    test('anında katılım: sunucuda bekleme süresi var → TST-X4', () async {
      _seed(club: instantClub);
      final container = await _container(session: _session());
      // Oturum eski: sunucuda reddedilmiş ve bekleme süresi sürüyor.
      _memberships().memberships[_pending.id] = _with(
        MembershipStatus.rejected,
        retryAfter: later,
      );
      expect(await reapply(container), ReapplyOutcome.blocked);
      expect(_feedback().toasts, [ToastId.tstX4]);
      expect(_feedback().toastParams.single, ToastParams(date: _date(later)));
    });

    test('anında katılım: sunucuda eski kayıt var (reapplyNeedsReview) → '
        'form', () async {
      _seed(club: instantClub);
      final container = await _container(session: _session());
      _memberships().memberships[_pending.id] = _with(
        MembershipStatus.cancelled,
      );
      expect(await reapply(container), ReapplyOutcome.openSheet);
      expect(_feedback().toasts, isEmpty);
      expect(_memberships().applied, isEmpty);
    });

    test('anında katılım: kulüp bu arada onaya geçti (conflict) → kulüp '
        'yeniden okunur; sonraki dokunuş forma gider', () async {
      _seed(club: instantClub);
      final container = await _container(session: _session());
      _clubs().clubs[_clubId] = _club;

      expect(await reapply(container), ReapplyOutcome.failed);
      await pumpEventQueue();
      expect(_feedback().toasts, isEmpty);
      expect(_state(container).club, _club);

      expect(await reapply(container), ReapplyOutcome.openSheet);
      expect(_memberships().applied, isEmpty);
    });

    for (final (error, toast, submitError) in [
      (FirestoreError.unavailable, ToastId.tst24, null),
      (FirestoreError.permissionDenied, ToastId.tstX18, null),
      (FirestoreError.unknown, null, SubmitError.unknown),
    ]) {
      test('anında katılım: sunucu ${error.name} → '
          '${toast?.designId ?? 'submitError ${submitError?.name}'}', () async {
        _seed(club: instantClub);
        final container = await _container(session: _session());
        _memberships().failNext(error);
        expect(await reapply(container), ReapplyOutcome.failed);
        expect(_feedback().toasts, [?toast]);
        expect(_state(container).submitError, submitError);
        expect(_state(container).isJoining, isFalse);
      });
    }

    test('kulüp yüklenmediyse yok sayılır', () async {
      final container = await _container(session: _session());
      expect(await reapply(container), ReapplyOutcome.failed);
      expect(_feedback().calls, isEmpty);
    });

    test('art arda dokunuş: tek katılım', () async {
      _seed(club: instantClub);
      final container = await _container(session: _session());
      final results = await Future.wait([
        reapply(container),
        reapply(container),
      ]);
      expect(results, [ReapplyOutcome.joined, ReapplyOutcome.failed]);
      expect(_writes(), ['joinInstant']);
      expect(_feedback().toasts, [ToastId.tst34]);
    });
  });

  group('CLB-05 · ClubApplicationViewModel · TST-34', () {
    test('showJoined: "Kulübe katıldın!" + "Kulübe git" eylemi', () async {
      _seed(membership: _pending);
      final container = await _container();
      var opened = 0;
      _viewModel(container).showJoined(onOpenClub: () => opened++);
      expect(_feedback().toasts, [ToastId.tst34]);
      expect(_feedback().hasToastAction, isTrue);
      _feedback().tapToastAction();
      expect(opened, 1);
    });
  });

  group('CLB-04 · ClubApplicationViewModel · bildirim izni '
      '(DLG-03, TST-19)', () {
    test('"İzin ver" + izin verildi → TST-19, kart kalkar', () async {
      _seed(membership: _pending);
      final container = await _container();
      expect(_state(container).showNotificationPrompt, isTrue);
      _feedback().nextDialogResult = true;

      await _viewModel(container).enableNotifications();
      await pumpEventQueue();

      expect(_feedback().dialogs, [DialogId.dlg03]);
      expect(_permissions().requested, [Permission.notification]);
      expect(_feedback().toasts, [ToastId.tst19]);
      expect(_state(container).showNotificationPrompt, isFalse);
      expect(_store().notificationPermissionAsked, isTrue);
    });

    test('"Şimdi değil": izin istenmez, kart kalır', () async {
      _seed(membership: _pending);
      final container = await _container();
      _feedback().nextDialogResult = false;

      await _viewModel(container).enableNotifications();
      await pumpEventQueue();

      expect(_feedback().dialogs, [DialogId.dlg03]);
      expect(_permissions().requested, isEmpty);
      expect(_feedback().toasts, isEmpty);
      expect(_state(container).showNotificationPrompt, isTrue);
      // Sonuç ne olursa olsun "bir kez" bayrağı işaretlenir.
      expect(_store().notificationPermissionAsked, isTrue);
    });

    test('sistem izni reddedildi: toast yok, kart kalır', () async {
      _seed(membership: _pending);
      _permissions().results[Permission.notification] =
          PermissionStatus.permanentlyDenied;
      final container = await _container();
      _feedback().nextDialogResult = true;

      await _viewModel(container).enableNotifications();

      expect(_permissions().requested, [Permission.notification]);
      expect(_feedback().toasts, isEmpty);
      expect(_state(container).showNotificationPrompt, isTrue);
    });
  });
}
