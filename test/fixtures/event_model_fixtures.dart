// Demo veriden kurulan sabit etkinlik modelleri (PLAN §16.2): her fixture
// `tool/seed/demo-data.json` belgesinden PLAN §9.12 dönüşümü + `fromJson` ile
// kurulur (model testleriyle aynı kaynak); elle yazılmış alan yoktur.
// Sayaçlar katılım kayıtlarından hesaplanır (`RsvpModelFixtures` ile
// tutarlı — CD-130).
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

  /// `e02` — `c01` kulübünün yalnızca üyelere açık, yayındaki etkinliği.
  static final EventModel e02 = byId('e02');

  /// `e03` — kontenjanı **dolu** (30 / 30) ve 4 kişilik bekleme listesi olan
  /// herkese açık etkinlik (`c03`).
  static final EventModel e03 = byId('e03');

  /// `e19` — geçmiş etkinlik: 38 kayıtlı, 34 yoklama (`c03`).
  static final EventModel e19 = byId('e19');

  /// `e21` — iptal edilmiş etkinlik (neden dolu; `c07`).
  static final EventModel e21 = byId('e21');

  /// `e22` — kontenjansız, üyelere özel **taslak** (`c03`; hiç
  /// yayınlanmamış: `publishedAt` boş).
  static final EventModel e22 = byId('e22');

  /// Demo verideki tüm etkinlikler (silinmiş yok), kimlik sırasıyla.
  static List<EventModel> all() => [
    for (final id in DemoDataFixture.ids(FirestoreCollections.events)) byId(id),
  ];

  /// Demo verideki [clubId] kulübünün etkinlikleri, en yeni başlangıç üstte
  /// (CLB-03 / MGT-04 sırası).
  static List<EventModel> ofClub(String clubId) =>
      all().where((event) => event.clubId == clubId).toList()
        ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
}
