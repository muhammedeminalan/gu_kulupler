// Demo veriden kurulan sabit yorum modelleri (PLAN §16.2): her fixture
// `tool/seed/demo-data.json` belgesinden PLAN §9.12 dönüşümü + `fromJson` ile
// kurulur (model testleriyle aynı kaynak); elle yazılmış alan yoktur.
import 'package:gu_data/gu_data.dart';

import 'demo_data.dart';

/// Demo verideki yorum belgelerinden kurulan sabit modeller.
abstract final class CommentModelFixtures {
  /// Demo verideki [id] kimlikli yorum (yoksa `ArgumentError`).
  static CommentModel byId(String id) => CommentModel.fromJson(
    DemoDataFixture.toFirestoreJson(FirestoreCollections.comments, id),
    id: id,
  );

  /// `cm01` — `p01` duyurusunun en yeni yorumu (`c01`).
  static final CommentModel cm01 = byId('cm01');

  /// Demo verideki [postId] gönderisinin yorumları, eskiden yeniye (yorum
  /// listesi sırası — FED-02).
  static List<CommentModel> ofPost(String postId) =>
      [
          for (final id in DemoDataFixture.ids(FirestoreCollections.comments))
            byId(id),
        ].where((comment) => comment.postId == postId).toList()
        ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
}
