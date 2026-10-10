// Demo veriden kurulan sabit üyelik modelleri (PLAN §16.2): her fixture
// `tool/seed/demo-data.json` belgesinden PLAN §9.12 dönüşümü + `fromJson` ile
// kurulur (model testleriyle aynı kaynak); elle yazılmış alan yoktur.
import 'package:gu_data/gu_data.dart';

import 'demo_data.dart';

/// Demo verideki üyelik belgelerinden kurulan sabit modeller.
abstract final class MembershipModelFixtures {
  /// Demo verideki [id] kimlikli üyelik (yoksa `ArgumentError`).
  static MembershipModel byId(String id) => MembershipModel.fromJson(
    DemoDataFixture.toFirestoreJson(FirestoreCollections.memberships, id),
    id: id,
  );

  /// `c01_u_mehmet` — Mehmet'in `c01` kulübündeki aktif üyeliği (rol: üye).
  static final MembershipModel c01Mehmet = byId('c01_u_mehmet');

  /// `c04_u_ayse` — Ayşe'nin demo verideki tek üyeliği (`c04`, aktif üye).
  static final MembershipModel c04Ayse = byId('c04_u_ayse');
}
