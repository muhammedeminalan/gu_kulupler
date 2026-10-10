// Demo veriden kurulan sabit etkinlik modelleri (PLAN §16.2): her fixture
// `tool/seed/demo-data.json` belgesinden PLAN §9.12 dönüşümü + `fromJson` ile
// kurulur (model testleriyle aynı kaynak); elle yazılmış alan yoktur.
import 'package:gu_data/gu_data.dart';

import 'demo_data.dart';

/// Demo verideki etkinlik belgelerinden kurulan sabit modeller.
abstract final class EventModelFixtures {
  /// Demo verideki [id] kimlikli etkinlik (yoksa `ArgumentError`).
  static EventModel byId(String id) => EventModel.fromJson(
    DemoDataFixture.toFirestoreJson(FirestoreCollections.events, id),
    id: id,
  );

  /// `e01` — Yapay Zekâya Giriş Atölyesi: `c01` kulübünün yayındaki, herkese
  /// açık, 40 kontenjanlı etkinliği.
  static final EventModel e01 = byId('e01');
}
