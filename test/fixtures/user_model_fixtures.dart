// Demo veriden kurulan sabit kullanıcı modelleri (PLAN §16.2): her fixture
// `tool/seed/demo-data.json` belgesinden PLAN §9.12 dönüşümü + `fromJson` ile
// kurulur (model testleriyle aynı kaynak); elle yazılmış alan yoktur.
import 'package:gu_data/gu_data.dart';

import 'demo_data.dart';

/// Demo verideki kullanıcı belgelerinden kurulan sabit modeller.
abstract final class UserModelFixtures {
  /// Demo verideki [id] kimlikli kullanıcı (yoksa `ArgumentError`).
  static UserModel byId(String id) => UserModel.fromJson(
    DemoDataFixture.toFirestoreJson(FirestoreCollections.users, id),
    id: id,
  );

  /// `u_ayse` — Ayşe Demir: profili tamamlanmış aktif öğrenci.
  static final UserModel ayse = byId('u_ayse');
}
