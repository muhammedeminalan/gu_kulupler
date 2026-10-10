// Demo veriden kurulan sabit kulüp modelleri (PLAN §16.2): her fixture
// `tool/seed/demo-data.json` belgesinden PLAN §9.12 dönüşümü + `fromJson` ile
// kurulur (model testleriyle aynı kaynak); elle yazılmış alan yoktur.
import 'package:gu_data/gu_data.dart';

import 'demo_data.dart';

/// Demo verideki kulüp belgelerinden kurulan sabit modeller.
abstract final class ClubModelFixtures {
  /// Demo verideki [id] kimlikli kulüp (yoksa `ArgumentError`).
  static ClubModel byId(String id) => ClubModel.fromJson(
    DemoDataFixture.toFirestoreJson(FirestoreCollections.clubs, id),
    id: id,
  );

  /// `c01` — Yazılım ve Yapay Zekâ Topluluğu: aktif, başvuru onaylı ve not
  /// zorunlu; sabitlenmiş gönderisi `p01`, danışmanı `u_zeynep`.
  static final ClubModel c01 = byId('c01');
}
