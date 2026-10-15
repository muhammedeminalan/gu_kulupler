// ADM-03 · AdminClubFormViewModel: doğrulama (ad / kategori / başkan
// zorunlu, danışman adı K-A), ad çakışması (CD-63 `alreadyExists` → alan
// uyarısı), oluşturma (createClub: başkan üyeliği + presidentId tutarlı,
// danışman ad + unvan, TST-33; görseller oluşturmadan sonra, yeniden
// denemede kulüp ikinci kez oluşturulmaz), düzenleme (yalnızca değişen
// alanlar, başkan ata → üyelik + presidentId, danışman bağını kaldır W-101 a,
// değişiklik yok TST-X9), okuma hatası, `permissionDenied` → claim yenileme
// (CD-160) — PLAN §12.6.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_club_form_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_club_form_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

import '../../../fakes/fake_admin_repository.dart';
import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_image_picker_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../admin_club_form_test_support.dart';
import '../admin_test_support.dart';

void main() {
  late FakeAdminRepository admin;
  late FakeClubRepository clubs;
  late FakeUserRepository users;
  late FakeMembershipRepository memberships;
  late FakeFeedbackService feedback;
  late FakeImagePickerService picker;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    admin = GetIt.I<AdminRepository>() as FakeAdminRepository;
    clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
    users = GetIt.I<UserRepository>() as FakeUserRepository;
    memberships = GetIt.I<MembershipRepository>() as FakeMembershipRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    picker = GetIt.I<ImagePickerService>() as FakeImagePickerService;
    seedClubForm();
  });

  ProviderContainer container() {
    final c = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => kAdminSession,
        ),
      ],
    );
    return c;
  }

  /// İlk okuması bitmiş kapsayıcı ([clubId] → düzenleme).
  Future<(ProviderContainer, AdminClubFormViewModelProvider)> opened([
    String? clubId,
  ]) async {
    final c = container();
    final provider = adminClubFormViewModelProvider(clubId);
    addTearDown(c.listen(provider, (_, _) {}).close);
    await pumpEventQueue();
    return (c, provider);
  }

  /// Yeni kulüp formunu geçerli doldurur.
  void fill(AdminClubFormViewModel vm) => vm
    ..setName('  Satranç Kulübü ')
    ..setCategory('k07')
    ..setSummary('Kısa')
    ..setPresident(users.users[kFormPresidentId]!);

  MembershipModel? membershipOf(String clubId, String uid) => memberships
      .memberships
      .values
      .where((m) => m.clubId == clubId && m.userId == uid)
      .firstOrNull;

  group('ADM-03 · AdminClubFormViewModel · doğrulama', () {
    test('boş form: ad, kategori, başkan zorunlu; yazım yok', () async {
      final (c, p) = await opened();
      expect(c.read(p), const AdminClubFormState());
      expect(await c.read(p.notifier).save(), AdminClubFormOutcome.invalid);
      expect(c.read(p).errors, {
        AdminClubField.name: FormFieldError.required,
        AdminClubField.category: FormFieldError.required,
        AdminClubField.president: FormFieldError.required,
      });
      expect(admin.callsTo('createClub'), isEmpty);
    });

    test(
      'danışman: unvan girildiyse ad zorunlu; tek harf kısa (K-A)',
      () async {
        final (c, p) = await opened();
        final vm = c.read(p.notifier);
        fill(vm);
        vm.setAdvisorTitle('Dr.');
        expect(vm.validate(), isFalse);
        expect(c.read(p).errors, {
          AdminClubField.advisorName: FormFieldError.required,
        });
        vm.setAdvisorName('A');
        expect(vm.validate(), isFalse);
        expect(
          c.read(p).errors[AdminClubField.advisorName],
          FormFieldError.tooShort,
        );
        vm.setAdvisorName('Ayşe Kaya');
        expect(vm.validate(), isTrue);
      },
    );

    test('kirli takibi: değişiklik kirletir; ikon kategoriden türer', () async {
      final (c, p) = await opened();
      final vm = c.read(p.notifier);
      expect(c.read(p).iconName, AdminClubFormState.defaultIconName);
      vm.setCategory('k03');
      expect(c.read(p).isDirty, isTrue);
      expect(c.read(p).iconName, 'mountain');
    });
  });

  group('ADM-03 · AdminClubFormViewModel · oluşturma', () {
    test('createClub: başkan üyeliği + presidentId tutarlı, danışman ad + '
        'unvan, TST-33', () async {
      final (c, p) = await opened();
      final vm = c.read(p.notifier);
      fill(vm);
      vm
        ..setAdvisorTitle('Dr.')
        ..setAdvisorName('Ayşe Kaya')
        ..setApprovalRequired(value: false);

      expect(await vm.save(), AdminClubFormOutcome.created);

      final call = admin.callsTo('createClub').single.args;
      final input = call[0]! as ClubCreateInput;
      expect(input.name, 'Satranç Kulübü');
      expect(input.nameLower, 'satranç kulübü');
      expect(input.iconName, 'gamepad-2');
      expect(input.approvalRequired, isFalse);
      expect(call[2], kFormPresidentEmail);
      expect(call[3], const AdvisorInput(name: 'Ayşe Kaya', title: 'Dr.'));
      final club = clubs.clubs.values.singleWhere(
        (club) => club.name == 'Satranç Kulübü',
      );
      expect(club.presidentId, kFormPresidentId);
      expect(club.memberCount, 1);
      final membership = membershipOf(club.id, kFormPresidentId)!;
      expect(membership.status, MembershipStatus.active);
      expect(membership.role, ClubRole.president);
      expect(feedback.toasts, [ToastId.tst33]);
      expect(c.read(p).isDirty, isFalse);
    });

    test('ad alınmış (CD-63) → alan uyarısı, kulüp oluşmaz; ad değişince '
        'uyarı kalkar', () async {
      clubs.put('cX', name: 'Satranç Kulübü');
      clubs.clubs['cX'] = clubs.clubs['cX']!.copyWith(
        nameLower: 'satranç kulübü',
      );
      final (c, p) = await opened();
      final vm = c.read(p.notifier);
      fill(vm);

      expect(await vm.save(), AdminClubFormOutcome.invalid);
      expect(c.read(p).isNameTaken, isTrue);
      expect(c.read(p).isSubmitting, isFalse);
      expect(clubs.clubs, hasLength(1));
      expect(feedback.toasts, isEmpty);

      vm.setName('Satranç Kulübü 2');
      expect(c.read(p).isNameTaken, isFalse);
    });

    test('logo oluşturmadan sonra yüklenir; yükleme hatası → yeniden denemede '
        'kulüp ikinci kez oluşturulmaz', () async {
      final (c, p) = await opened();
      final vm = c.read(p.notifier);
      fill(vm);
      // Desteklenmeyen tür: kulüp oluşur, yükleme reddedilir (hata bandı).
      picker.nextPick = PickedImage(
        bytes: kFakeJpeg.bytes,
        contentType: 'image/gif',
        width: kFakeJpeg.width,
        height: kFakeJpeg.height,
      );
      await vm.pickLogo(MediaSource.gallery);
      expect(c.read(p).pendingLogo, isNotNull);

      expect(await vm.save(), AdminClubFormOutcome.failed);
      expect(c.read(p).isSubmitError, isTrue);
      expect(feedback.toasts, isEmpty);
      final createdId = c.read(p).createdClubId;
      expect(createdId, isNotNull);

      picker.nextPick = kFakeJpeg;
      await vm.pickLogo(MediaSource.gallery);
      expect(await vm.save(), AdminClubFormOutcome.created);
      expect(admin.callsTo('createClub'), hasLength(1));
      expect(admin.mediaUploads.single.clubId, createdId);
      expect(clubs.clubs[createdId]!.logoPath, isNotNull);
      expect(feedback.toasts.last, ToastId.tst33);
    });

    test('permissionDenied → TST-X18 + claim yenilenir (CD-160)', () async {
      final auth = GetIt.I<AuthRepository>() as FakeAuthRepository;
      final (c, p) = await opened();
      final vm = c.read(p.notifier);
      fill(vm);
      admin.failNext(FirestoreError.permissionDenied);

      expect(await vm.save(), AdminClubFormOutcome.failed);
      await pumpEventQueue();
      expect(feedback.toasts, [ToastId.tstX18]);
      expect(auth.callsTo('isSuperAdmin'), isNotEmpty);
    });

    test(
      'başkan adayları: etkin, personel olmayan; seçili başkan hariç',
      () async {
        users.users['u_staff'] = users
            .putActive('u_staff', name: 'Personel')
            .copyWith(staff: true);
        final (c, p) = await opened();
        final vm = c.read(p.notifier)
          ..setPresident(users.users[kFormPresidentId]!);
        final ids = (await vm.presidentCandidates())!.map((u) => u.uid);
        expect(ids, contains(kFormNextId));
        expect(ids, isNot(contains(kFormPresidentId)));
        expect(ids, isNot(contains('u_staff')));
        expect(admin.callsTo('listUsersByName').single.args.first, '');
      },
    );
  });

  group('ADM-03 · AdminClubFormViewModel · düzenleme', () {
    test(
      'açılış: form belgeden + başkan kartı; değişiklik yok → TST-X9',
      () async {
        final club = await seedFormClub();
        final (c, p) = await opened(club.id);
        final state = c.read(p);
        expect(state.isEdit, isTrue);
        expect(state.name, 'Doğa Kulübü');
        expect(state.advisorTitle, 'Dr.');
        expect(state.president?.uid, kFormPresidentId);
        expect(state.isDirty, isFalse);

        expect(await c.read(p.notifier).save(), AdminClubFormOutcome.blocked);
        expect(feedback.toasts, [ToastId.tstX9]);
        expect(admin.callsTo('updateClubIdentity'), isEmpty);
      },
    );

    test('yalnızca değişen alanlar yazılır; TST-21', () async {
      final club = await seedFormClub();
      final (c, p) = await opened(club.id);
      final vm = c.read(p.notifier)
        ..setSummary('Yeni özet')
        ..setApplicationsOpen(value: false);

      expect(await vm.save(), AdminClubFormOutcome.saved);
      final patch =
          admin.callsTo('updateClubIdentity').single.args[1]!
              as ClubIdentityPatch;
      expect(
        patch,
        const ClubIdentityPatch(summary: 'Yeni özet', applicationsOpen: false),
      );
      expect(clubs.clubs[club.id]!.summary, 'Yeni özet');
      expect(feedback.toasts, [ToastId.tst21]);
    });

    test(
      'başkan ata → üyelik + presidentId tutarlı (eski başkan board)',
      () async {
        final club = await seedFormClub();
        final (c, p) = await opened(club.id);
        final vm = c.read(p.notifier)
          ..removePresident()
          ..setPresident(users.users[kFormNextId]!);

        expect(await vm.save(), AdminClubFormOutcome.saved);
        expect(admin.callsTo('updateClubIdentity'), isEmpty);
        expect(admin.callsTo('assignPresident').single.args, [
          club.id,
          kFormNextId,
          kAdminSession.uid,
        ]);
        expect(clubs.clubs[club.id]!.presidentId, kFormNextId);
        expect(membershipOf(club.id, kFormNextId)!.role, ClubRole.president);
        expect(
          membershipOf(club.id, kFormNextId)!.status,
          MembershipStatus.active,
        );
        expect(membershipOf(club.id, kFormPresidentId)!.role, ClubRole.board);
      },
    );

    test('ad başka kulübünkiyle çakışır → alan uyarısı', () async {
      clubs.put('cX', name: 'Satranç');
      clubs.clubs['cX'] = clubs.clubs['cX']!.copyWith(nameLower: 'satranç');
      final club = await seedFormClub();
      final (c, p) = await opened(club.id);
      final vm = c.read(p.notifier)..setName('Satranç');

      expect(await vm.save(), AdminClubFormOutcome.invalid);
      expect(c.read(p).isNameTaken, isTrue);
      expect(clubs.clubs[club.id]!.name, 'Doğa Kulübü');
    });

    test('bağlı danışman "Kaldır" (W-101 a) → setAdvisor(active: false); '
        'ad / unvan kalır', () async {
      final club = await seedFormClub(linkedAdvisor: true);
      final (c, p) = await opened(club.id);
      expect(c.read(p).linkedAdvisorId, kFormAdvisorUid);
      final vm = c.read(p.notifier)..unlinkAdvisor();
      expect(c.read(p).linkedAdvisorId, isNull);
      expect(c.read(p).isDirty, isTrue);

      expect(await vm.save(), AdminClubFormOutcome.saved);
      expect(admin.callsTo('setAdvisor').single.args, [
        club.id,
        kFormAdvisorUid,
        false,
      ]);
      expect(admin.callsTo('updateClubIdentity'), isEmpty);
      expect(clubs.clubs[club.id]!.advisor?.userId, isNull);
      expect(clubs.clubs[club.id]!.advisor?.name, 'Ayşe Kaya');
    });

    test('danışman temizlenir → clearAdvisor', () async {
      final club = await seedFormClub();
      final (c, p) = await opened(club.id);
      final vm = c.read(p.notifier)
        ..setAdvisorTitle('')
        ..setAdvisorName('');

      expect(await vm.save(), AdminClubFormOutcome.saved);
      final patch =
          admin.callsTo('updateClubIdentity').single.args[1]!
              as ClubIdentityPatch;
      expect(patch, const ClubIdentityPatch(clearAdvisor: true));
      expect(clubs.clubs[club.id]!.advisor, isNull);
    });

    test('okunamayan kulüp → hata; "Yeniden dene" okur', () async {
      final club = await seedFormClub();
      clubs.failNext(FirestoreError.unavailable);
      final (c, p) = await opened(club.id);
      expect(c.read(p).isError, isTrue);
      await c.read(p.notifier).load();
      expect(c.read(p).isError, isFalse);
      expect(c.read(p).original?.id, club.id);
    });
  });
}
