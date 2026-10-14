// FED-03 testlerinin ortak verisi: demo verideki `c03` kulübü (Doğa Sporları
// ve Dağcılık Kulübü) ve başkanı `u_burak` (tasarım yakalamasındaki
// kullanıcı); düzenleme kipi için kulübün üç gönderisi (yazarı oturumdaki
// kullanıcı yapılmış: yalnızca yazar düzenleyebilir). Modeller fixture'lardan
// kurulur.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/feed/provider/compose_state.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';

import '../../fakes/fake_app_preferences_store.dart';
import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_post_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../fixtures/post_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';

/// Testlerdeki kulübün kimliği.
const String kComposeClubId = 'c03';

/// Oturumdaki kullanıcı (`c03` başkanı — Burak Şahin).
const String kComposeUid = 'u_burak';

/// `c03` — Doğa Sporları ve Dağcılık Kulübü.
final ClubModel kComposeClub = ClubModelFixtures.byId(kComposeClubId);

/// Burak Şahin.
final UserModel kComposeUser = UserModelFixtures.byId(kComposeUid);

/// `p10` — üç görselli gönderi; yazarı oturumdaki kullanıcı.
final PostModel kEditPost = PostModelFixtures.byId(
  'p10',
).copyWith(authorId: kComposeUid);

/// `p08` — sabit duyuru; yazarı oturumdaki kullanıcı.
final PostModel kEditAnnouncement = PostModelFixtures.byId(
  'p08',
).copyWith(authorId: kComposeUid);

/// `p09` — anket; yazarı oturumdaki kullanıcı.
final PostModel kEditPoll = PostModelFixtures.byId(
  'p09',
).copyWith(authorId: kComposeUid);

/// Aktif oturum: `c03` kulübünde [role] rolü; [alsoManages] verilirse o
/// kulüpte de yönetim kurulu üyesi (SHT-18 koşulu).
SessionState composeSession({
  ClubRole role = ClubRole.president,
  String? alsoManages,
}) {
  final membership = MembershipModelFixtures.byId(
    '${kComposeClubId}_$kComposeUid',
  );
  return FakeSessionStates.active.copyWith(
    uid: kComposeUid,
    user: kComposeUser,
    memberships: {
      kComposeClubId: membership.copyWith(role: role),
      ...?_boardIn(alsoManages, membership),
    },
  );
}

Map<String, MembershipModel>? _boardIn(
  String? clubId,
  MembershipModel membership,
) => clubId == null
    ? null
    : {
        clubId: membership.copyWith(
          id: FirestoreIds.membership(clubId, kComposeUid),
          clubId: clubId,
          role: ClubRole.board,
        ),
      };

/// Dolu form durumu (ViewModel'in ürettiği durumla aynı): kulüp okunmuş.
ComposeState loadedComposeState({
  ComposeState base = const ComposeState(),
}) => base.copyWith(club: kComposeClub);

/// Kayıtlı fake'lere kulübü ve düzenlenecek gönderileri yazar; galeri ön
/// açıklamasını (DLG-05) onaylanmış sayar. Çağrı günlükleri temizlenir.
void seedCompose() {
  (GetIt.I<ClubRepository>() as FakeClubRepository).clubs[kComposeClubId] =
      kComposeClub;
  (GetIt.I<PostRepository>() as FakePostRepository)
    ..put(kEditPost)
    ..put(kEditAnnouncement)
    ..put(kEditPoll)
    ..calls.clear();
  (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
          .values[AppPreferenceKeys.photoAccessExplained] =
      true;
}
