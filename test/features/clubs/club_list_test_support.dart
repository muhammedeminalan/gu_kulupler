// CLB-01 testlerinin ortak verisi: demo verideki 14 kulüp (13 aktif + askıdaki
// `c14`), `c03` yönetim üyelikleri ve oturum durumları. Modeller
// fixture'lardan kurulur; elle yazılmış alan yoktur.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_list_state.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/demo_data.dart';
import '../../fixtures/membership_model_fixtures.dart';
import 'club_detail_test_support.dart';

export 'club_detail_test_support.dart'
    show kEmail, kManagers, kPresident, kUid, kUser, kVisitorSession;

/// Demo verideki tüm kulüpler, dosya sırasıyla (`c01`…`c14`). Üye sayıları
/// tasarımdaki değerlerdir (prototip `clubs[id].memberCount` — `c03` 231):
/// tohumlanan belgede sayı üyelik belgelerinden türetilir, referans
/// görüntüler ise prototip sayısını gösterir.
final List<ClubModel> kAllClubs = [
  for (final id in DemoDataFixture.ids(FirestoreCollections.clubs))
    ClubModelFixtures.byId(id).copyWith(memberCount: _designMemberCount(id)),
];

int _designMemberCount(String clubId) {
  final clubs = DemoDataFixture.raw['clubs']! as Map<String, Object?>;
  return (clubs[clubId]! as Map<String, Object?>)['memberCount']! as int;
}

/// Ekranda listelenen kulüp sayısı: askıdaki `c14` listeye girmez.
final int kActiveClubCount = kAllClubs
    .where((club) => club.status == ClubStatus.active)
    .length;

/// Onay gerekli kulüp (`c03` — Doğa Sporları ve Dağcılık; en çok üyeli).
const String kApprovalClubId = 'c03';

/// Onaysız (anında katılım) kulüp (`c07` — Fotoğraf ve Sinema).
const String kInstantClubId = 'c07';

/// Başvuruları kapalı kulüp (`c05` — Tiyatro).
const String kClosedClubId = 'c05';

/// Askıdaki kulüp (`c14` — Kariyer ve Mezunlar).
const String kSuspendedClubId = 'c14';

/// [id] kimlikli demo kulüp.
ClubModel clubOf(String id) => kAllClubs.firstWhere((club) => club.id == id);

/// Oturumdaki kullanıcının (`u_mehmet`) demo üyelikleri: `c01` üye, `c07`
/// yönetim kurulu (rozet için rol değiştirilir), `c06` bekleyen, `c05`
/// reddedilmiş.
final SessionState kMemberSession = kVisitorSession.copyWith(
  memberships: {
    'c01': MembershipModelFixtures.byId('c01_u_mehmet'),
    'c07': MembershipModelFixtures.byId(
      'c07_u_mehmet',
    ).copyWith(role: ClubRole.board),
    'c06': MembershipModelFixtures.byId('c06_u_mehmet'),
    'c05': MembershipModelFixtures.byId('c05_u_mehmet'),
  },
);

/// [session] oturumundaki kullanıcının gördüğü dolu ekran durumu: kulüpler
/// yüklü, `c03` yönetici önizlemesi dolu (ViewModel'in ürettiği durumla aynı).
ClubListState loadedListState(
  SessionState session, {
  ClubListState base = const ClubListState(),
}) => base.copyWith(
  clubs: kAllClubs,
  memberClubIds: {
    for (final clubId in session.memberships.keys)
      if (session.roleIn(clubId) != null) clubId,
  },
  managerPreviews: {kApprovalClubId: kManagers},
);

/// Kayıtlı fake'lere tüm demo kulüpleri ve `c03` yönetim üyeliklerini yazar;
/// oturumun e-postasını kurar.
void seedClubs() {
  seedClub();
  final clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
  for (final club in kAllClubs) {
    clubs.clubs[club.id] = club;
  }
}
