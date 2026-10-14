import 'package:equatable/equatable.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/models/club_model.dart';
import 'package:gu_data/src/models/enums/rsvp_status.dart';
import 'package:gu_data/src/models/event_model.dart';

/// Çok alıcılı bildirimlerin alıcı kümesini istemcide çözer (PLAN §10.5
/// "Alıcı çözümü (Mod C)"; `docs/plans/T-25.md` §6 d).
///
/// Her metot okuyan aktörün Rules izniyle çalışır: [managersOf] başvuran
/// dahil her etkin kullanıcıya açıktır (rules-spec §3.4 R(d), CD-139);
/// [membersOf] ve [rsvpUsersOf] kulüp yönetimine açıktır (üye listesi /
/// katılımcı listesi). Sonuçlar tekilleştirilmiş uid listeleridir; sıra
/// anlamsızdır. Tercih süzgeci uygulanmaz (okuyan taraf süzer).
abstract interface class RecipientResolver {
  /// [clubId] kulübünün etkin yöneticileri (`board`, `president`; danışman
  /// hariç) — `application_received` alıcıları
  /// (`MembershipRepository.listManagers`).
  Future<FirestoreResult<List<String>>> managersOf(String clubId);

  /// [clubId] kulübünün tüm etkin üyeleri (`role != advisor`, sayfasız),
  /// [excludeUserId] hariç — `announcement` alıcıları
  /// (`MembershipRepository.listActiveMembers` sayfaları birleştirilir).
  Future<FirestoreResult<List<String>>> membersOf(
    String clubId, {
    String? excludeUserId,
  });

  /// [eventId] etkinliğinin ([clubId] kulübü) durumu [statuses] içinde olan
  /// katılım kayıtlarının sahipleri — `event_cancelled` alıcıları
  /// (`going` + `waitlist`). Sorgu `eventId` + `clubId` süzgeçlidir
  /// (rules-spec §6; yalnızca kulüp yönetimi okur).
  Future<FirestoreResult<List<String>>> rsvpUsersOf(
    String eventId,
    String clubId,
    Set<RsvpStatus> statuses,
  );

  /// `event_new` alıcıları: [event] kulübünün üyeleri (`event.createdBy`
  /// hariç) ∪ etkinlik herkese açıksa [club] kategorisinin ilgi alanlarıyla
  /// eşleşen kullanıcılar (`UserRepository.listByInterests`, en çok
  /// `Limits.eventNewInterestFanOutMax` — CD-38). Sınır aşıldıysa
  /// `RecipientSet.truncated` doludur.
  Future<FirestoreResult<RecipientSet>> eventNew(
    EventModel event,
    ClubModel club,
  );

  /// [eventNew] kümesinin tekilleştirilmiş boyu — DLG-22 "{n} kişiye
  /// bildirim gönder" sayısı (aynı iki sorgu).
  Future<FirestoreResult<int>> estimateEventNew(
    EventModel event,
    ClubModel club,
  );
}

/// Çözülmüş alıcı kümesi (PLAN §10.5 `RecipientResolver.eventNew`).
final class RecipientSet extends Equatable {
  /// Tekilleştirilmiş [ids]; [truncated] ilgi-eşleşmeli kısmın üst sınıra
  /// takıldığını bildirir (uygulama katmanı `AppLogger.warn` yazar).
  const RecipientSet({required this.ids, this.truncated = false});

  /// Alıcı uid'leri (tekil).
  final List<String> ids;

  /// İlgi-eşleşmeli alıcılar `Limits.eventNewInterestFanOutMax`'ta kesildi
  /// mi?
  final bool truncated;

  @override
  List<Object?> get props => [ids, truncated];
}
