import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/enums/reminder_option.dart';
import 'package:gu_data/src/models/rsvp_model.dart';

/// Etkinlik katılım kayıtları — `rsvps/{eventId}_{userId}`
/// (`FirestoreIds.rsvp`; PLAN §10.4; rules-spec §3.8, domain-model §2.8, §8;
/// sözleşme `docs/plans/T-22.md §6`).
///
/// Bu arayüz **katılımcı tarafıdır**: kullanıcı yalnızca kendi kaydını yazar.
/// Yönetici geçişleri (yoklama `going ↔ attended`, bekleme listesinden terfi
/// `waitlist → going`) `AttendanceRepository` altındadır (T-30); Mod C'de
/// **otomatik terfi yoktur** — yer açıldığında bekleyeni yönetici elle alır.
///
/// **Belge silme yoktur (D-10):** vazgeçme bir durum geçişidir
/// (`cancelled`); kayıt yerinde kalır ve yeniden katılımda aynı belge, **aynı
/// bilet koduyla** yeniden kullanılır.
///
/// Sayaçlar mutlak değerle yazılmaz: `events.goingCount` / `waitlistCount`
/// kayıtla **aynı transaction'da** ±1 değişir (ya ikisi ya hiçbiri); Security
/// Rules iki belgeyi karşılıklı doğrular ve kontenjan aşımını reddeder.
/// Kaydın yolu oturumdan türetilir — etkinlik belgesine kimin katıldığını
/// gösteren işaretçi **yazılmaz** (W-64).
///
/// Yetki arayüzde değil Security Rules'ta uygulanır: başkası adına yazım
/// [FirestoreError.permissionDenied] döner. Kimlik parametreleri dış girdi
/// sayılır: geçersiz kimlik (boş, `/` içeren)
/// [FirestoreError.invalidArgument] döner.
abstract interface class RsvpRepository {
  /// [userId] kullanıcısını [clubId] kulübünün [eventId] etkinliğine kaydeder
  /// ve yazılan kaydı döner (SHT-12): yer varsa `going`, kontenjan doluysa
  /// ya da önde bekleyen varsa `waitlist` (`EventModel.joinsWaitlist`).
  ///
  /// Transaction:
  /// 1. `events/{eventId}` ve `rsvps/{eventId}_{userId}` okunur;
  /// 2. `capacity == null || (goingCount < capacity && waitlistCount == 0)`
  ///    ise durum `going`, değilse `waitlist` — boşalan yer önce bekleyenindir,
  ///    Mod C'de yönetici terfi eder (aynı anda gelen iki istekten biri bekleme listesine
  ///    düşer — işlem çakışmada yeniden koşar; bayat okumayla yapılan
  ///    `going` yazımını Security Rules reddederse işlem güncel sayaçla bir
  ///    kez daha denenir);
  /// 3. kayıt yazılır — **yeni kayıt:** `eventId`, `clubId`, `userId`,
  ///    `status`, [reminder], `ticketCode` (`TicketCodeGenerator.ticketCode()`),
  ///    yalnızca `waitlist` iken `waitlistAt` (sunucu zamanı), temel alanlar;
  ///    **yeniden katılım** (`cancelled` kayıt): `status`, [reminder],
  ///    `waitlistAt` (`waitlist` iken sunucu zamanı, `going` iken `null`),
  ///    `updatedAt` — `ticketCode` ve `createdAt` korunur;
  /// 4. etkinlik: `goingCount` **ya da** `waitlistCount` `increment(1)` +
  ///    `updatedAt`.
  ///
  /// Dönen modelin zaman alanları istemci saatinden yaklaşık değerdir.
  ///
  /// Hatalar:
  /// - etkinlik yok ya da silinmiş → [FirestoreError.notFound]; [clubId]
  ///   etkinliğin kulübü değil → [FirestoreError.invalidArgument];
  /// - etkinlik yayında değil (taslak, iptal) ya da kayıt kapalı →
  ///   [FirestoreRuleCode.registrationClosed];
  /// - etkinlik bitmiş (`endsAt <= şimdi`) → [FirestoreRuleCode.eventEnded];
  /// - kullanıcı zaten kayıtlı (`going`, `waitlist`, `attended`) →
  ///   [FirestoreError.conflict];
  /// - üyelere özel etkinlikte üye olmayan, askıdaki hesap ya da askıdaki
  ///   kulüp → [FirestoreError.permissionDenied] (Rules).
  Future<FirestoreResult<RsvpModel>> join({
    required String eventId,
    required String clubId,
    required String userId,
    required ReminderOption reminder,
  });

  /// [userId] kullanıcısının [eventId] kaydından vazgeçer (DLG-14).
  ///
  /// Transaction: kayıt ve (`going` / `waitlist` iken) etkinlik okunur →
  /// `going → cancelled` (etkinlik `goingCount` `increment(-1)`) ya da
  /// `waitlist → cancelled` (`waitlistCount` `increment(-1)`); kayıtta
  /// yalnızca `status` + `updatedAt`, etkinlikte sayaç + `updatedAt` yazılır.
  /// Boşalan yere kimse otomatik alınmaz. Etkinliğin durumu aranmaz (iptal
  /// edilmiş etkinlikten de vazgeçilir), bitişi aranır.
  ///
  /// Kayıt zaten `cancelled` ise hiçbir şey yazılmadan başarı döner.
  ///
  /// Hatalar: kayıt yok → [FirestoreError.notFound]; yoklaması alınmış kayıt
  /// (`attended`) → [FirestoreError.failedPrecondition]; etkinlik bitmiş
  /// (`endsAt <= şimdi`) → [FirestoreRuleCode.eventEnded] ("Gelmedin" kaydı
  /// sonradan iptale çevrilemez).
  Future<FirestoreResult<void>> cancel({
    required String eventId,
    required String userId,
  });

  /// [userId] kullanıcısının [eventId] kaydındaki hatırlatma tercihini
  /// değiştirir (SHT-13; dört değer — CD-34).
  ///
  /// Transaction: kayıt okunur → tek güncelleme (`reminder`, `updatedAt`).
  /// Yerel bildirimi çağıran planlar.
  ///
  /// Kayıt yok ya da durumu `going` / `waitlist` değil →
  /// [FirestoreRuleCode.notMember] (TST-X7).
  Future<FirestoreResult<void>> setReminder({
    required String eventId,
    required String userId,
    required ReminderOption reminder,
  });

  /// [userId] kullanıcısının [eventId] kaydı; hiç katılmadıysa başarı `null`
  /// (vazgeçilmiş kayıt `cancelled` durumuyla döner).
  Future<FirestoreResult<RsvpModel?>> getMine({
    required String eventId,
    required String userId,
  });

  /// [userId] kullanıcısının [eventId] kaydını canlı dinler — yalnızca bilet
  /// ekranı açıkken (EVT-03; PLAN §10.6): yönetici bileti okutunca durum anında
  /// `attended` olur.
  ///
  /// Kayıt yoksa olay başarı `null`'dır. Hata olayı akışı kapatmaz; geçersiz
  /// kimlik tek bir [FirestoreError.invalidArgument] olayı yayar.
  Stream<FirestoreResult<RsvpModel?>> watchMine({
    required String eventId,
    required String userId,
  });

  /// [userId] kullanıcısının tüm katılım kayıtları, en yeni üstte (EVT-04,
  /// PRF-03) — vazgeçilmişler dahil.
  ///
  /// Sorgu: `userId == userId`, `isDeleted == false`, `orderBy createdAt ↓`.
  Future<FirestoreResult<List<RsvpModel>>> listMine(String userId);

  /// [clubId] kulübünün [eventId] etkinliğinde, bekleme listesine
  /// [waitlistAtUtc] anında girmiş kaydın sırası ("{n}. sıra"): ondan önce
  /// girmiş `waitlist` kayıtlarının sayısı + 1.
  ///
  /// Sayım sorgusu: `eventId`, `clubId`, `status == waitlist`,
  /// `waitlistAt < waitlistAtUtc` (belge indirilmez).
  ///
  /// Sorgu başkalarının kayıtlarını saydığı için yalnızca **kulüp yönetimi,
  /// danışman ve süper admin** çalıştırabilir; katılımcı
  /// [FirestoreError.permissionDenied] alır (kayıt listesi katılımcıya
  /// kapalıdır — bilet kodu ve kimlik sızmasın). Katılımcının kendi sırası,
  /// katılımdan hemen sonra okunan `events.waitlistCount` değeridir.
  Future<FirestoreResult<int>> waitlistPosition({
    required String eventId,
    required String clubId,
    required DateTime waitlistAtUtc,
  });

  /// [clubId] kulübünün [eventId] etkinliğinde bilet kodu [code] olan kayıt;
  /// yoksa başarı `null` (yoklama doğrulaması — D-30). Yalnızca kulüp
  /// yönetimi, danışman ve süper admin okuyabilir.
  ///
  /// Sorgu: `eventId`, `clubId`, `ticketCode == code`, `limit 2`. [code]
  /// `FirestoreIds.ticketCodePattern` ile eşleşmiyorsa sorgu yapılmadan
  /// başarı `null` döner. Kodu istemci üretir ve Security Rules tekillik
  /// aramaz: iki kayıt aynı kodu taşıyorsa (başkasının kodu kopyalanmış)
  /// eşleşme belirsizdir → [FirestoreError.failedPrecondition]; çağıran
  /// bileti geçersiz sayar, yoklama elle alınır (MGT-06).
  Future<FirestoreResult<RsvpModel?>> findByTicket({
    required String eventId,
    required String clubId,
    required String code,
  });
}
