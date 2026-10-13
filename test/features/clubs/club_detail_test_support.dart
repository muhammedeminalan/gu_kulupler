// CLB-03 testlerinin ortak verisi: demo verideki `c03` kulübü (Doğa Sporları
// ve Dağcılık Kulübü — onay gerekli, not zorunlu, 231 üye), yönetim kurulu
// üyelikleri ve oturum durumları. Modeller fixture'lardan kurulur; elle
// yazılmış alan yoktur.
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_detail_state.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/product/navigation/club_detail_tab.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_membership_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';

/// Testlerdeki kulübün kimliği.
const String kClubId = 'c03';

/// Oturumdaki kullanıcının kimliği (`FakeSessionStates.uid`).
const String kUid = FakeSessionStates.uid;

/// `c03` — Doğa Sporları ve Dağcılık Kulübü (demo veri).
final ClubModel kClub = ClubModelFixtures.byId(kClubId);

/// Oturumdaki kullanıcı (`u_mehmet` — Mehmet Kaya).
final UserModel kUser = UserModelFixtures.byId(kUid);

/// Oturumdaki kullanıcının e-postası (izinli alan adı).
const String kEmail = 'mehmet.kaya@ogr.gumushane.edu.tr';

/// `c03` başkanı.
final MembershipModel kPresident = MembershipModelFixtures.byId('c03_u_burak');

/// `c03` yönetim kurulu üyeleri (demo veri sırasıyla).
final List<MembershipModel> kBoard = [
  for (final id in ['u032', 'u071', 'u155', 'u151', 'u002'])
    MembershipModelFixtures.byId('c03_$id'),
];

/// `c03` danışmanının üyeliği (yönetim kurulu listesine girmez).
final MembershipModel kAdvisorMembership = MembershipModelFixtures.byId(
  'c03_u_a_c03',
);

/// Ekranda beklenen yönetim kurulu sırası: başkan önde.
final List<MembershipModel> kManagers = [kPresident, ...kBoard];

/// Aktif oturum + profil; üyelik yok (ziyaretçi).
final SessionState kVisitorSession = FakeSessionStates.active.copyWith(
  user: kUser,
);

/// Aktif oturum + `c03` kulübünde verilen [status] / [role] üyeliği.
/// [retryAfter] ret / çıkarma sonrası bekleme anıdır.
SessionState sessionWith({
  MembershipStatus status = MembershipStatus.active,
  ClubRole role = ClubRole.member,
  bool isSuperAdmin = false,
  DateTime? retryAfter,
}) {
  final base = FakeSessionStates.withMembership(
    kClubId,
    status: status,
    role: role,
    isSuperAdmin: isSuperAdmin,
  );
  return base.copyWith(
    user: kUser,
    memberships: {
      kClubId: base.memberships[kClubId]!.copyWith(retryAfter: retryAfter),
    },
  );
}

/// Aktif oturum, süper admin (üyelik yok).
final SessionState kSuperSession = FakeSessionStates.activeSuper.copyWith(
  user: kUser,
);

/// [session] oturumundaki kullanıcının gördüğü dolu ekran durumu: kulüp ve
/// yönetim kurulu yüklü (yöneticiler herkese okunur — CD-139); üye
/// önizlemesi kulübün içini görende ilk etkin üyelerden, görmeyende
/// yöneticilerden kurulur (ViewModel'in ürettiği durumla aynı): içeridekine
/// beş üye (`ClubDetailState.memberPreviewLimit`), dışarıdakine dört.
ClubDetailState loadedState(
  SessionState session, {
  ClubModel? club,
  ClubDetailState base = const ClubDetailState(),
}) {
  final state = base.copyWith(
    club: club ?? kClub,
    access: session.accessTo(kClubId),
    membership: session.memberships[kClubId],
  );
  return state.copyWith(
    managers: kManagers,
    memberPreview: state.seesInside
        ? [kPresident, kAdvisorMembership, ...kBoard.take(3)]
        : kManagers.take(GuSizes.avatarGroupMax).toList(),
  );
}

/// Kayıtlı fake'lere `c03` kulübünü ve yönetim üyeliklerini yazar; oturumun
/// e-postasını kurar. [club] verilirse o kulüp yazılır.
void seedClub({ClubModel? club}) {
  final clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
  final memberships =
      GetIt.I<MembershipRepository>() as FakeMembershipRepository;
  final seeded = club ?? kClub;
  clubs.clubs[seeded.id] = seeded;
  [kPresident, kAdvisorMembership, ...kBoard].forEach(memberships.put);
  (GetIt.I<AuthRepository>() as FakeAuthRepository)
    ..service.uid = kUid
    ..currentUser = const AuthUserInfo(
      uid: kUid,
      email: kEmail,
      emailVerified: true,
    );
}

/// CLB-03 ekranı (`c03`). Varlıkları `pumpApp` / `pumpAppRouter`'ın sardığı
/// `TestAssetBundle` okur (kapak şablonu > 50 KB — `test_asset_bundle.dart`).
Widget clubDetailView({ClubDetailTab? tab}) =>
    ClubDetailView(clubId: kClubId, tab: tab);
