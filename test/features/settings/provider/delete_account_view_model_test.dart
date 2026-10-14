// SET-03 · Hesabı sil — `DeleteAccountViewModel` + `DeleteAccountState`:
// adımlar (uyarı → neden → onay; geri), başkanlık engeli (TST-X10; onaydan
// önce yeniden denetim), "SİL" doğrulaması (TST-X11; Türkçe büyük harf, tam
// eşleşme), yeniden doğrulama hatası (yazım yok), dizi ilerlemesi, temizlik
// hatasında oturumun yine kapanması (sürdürme sonraki girişte), TST-22.
// Referans: screens-profile.js:80–92, PLAN §12.6, docs/plans/T-29.md §4 f.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/settings/provider/delete_account_state.dart';
import 'package:gu_kulupler/features/settings/provider/delete_account_view_model.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';

import '../../../fakes/fake_account_deletion_repository.dart';
import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_local_reminder_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';

const String _uid = FakeSessionStates.uid;
const String _word = 'SİL';
const String _password = 'Demo1234!';

MembershipModel _membership(
  String clubId, {
  ClubRole role = ClubRole.member,
  MembershipStatus status = MembershipStatus.active,
}) => MembershipModel(
  clubId: clubId,
  userId: _uid,
  applicant: const MembershipApplicantModel(name: 'Mehmet', avatarSeed: 's'),
  role: role,
  status: status,
);

void main() {
  late FakeAuthRepository auth;
  late FakeUserRepository users;
  late FakeClubRepository clubs;
  late FakeMembershipRepository memberships;
  late FakeAccountDeletionRepository deletion;
  late FakeFeedbackService feedback;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    auth = GetIt.I<AuthRepository>() as FakeAuthRepository
      ..currentUser = const AuthUserInfo(
        uid: _uid,
        email: 'mehmet@ogr.gumushane.edu.tr',
        emailVerified: true,
      );
    users = GetIt.I<UserRepository>() as FakeUserRepository..putActive(_uid);
    memberships = GetIt.I<MembershipRepository>() as FakeMembershipRepository;
    clubs = memberships.clubRepository
      ..put('c01', memberCount: 3)
      ..put('c03', memberCount: 3);
    deletion =
        GetIt.I<AccountDeletionRepository>() as FakeAccountDeletionRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
  });

  Future<ProviderContainer> loaded() async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => FakeSessionStates.active,
        ),
      ],
    );
    addTearDown(
      container.listen(deleteAccountViewModelProvider, (_, _) {}).close,
    );
    await pumpEventQueue();
    return container;
  }

  DeleteAccountViewModel vmOf(ProviderContainer c) =>
      c.read(deleteAccountViewModelProvider.notifier);

  DeleteAccountState stateOf(ProviderContainer c) =>
      c.read(deleteAccountViewModelProvider);

  /// 3. adımda, geçerli formla.
  Future<ProviderContainer> atConfirm({String word = 'sil'}) async {
    final c = await loaded();
    vmOf(c)
      ..next()
      ..next()
      ..setPassword(_password)
      ..setConfirmWord(word);
    return c;
  }

  group('SET-03 · DeleteAccountState', () {
    test('varsayılan: 1. adım, ön denetim sürüyor; props tüm alanlar', () {
      const state = DeleteAccountState();
      expect(state.step, DeleteStep.warning);
      expect(state.isChecking, isTrue);
      expect(state.props, hasLength(12));
      expect(DeleteStep.values.map((s) => s.number), [1, 2, 3]);
    });

    test('canConfirm: şifre dolu + kırpılmış Türkçe büyük harf tam eşleşme '
        '(sil → SİL, SIL ✗, SİLL ✗)', () {
      const state = DeleteAccountState(password: 'x');
      for (final (input, ok) in [
        ('SİL', true),
        ('sil', true),
        ('  Sil ', true),
        ('SIL', false),
        ('SİLL', false),
        ('', false),
      ]) {
        expect(
          state.copyWith(confirmWord: input).canConfirm(_word),
          ok,
          reason: input,
        );
      }
      expect(
        const DeleteAccountState(confirmWord: 'SİL').canConfirm(_word),
        isFalse,
      );
    });
  });

  group('SET-03 · DeleteAccountViewModel · adımlar ve başkanlık', () {
    test('başkan değil: ön denetim ready → Devam 2. ve 3. adıma; geri '
        '3 → 2 → 1, 1. adımda false', () async {
      final c = await loaded();
      expect(stateOf(c).isChecking, isFalse);
      expect(stateOf(c).isPresident, isFalse);

      expect(vmOf(c).next(), isTrue);
      expect(stateOf(c).step, DeleteStep.reason);
      expect(vmOf(c).next(), isTrue);
      expect(stateOf(c).step, DeleteStep.confirm);
      expect(vmOf(c).back(), isTrue);
      expect(vmOf(c).back(), isTrue);
      expect(stateOf(c).step, DeleteStep.warning);
      expect(vmOf(c).back(), isFalse);
    });

    test(
      'TST-X10: etkin başkan → kulüp adlarıyla engel; Devam ilerlemez',
      () async {
        clubs.put('c03', name: 'Doğa Sporları ve Dağcılık Kulübü');
        memberships.put(_membership('c03', role: ClubRole.president));
        final c = await loaded();

        expect(stateOf(c).presidentOfClubIds, ['c03']);
        expect(stateOf(c).clubNames['c03'], 'Doğa Sporları ve Dağcılık Kulübü');
        expect(vmOf(c).next(), isFalse);
        expect(stateOf(c).step, DeleteStep.warning);
        expect(feedback.toasts, [ToastId.tstX10]);
      },
    );

    test('W-34: "Devret" → SHT-25 → DLG-21 → devredilir (TST-49); engel '
        'kalkar, Devam ilerler', () async {
      final president = _membership('c03', role: ClubRole.president);
      memberships
        ..put(president)
        ..put(
          const MembershipModel(
            clubId: 'c03',
            userId: 'u_heir',
            applicant: MembershipApplicantModel(
              name: 'Varis',
              avatarSeed: 'v',
            ),
            role: ClubRole.board,
            status: MembershipStatus.active,
          ),
        );
      final c = createContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => FakeSessionStates.active.copyWith(
              memberships: {'c03': president},
            ),
          ),
        ],
      );
      addTearDown(c.listen(deleteAccountViewModelProvider, (_, _) {}).close);
      await pumpEventQueue();
      expect(stateOf(c).isPresident, isTrue);

      feedback
        ..nextSheetResult = 'u_heir'
        ..dialogResults[DialogId.dlg21] = true;
      expect(await vmOf(c).transfer('c03'), isTrue);
      expect(feedback.sheets, [SheetId.sht25]);
      expect(feedback.toasts, [ToastId.tst49]);
      await pumpEventQueue();
      expect(stateOf(c).isPresident, isFalse);
      expect(vmOf(c).next(), isTrue);
      expect(stateOf(c).step, DeleteStep.reason);
    });

    test('ön denetim okunamazsa hata; Devam yeniden dener', () async {
      deletion.failNext(FirestoreError.unavailable);
      final c = await loaded();
      expect(stateOf(c).isCheckError, isTrue);

      expect(vmOf(c).next(), isFalse);
      await pumpEventQueue();
      expect(stateOf(c).isCheckError, isFalse);
      expect(vmOf(c).next(), isTrue);
    });

    test('neden: seçim + metin 300 karakterde kesilir', () async {
      final c = await loaded();
      vmOf(c)
        ..setReason(DeleteReason.graduated)
        ..setReasonText('a' * 400);
      expect(stateOf(c).reason, DeleteReason.graduated);
      expect(stateOf(c).reasonText.length, DeleteAccountState.reasonTextMax);
    });
  });

  group('SET-03 · DeleteAccountViewModel · onay (confirm)', () {
    test('TST-X11: form eksik → yok sayılır, yeniden doğrulama yok', () async {
      final c = await atConfirm(word: 'SIL');

      expect(await vmOf(c).confirm(_word), DeleteOutcome.ignored);
      expect(feedback.toasts, [ToastId.tstX11]);
      expect(auth.callsTo('reauthenticate'), isEmpty);
    });

    test('yanlış şifre → wrongPassword, hiçbir şey yazılmaz; şifre değişince '
        'hata temizlenir', () async {
      final c = await atConfirm();
      auth.service.failNext(AuthError.invalidCredentials);

      expect(await vmOf(c).confirm(_word), DeleteOutcome.failed);
      expect(stateOf(c).submitError, DeleteError.wrongPassword);
      expect(stateOf(c).isSubmitting, isFalse);
      expect(deletion.callsTo('markDeleted'), isEmpty);
      expect(users.users[_uid]!.status, UserStatus.active);

      vmOf(c).setPassword('Baska123!');
      expect(stateOf(c).submitError, isNull);
    });

    test('çevrimdışı → TST-24, yeniden doğrulama yok', () async {
      (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
          true;
      final c = await atConfirm();

      expect(await vmOf(c).confirm(_word), DeleteOutcome.failed);
      expect(stateOf(c).submitError, DeleteError.network);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(auth.callsTo('reauthenticate'), isEmpty);
    });

    test('onaydan hemen önce başkanlık (yarış) → TST-X10 + 1. adım; '
        'markDeleted yok', () async {
      final c = await atConfirm();
      memberships.put(_membership('c01', role: ClubRole.president));

      expect(await vmOf(c).confirm(_word), DeleteOutcome.blockedByPresidency);
      expect(stateOf(c).step, DeleteStep.warning);
      expect(stateOf(c).presidentOfClubIds, ['c01']);
      expect(feedback.toasts, [ToastId.tstX10]);
      expect(deletion.callsTo('markDeleted'), isEmpty);
    });

    test(
      'markDeleted düşerse hiçbir şey değişmez; yeniden denenebilir',
      () async {
        final c = await atConfirm();
        deletion.markDeletedError = FirestoreError.unknown;

        expect(await vmOf(c).confirm(_word), DeleteOutcome.failed);
        expect(stateOf(c).submitError, DeleteError.unknown);
        expect(stateOf(c).isSubmitting, isFalse);
        expect(users.users[_uid]!.status, UserStatus.active);
        expect(deletion.callsTo('resumeCleanup'), isEmpty);
        expect(auth.callsTo('signOut'), isEmpty);

        expect(await vmOf(c).confirm(_word), DeleteOutcome.deleted);
      },
    );

    test('dizi: reauth → precheck → markDeleted → resumeCleanup (ilerleme) → '
        'hatırlatıcılar iptal → signOut → TST-22', () async {
      for (final clubId in ['c01', 'c02', 'c04', 'c05', 'c06', 'c07']) {
        clubs.put(clubId, memberCount: 2);
        memberships.put(_membership(clubId));
      }
      final c = await atConfirm();
      final progress = <DeleteProgress?>[];
      c.listen(
        deleteAccountViewModelProvider.select((s) => s.progress),
        (_, next) => progress.add(next),
      );

      expect(await vmOf(c).confirm(_word), DeleteOutcome.deleted);

      expect(auth.callsTo('reauthenticate').single.args, [_password]);
      expect(deletion.calls.map((call) => call.method).toList(), [
        'precheck',
        'precheck',
        'markDeleted',
        'resumeCleanup',
        'buildPlan',
        'anonymizeMembershipChunk',
        'anonymizeMembershipChunk',
      ]);
      expect(progress, [
        const DeleteProgress(done: 1, total: 2),
        const DeleteProgress(done: 2, total: 2),
      ]);
      expect(users.users[_uid]!.status, UserStatus.deleted);
      expect(
        memberships.memberships.values.map((m) => m.status).toSet(),
        {MembershipStatus.left},
      );
      expect(
        (GetIt.I<LocalReminderService>() as FakeLocalReminderService)
            .cancelAllCalls,
        1,
      );
      expect(auth.callsTo('signOut'), hasLength(1));
      expect(feedback.toasts, [ToastId.tst22]);
    });

    test('temizlik yarıda kalırsa akış durmaz: oturum yine kapanır + TST-22 '
        '(kalan iş sonraki girişte sürer)', () async {
      for (final clubId in ['c01', 'c02', 'c04', 'c05', 'c06', 'c07']) {
        clubs.put(clubId, memberCount: 2);
        memberships.put(_membership(clubId));
      }
      deletion.failCleanupAfter(1);
      final c = await atConfirm();

      expect(await vmOf(c).confirm(_word), DeleteOutcome.deleted);
      expect(
        memberships.memberships['c07_$_uid']!.status,
        MembershipStatus.active,
      );
      expect(auth.callsTo('signOut'), hasLength(1));
      expect(feedback.toasts, [ToastId.tst22]);

      // Sonraki giriş (oturum çözümü) kalan parçayı bitirir.
      expect((await deletion.resumeCleanup(_uid)).isSuccess, isTrue);
      expect(
        memberships.memberships['c07_$_uid']!.status,
        MembershipStatus.left,
      );
    });

    test('oturum kapatılamazsa oturum yeniden çözülür (silinmiş hesap '
        'orada kapatılır)', () async {
      clubs.put('c02', memberCount: 2);
      memberships.put(_membership('c02'));
      final c = await atConfirm();
      // Kapı temizlik parçasında bekletir: hata yeniden doğrulamaya değil
      // oturum kapatmaya düşsün.
      final gate = deletion.cleanupGate = Completer<void>();
      final outcome = vmOf(c).confirm(_word);
      await pumpEventQueue();
      auth.failNext(AuthError.network);
      gate.complete();

      expect(await outcome, DeleteOutcome.deleted);
      // `refreshUser` → silinmiş hesap → `_closeDeletedAccount`: temizlik
      // (boş plan) + ikinci kapatma → TST-22 bir kez.
      await pumpEventQueue();
      expect(auth.callsTo('signOut'), hasLength(2));
      expect(deletion.callsTo('resumeCleanup'), hasLength(2));
      expect(feedback.toasts, [ToastId.tst22]);
    });
  });
}
