import 'package:gu_data/src/core/bulk_result.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/enums/rsvp_status.dart';
import 'package:gu_data/src/models/enums/scan_outcome.dart';
import 'package:gu_data/src/models/rsvp_model.dart';

/// Etkinlik yoklaması ve bekleme listesi terfisi — yöneticinin
/// `rsvps/{eventId}_{userId}` yazımları (PLAN §10.4 `AttendanceRepository`;
/// rules-spec §3.7 / §3.8; sözleşme `docs/plans/T-30.md` §4).
///
/// Her durum geçişi (`going → attended`, `attended → going`,
/// `waitlist → going`) **tek transaction**'dır: kayıt, etkinliğin sayaçları
/// (tam ±1 bileşimi) ve sayaç işaretçisi yan belgesi
/// `events/{eventId}/private/counter` (`{clubId, lastRsvpRef, updatedAt}` —
/// W-64, W-77) birlikte yazılır; terfide `waitlist_promoted` bildirimi de
/// aynı işlemdedir. Yetkiyi Rules uygular: yalnızca etkinliğin kulübünün
/// etkin yöneticisi (danışman ve süper admin değil); yoklama yalnızca K-G
/// penceresinde (`startsAt − Limits.attendanceWindowBefore` …
/// `endsAt + Limits.attendanceWindowAfter`). Kayıt silinmez (D-10).
abstract interface class AttendanceRepository {
  /// [eventId] etkinliğinin katılım kayıtlarını canlı dinler (MGT-06 açıkken
  /// — PLAN §10.6 #5); sıra `status`, `waitlistAt`.
  ///
  /// Hata olayı akışı kapatmaz; geçersiz kimlik tek bir
  /// [FirestoreError.invalidArgument] olayı yayar.
  Stream<FirestoreResult<List<RsvpModel>>> watchParticipants({
    required String eventId,
    required String clubId,
  });

  /// [eventId] etkinliğinin katılım kayıtları (tek okuma); [statuses]
  /// verilirse yalnızca o durumlar (iptal fan-out alıcıları, yoklama
  /// yüzdesi). Boş küme sorgu yapmadan boş liste döner.
  Future<FirestoreResult<List<RsvpModel>>> listParticipants({
    required String eventId,
    required String clubId,
    Set<RsvpStatus>? statuses,
  });

  /// MGT-07 → SHT-24 — [qrPayload] biletini okutur.
  ///
  /// `FirestoreIds.parseTicketQr` çözemezse ya da `eventId` eşleşmezse,
  /// kayıt yoksa / `cancelled` / `waitlist` ise ya da kod kopyalanmışsa
  /// (`RsvpRepository.findByTicket` → `failedPrecondition`, W-79)
  /// [ScanOutcome.invalid]; kayıt `attended` ise [ScanOutcome.alreadyScanned]
  /// (ikisinde de yazım yok); `going` ise [markAttended] ile aynı
  /// transaction (`going → attended`, `scannedAt` sunucu zamanı,
  /// `scannedBy` [actorId], `attendedCount +1`) → [ScanOutcome.valid].
  /// [actorId]'nin kendi bileti [ScanOutcome.invalid]'dir (katılımcının
  /// kendisi yoklama alamaz — rules-spec §3.8; başka yönetici okutur).
  ///
  /// Hatalar: pencere dışı → [FirestoreRuleCode.attendanceWindowClosed];
  /// işlem sırasında durum değişti → [FirestoreError.conflict].
  Future<FirestoreResult<ScanOutcome>> scanTicket({
    required String eventId,
    required String clubId,
    required String qrPayload,
    required String actorId,
  });

  /// MGT-06 — elle yoklama: [attended] `true` ise `going → attended`
  /// (`attendedCount +1`), `false` ise `attended → going` (`attendedCount
  /// −1`, `scannedAt` / `scannedBy` boşalır; TST-31 "Geri al").
  ///
  /// Hatalar: kayıt beklenen durumda değil → [FirestoreError.conflict];
  /// etkinlik yayında değil → [FirestoreError.conflict]; pencere dışı →
  /// [FirestoreRuleCode.attendanceWindowClosed]; [userId] == [actorId]
  /// (kendi kaydı — rules-spec §3.8) → [FirestoreError.invalidArgument].
  Future<FirestoreResult<void>> markAttended({
    required String eventId,
    required String userId,
    required String actorId,
    required bool attended,
  });

  /// DLG-17 — `going` kayıtların hepsini sırayla [markAttended] ile
  /// `attended` yapar (her kayıt **ayrı** transaction; `+n` yazımı yok).
  /// Zaten `attended` olanlar atlanır (idempotent; kesintide kalanlar
  /// sonraki çağrıda sürer). [actorId]'nin kendi kaydı kümeye girmez (kendi
  /// yoklamasını alamaz — rules-spec §3.8). [onProgress] her kayıttan sonra
  /// (bitmiş, toplam) ile çağrılır. Pencere dışı → ilk kayıtta durur,
  /// [FirestoreRuleCode.attendanceWindowClosed].
  Future<FirestoreResult<BulkResult>> markAllAttended({
    required String eventId,
    required String clubId,
    required String actorId,
    void Function(int done, int total)? onProgress,
  });

  /// MGT-06 "Kayıtlıya al" — `waitlist → going` (tek transaction:
  /// `goingCount +1`, `waitlistCount −1`, sayaç işaretçisi ve terfi edilene
  /// `waitlist_promoted` bildirimi). Otomatik terfi yoktur.
  ///
  /// Hatalar: kontenjan dolu → [FirestoreRuleCode.capacityFull] (TST-X14);
  /// kayıt `waitlist` değil / etkinlik yayında değil →
  /// [FirestoreError.conflict]; etkinlik bitmiş →
  /// [FirestoreRuleCode.eventEnded]; [userId] == [actorId] (bekleyen yönetici
  /// kendini terfi ettiremez — rules-spec §3.8) →
  /// [FirestoreError.invalidArgument].
  Future<FirestoreResult<void>> promote({
    required String eventId,
    required String userId,
    required String actorId,
  });
}
