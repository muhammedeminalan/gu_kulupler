// FED-01 testlerinin ortak verisi: demo verideki `c01` kulübünün yedi
// gönderisi (sabit duyuru `p01`, iki görselli gönderi, bir anket), oyları,
// oturumdaki kullanıcının (`u_mehmet`) kaydı, yazar belgeleri / rolleri ve
// oturum durumları. Modeller fixture'lardan kurulur; elle yazılmış alan
// yoktur. Kulüp, üyelikler ve kullanıcılar CLB-06 desteğinden gelir.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_feed_state.dart';

import '../../fakes/fake_post_repository.dart';
import '../../fakes/fake_saved_post_repository.dart';
import '../../fixtures/demo_data.dart';
import '../../fixtures/post_model_fixtures.dart';
import '../../helpers/fake_app_clock.dart';
import 'club_members_test_support.dart';

export 'club_members_test_support.dart'
    show kClubManagers, kClubUsers, kMembersClub, kMembersUid, membersSession;

/// Testlerdeki kulübün kimliği.
const String kFeedClubId = kMembersClubId;

/// Tasarım yakalamasının anı: referans görüntüdeki göreli zamanlar ("18 saat
/// önce", "3 gün kaldı") bu ana göredir. Anket (`p04`) bu anda açıktır.
final DateTime kFeedNowUtc = DateTime.utc(2026, 10, 8, 17);

/// `c01` kulübünün gönderileri, en yeni üstte (7; `listFeed` sırası).
final List<PostModel> kFeedPosts = PostModelFixtures.ofClub(kFeedClubId);

/// Sabit duyuru (`p01`; `clubs/c01.pinnedPostId`).
final PostModel kPinnedPost = PostModelFixtures.p01;

/// İki görselli gönderi (`p02`).
final PostModel kImagePost = PostModelFixtures.p02;

/// Dört seçenekli anket (`p04`; [kFeedNowUtc] anında açık).
final PostModel kPollPost = PostModelFixtures.p04;

/// Akışın ekrandaki sırası: sabit gönderi üstte, kalanlar en yeniden eskiye.
final List<String> kFeedOrder = [
  kPinnedPost.id,
  for (final post in kFeedPosts)
    if (post.id != kPinnedPost.id) post.id,
];

/// Gönderi yazarlarının kullanıcı belgeleri (kimlik → belge).
final Map<String, UserModel> kFeedAuthors = {
  for (final post in kFeedPosts) post.authorId: kClubUsers[post.authorId]!,
};

/// Yöneticilerin rolleri (kimlik → rol; yazar rozetleri).
final Map<String, ClubRole> kFeedRoles = {
  for (final manager in kClubManagers) manager.userId: manager.role,
};

/// Demo verideki oylar: gönderi → (uid → seçenek kimliği).
final Map<String, Map<String, String>> kFeedVotes = () {
  final votes = <String, Map<String, String>>{};
  for (final key in DemoDataFixture.ids(FirestoreCollections.votesSub)) {
    final postId = key.substring(0, key.indexOf('/'));
    final json = DemoDataFixture.toFirestoreJson(
      FirestoreCollections.votesSub,
      key,
    );
    votes.putIfAbsent(postId, () => <String, String>{})[DemoDataFixture.voteUid(
          key,
        )] =
        json[FirestoreFields.optionId]! as String;
  }
  return votes;
}();

/// `p04` anketinin oy sayıları (seçenek → oy).
final Map<String, int> kPollResults = {
  for (final option in kPollPost.poll!.options)
    option.id: kFeedVotes[kPollPost.id]!.values
        .where((voted) => voted == option.id)
        .length,
};

/// Oturumdaki kullanıcının demo verideki kayıtları.
final List<SavedPostModel> kFeedSaved = [
  for (final id in DemoDataFixture.ids(FirestoreCollections.savedPosts))
    SavedPostModel.fromJson(
      DemoDataFixture.toFirestoreJson(FirestoreCollections.savedPosts, id),
      id: id,
    ),
].where((record) => record.userId == kMembersUid).toList();

/// Oturumdaki kullanıcının `c01` akışındaki kayıtlı gönderileri (`p01`).
final Set<String> kFeedSavedIds = {
  for (final record in kFeedSaved)
    if (kFeedPosts.any((post) => post.id == record.postId)) record.postId,
};

/// Aktif oturum + `c01` kulübünde [role] rolü ([blocked] engellenenler).
SessionState feedSession({
  ClubRole role = ClubRole.member,
  Set<String> blocked = const {},
}) => membersSession(role: role, blocked: blocked);

/// Tüm sayfaları okunmuş dolu akış durumu (ViewModel'in ürettiği durumla
/// aynı); [session] engellenenleri verir.
ClubFeedState loadedFeedState({
  SessionState? session,
  ClubFeedState base = const ClubFeedState(),
}) => base.copyWith(
  club: kMembersClub,
  posts: kFeedPosts,
  pinned: kPinnedPost,
  users: kFeedAuthors,
  roles: kFeedRoles,
  savedPostIds: kFeedSavedIds,
  pollResults: {kPollPost.id: kPollResults},
  blockedUserIds: session?.blockedUserIds,
);

/// Kayıtlı sahte saat.
FakeAppClock feedClock() => GetIt.I<AppClock>() as FakeAppClock;

/// Kayıtlı sahte gönderi deposu.
FakePostRepository feedPosts() =>
    GetIt.I<PostRepository>() as FakePostRepository;

/// Kayıtlı sahte kayıt deposu.
FakeSavedPostRepository feedSaved() =>
    GetIt.I<SavedPostRepository>() as FakeSavedPostRepository;

/// Kayıtlı fake'lere `c01` kulübünü, üyelikleri, kullanıcıları, yedi
/// gönderiyi, oyları ve kayıtları yazar; saati [kFeedNowUtc] anına kurar.
void seedFeed() {
  seedMembers();
  feedClock().set(kFeedNowUtc);
  final posts = feedPosts();
  kFeedPosts.forEach(posts.put);
  posts.votes.addAll({
    for (final MapEntry(:key, :value) in kFeedVotes.entries)
      key: Map<String, String>.of(value),
  });
  kFeedSaved.forEach(feedSaved().put);
}

/// [count] ek gönderi: `p02`'nin kopyaları, hepsi var olan gönderilerden
/// yeni (kimlik `px00`…; en yenisi `px00`). Sayfalama testleri içindir.
List<PostModel> extraFeedPosts(int count) => [
  for (var index = 0; index < count; index++)
    kImagePost.copyWith(
      id: 'px${index.toString().padLeft(2, '0')}',
      images: const [],
      createdAt: kFeedNowUtc.subtract(Duration(minutes: index + 1)),
    ),
];
