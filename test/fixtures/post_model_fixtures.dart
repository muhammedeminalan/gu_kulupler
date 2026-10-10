// Demo veriden kurulan sabit gönderi modelleri (PLAN §16.2): her fixture
// `tool/seed/demo-data.json` belgesinden PLAN §9.12 dönüşümü + `fromJson` ile
// kurulur (model testleriyle aynı kaynak); elle yazılmış alan yoktur.
import 'package:gu_data/gu_data.dart';

import 'demo_data.dart';

/// Demo verideki gönderi belgelerinden kurulan sabit modeller.
abstract final class PostModelFixtures {
  /// Demo verideki [id] kimlikli gönderi (yoksa `ArgumentError`).
  static PostModel byId(String id) => PostModel.fromJson(
    DemoDataFixture.toFirestoreJson(FirestoreCollections.posts, id),
    id: id,
  );

  /// `p01` — `c01` kulübünün sabitlenmiş, bildirimi gönderilmiş duyurusu (3
  /// yorum).
  static final PostModel p01 = byId('p01');
}
