// Demo veriden kurulan sabit katılım kayıtları (PLAN §16.2): her fixture
// `tool/seed/demo-data.json` belgesinden PLAN §9.12 dönüşümü + `fromJson` ile
// kurulur; elle yazılmış alan yoktur. Etkinlik sayaçları bu kayıtlardan
// hesaplanır (`EventModelFixtures`).
import 'package:gu_data/gu_data.dart';

import 'demo_data.dart';

/// Demo verideki katılım kayıtlarından kurulan sabit modeller.
abstract final class RsvpModelFixtures {
  /// Demo verideki [id] kimlikli kayıt (`{eventId}_{userId}`; yoksa
  /// `ArgumentError`).
  static RsvpModel byId(String id) => RsvpModel.fromJson(
    DemoDataFixture.toFirestoreJson(FirestoreCollections.rsvps, id),
    id: id,
  );

  /// `e01_u_mehmet` — Mehmet'in `e01` etkinliğindeki kaydı (`going`,
  /// hatırlatma 1 saat önce).
  static final RsvpModel e01Mehmet = byId('e01_u_mehmet');

  /// `e08_u_mehmet` — Mehmet'in `e08` bekleme listesi kaydı.
  static final RsvpModel e08Mehmet = byId('e08_u_mehmet');

  /// `e18_u_mehmet` — Mehmet'in geçmiş `e18` etkinliğinde yoklaması alınmış
  /// kaydı (`attended`).
  static final RsvpModel e18Mehmet = byId('e18_u_mehmet');

  /// Demo verideki [eventId] etkinliğinin kayıtları; bekleme listesindekiler
  /// giriş sırasıyla (`waitlistAt ↑`), diğerleri kimlik sırasıyla.
  static List<RsvpModel> ofEvent(String eventId) =>
      [
          for (final id in DemoDataFixture.ids(FirestoreCollections.rsvps))
            if (id.startsWith('${eventId}_')) byId(id),
        ].where((rsvp) => rsvp.eventId == eventId).toList()
        ..sort(_waitlistFirstInOrder);

  /// Demo verideki [userId] kullanıcısının kayıtları, en yeni üstte
  /// (`RsvpRepository.listMine` sırası — EVT-04).
  static List<RsvpModel> ofUser(String userId) =>
      [
          for (final id in DemoDataFixture.ids(FirestoreCollections.rsvps))
            if (id.endsWith('_$userId')) byId(id),
        ].where((rsvp) => rsvp.userId == userId).toList()
        ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

  /// Bekleme listesi önce ve `waitlistAt` artan; geri kalanı kimlik sırası.
  static int _waitlistFirstInOrder(RsvpModel a, RsvpModel b) {
    final left = a.waitlistAt;
    final right = b.waitlistAt;
    if (a.status == RsvpStatus.waitlist && b.status == RsvpStatus.waitlist) {
      return left!.compareTo(right!);
    }
    if (a.status == RsvpStatus.waitlist) return -1;
    if (b.status == RsvpStatus.waitlist) return 1;
    return a.id.compareTo(b.id);
  }
}
