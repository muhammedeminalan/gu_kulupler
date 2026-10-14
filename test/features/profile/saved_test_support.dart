// PRF-04 testlerinin ortak verisi: demo verideki Mehmet'in iki kaydı —
// `p01` (Yazılım ve Yapay Zekâ, başlıklı; en son kaydedilen) ve `p21`
// (Fotoğraf ve Sinema, başlıksız) — ve sayfalama için üretilmiş kümeler.
// Gönderiler fixture'lardan kurulur; kayıt modeli demo veride `saved`
// eşlemesidir (fixture'ı yok), burada kurulur.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/profile/provider/saved_state.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_post_repository.dart';
import '../../fakes/fake_saved_post_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/post_model_fixtures.dart';

/// Oturumdaki kullanıcı (`u_mehmet`).
const String kSavedUid = FakeSessionStates.uid;

/// `p01` — duyuru başlıklı (`c01`).
final PostModel kSavedP01 = PostModelFixtures.p01;

/// `p21` — başlıksız gönderi (`c07`).
final PostModel kSavedP21 = PostModelFixtures.byId('p21');

/// [post] gönderisinin Mehmet'e ait kaydı; [savedAt] sıralamayı belirler.
SavedPostModel savedOf(PostModel post, DateTime savedAt) => SavedPostModel(
  userId: kSavedUid,
  postId: post.id,
  clubId: post.clubId,
  savedAt: savedAt,
);

/// `p01` kaydı (en yeni).
final SavedPostModel kSavedRecordP01 = savedOf(
  kSavedP01,
  DateTime.utc(2026, 10, 6),
);

/// `p21` kaydı.
final SavedPostModel kSavedRecordP21 = savedOf(
  kSavedP21,
  DateTime.utc(2026, 10, 4),
);

/// Fake'leri tohumlar: [posts] gönderileri + kulüpleri; [records] kayıtları.
void seedSaved({List<PostModel>? posts, List<SavedPostModel>? records}) {
  final postRepo = GetIt.I<PostRepository>() as FakePostRepository;
  final clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
  final saved = GetIt.I<SavedPostRepository>() as FakeSavedPostRepository;
  for (final post in posts ?? [kSavedP01, kSavedP21]) {
    postRepo.put(post);
    clubs.clubs[post.clubId] = ClubModelFixtures.byId(post.clubId);
  }
  (records ?? [kSavedRecordP01, kSavedRecordP21]).forEach(saved.put);
}

/// [count] gönderi (`p01` kopyası, `s0`, `s1`, …) ve kayıtları (en yeni
/// üstte).
({List<PostModel> posts, List<SavedPostModel> records}) savedBatch(int count) {
  final posts = <PostModel>[];
  final records = <SavedPostModel>[];
  for (var i = 0; i < count; i++) {
    final post = kSavedP01.copyWith(id: 's$i');
    posts.add(post);
    records.add(
      savedOf(post, DateTime.utc(2026, 10, 6).subtract(Duration(hours: i))),
    );
  }
  return (posts: posts, records: records);
}

/// Dolu ekran durumu: [entries] satırları, kulüp adları fixture'dan.
SavedState loadedSaved({List<SavedEntry>? entries}) {
  final list =
      entries ?? [(kSavedRecordP01, kSavedP01), (kSavedRecordP21, kSavedP21)];
  return SavedState(
    items: list,
    clubNames: {
      for (final (saved, _) in list)
        saved.clubId: ClubModelFixtures.byId(saved.clubId).name,
    },
  );
}
