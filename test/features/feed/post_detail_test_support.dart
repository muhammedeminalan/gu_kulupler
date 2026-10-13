// FED-02 / SHT-09 testlerinin ortak verisi: demo verideki `p01` duyurusu
// (`c01` — Yazılım ve Yapay Zekâ Topluluğu; sabit, 46 beğeni, 3 yorum), üç
// yorumu, yazarların kullanıcı belgeleri, kulübün yöneticileri ve oturum
// durumları. Modeller fixture'lardan kurulur; elle yazılmış alan yoktur.
//
// Sıra notu: demo veride `cm01` en yeni yorumdur; uygulama yorumları eskiden
// yeniye çizer (`watchComments` `createdAt ↑`), referans görüntü ise
// prototipin `commentIds` sırasını (cm01 → cm03) gösterir.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_state.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_comment_repository.dart';
import '../../fakes/fake_membership_repository.dart';
import '../../fakes/fake_post_repository.dart';
import '../../fakes/fake_saved_post_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/comment_model_fixtures.dart';
import '../../fixtures/demo_data.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../fixtures/post_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';

/// Testlerdeki kulübün kimliği.
const String kPostClubId = 'c01';

/// Testlerdeki gönderinin kimliği (sabit duyuru).
const String kPostId = 'p01';

/// Oturumdaki kullanıcının kimliği (`u_mehmet` — `c01` üyesi).
const String kPostUid = FakeSessionStates.uid;

/// Oturumdaki kullanıcının e-postası.
const String kPostEmail = 'mehmet.kaya@ogr.gumushane.edu.tr';

/// `c01` — Yazılım ve Yapay Zekâ Topluluğu.
final ClubModel kPostClub = ClubModelFixtures.byId(kPostClubId);

/// `p01` — "Güz Hackathon'u için ekip kurma haftası başlıyor" (Baran Çelik,
/// başkan).
final PostModel kPost = PostModelFixtures.p01;

/// `p04` — anket (`c01`); demo verideki bitişi test saatinden öncedir
/// (açık anket için [openPollPost]).
final PostModel kPollPost = PostModelFixtures.p04;

/// `p04` anketi, bitişi test saatinden bir gün sonraya alınmış (oy verilebilir).
/// Kayıtlı `AppClock`'u okur: `registerDefaultFakes` sonrası çağrılır.
PostModel openPollPost() => kPollPost.copyWith(
  poll: kPollPost.poll!.copyWith(
    endsAt: GetIt.I<AppClock>().nowUtc().add(const Duration(days: 1)),
  ),
);

/// `p01` yorumları, eskiden yeniye: `cm03` (Zehra Korkmaz, yönetim kurulu),
/// `cm02` (Serkan Keskin), `cm01` (Hilal Özdemir).
final List<CommentModel> kPostComments = CommentModelFixtures.ofPost(kPostId);

/// Oturumdaki kullanıcının yazmadığı, sıradan bir üyenin yorumu (`cm01` —
/// Hilal Özdemir).
final CommentModel kOtherComment = kPostComments.last;

/// `c01` kulübünün başkanı ve yönetim kurulu (aktif üyelikler).
final List<MembershipModel> kPostManagers = [
  for (final id in DemoDataFixture.ids(FirestoreCollections.memberships))
    if (id.startsWith('${kPostClubId}_')) MembershipModelFixtures.byId(id),
].where(_isManager).toList();

bool _isManager(MembershipModel membership) =>
    membership.status == MembershipStatus.active &&
    (membership.role == ClubRole.president ||
        membership.role == ClubRole.board);

/// Yöneticilerin rolleri (kimlik → rol).
final Map<String, ClubRole> kPostRoles = {
  for (final membership in kPostManagers) membership.userId: membership.role,
};

/// Gönderi ve yorum yazarlarının kullanıcı belgeleri (kimlik → belge).
final Map<String, UserModel> kPostUsers = {
  for (final userId in {
    kPost.authorId,
    kPollPost.authorId,
    for (final comment in kPostComments) comment.authorId,
  })
    userId: UserModelFixtures.byId(userId),
};

/// Aktif oturum + `c01` kulübünde [role] rolü ([blocked] engellenenler).
SessionState postSession({
  ClubRole role = ClubRole.member,
  Set<String> blocked = const {},
}) => FakeSessionStates.active.copyWith(
  user: UserModelFixtures.byId(kPostUid),
  memberships: {
    kPostClubId: MembershipModelFixtures.c01Mehmet.copyWith(role: role),
  },
  blockedUserIds: blocked,
);

/// Dolu ekran durumu (ViewModel'in ürettiği durumla aynı): tasarımdaki gibi
/// gönderi kaydedilmiş; [session] engellenenleri verir.
PostDetailState loadedPostState({
  SessionState? session,
  PostDetailState base = const PostDetailState(),
  PostModel? post,
  List<CommentModel>? comments,
}) => base.copyWith(
  post: post ?? kPost,
  club: kPostClub,
  comments: comments ?? kPostComments,
  users: kPostUsers,
  roles: kPostRoles,
  blockedUserIds: session?.blockedUserIds,
  isSaved: true,
);

/// Kayıtlı fake'lere `c01` kulübünü, `p01` (+ açık `p04`) gönderisini, yorumları,
/// yazar belgelerini, yönetici üyeliklerini ve oturumdaki kullanıcının `p01`
/// kaydını yazar; oturumun kimliğini kurar. Çağrı günlükleri temizlenir.
Future<void> seedPost() async {
  final posts = GetIt.I<PostRepository>() as FakePostRepository
    ..put(kPost)
    ..put(openPollPost());
  final comments = GetIt.I<CommentRepository>() as FakeCommentRepository;
  kPostComments.forEach(comments.put);
  (GetIt.I<ClubRepository>() as FakeClubRepository).clubs[kPostClubId] =
      kPostClub;
  kPostManagers.forEach(
    (GetIt.I<MembershipRepository>() as FakeMembershipRepository).put,
  );
  (GetIt.I<UserRepository>() as FakeUserRepository).users.addAll(kPostUsers);
  (GetIt.I<AuthRepository>() as FakeAuthRepository)
    ..service.uid = kPostUid
    ..currentUser = const AuthUserInfo(
      uid: kPostUid,
      email: kPostEmail,
      emailVerified: true,
    );
  final saved = GetIt.I<SavedPostRepository>() as FakeSavedPostRepository;
  await saved.save(userId: kPostUid, postId: kPostId, clubId: kPostClubId);
  saved.calls.clear();
  posts.calls.clear();
}
