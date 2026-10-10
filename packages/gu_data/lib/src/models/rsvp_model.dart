import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/models/enums/event_status.dart';
import 'package:gu_data/src/models/enums/reminder_option.dart';
import 'package:gu_data/src/models/enums/rsvp_status.dart';
import 'package:gu_data/src/models/enums/ticket_state.dart';
import 'package:gu_data/src/models/event_model.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rsvp_model.g.dart';

/// Etkinlik katılım kaydı — `rsvps/{eventId}_{userId}` (PLAN §9.6.10,
/// domain-model §2.8, §8; rules-spec §3.8).
///
/// Katılım durumu [status] ile yürür; kayıt soft delete edilmez (vazgeçme bir
/// durum geçişidir). "Gelmedi" ve bilet rozeti saklanmaz, [isAbsent] ve
/// [ticketState] ile türetilir. Tüm zamanlar UTC'dir (D-26).
///
/// Belge kimliği ([id]) JSON'a yazılmaz; okurken [RsvpModel.fromJson]
/// çağrısına ayrıca verilir.
@JsonSerializable()
final class RsvpModel extends Equatable with BaseFields {
  /// Katılım kaydı oluşturur. [id] verilmezse [FirestoreIds.rsvp] ile
  /// [eventId] ve [userId]'den türetilir.
  const RsvpModel({
    required this.eventId,
    required this.clubId,
    required this.userId,
    required this.ticketCode,
    this._id,
    this.status = RsvpStatus.going,
    this.reminder = ReminderOption.none,
    this.waitlistAt,
    this.scannedAt,
    this.scannedBy,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  /// Firestore belge verisinden ([json]) ve belge kimliğinden ([id]) katılım
  /// kaydı üretir.
  ///
  /// Zaman alanları `Timestamp`, [DateTime] ya da ISO-8601 dizgisi olabilir;
  /// hepsi UTC'ye çevrilir. Tanınmayan anahtarlar yok sayılır. Eksik zorunlu
  /// alan ya da bilinmeyen enum değeri `CheckedFromJsonException` fırlatır
  /// (alan adıyla).
  factory RsvpModel.fromJson(Map<String, Object?> json, {required String id}) =>
      _$RsvpModelFromJson(json).copyWith(id: id);

  /// Açıkça verilen belge kimliği; verilmediyse `null` ([id] türetilir).
  final String? _id;

  /// Belge kimliği (`rsvps/{eventId}_{userId}`); JSON'a yazılmaz ve JSON'dan
  /// okunmaz. Açıkça verilmediyse `FirestoreIds.rsvp(eventId, userId)`
  /// değeridir.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get id => _id ?? FirestoreIds.rsvp(eventId, userId);

  /// Etkinliğin kimliği.
  @JsonKey(name: FirestoreFields.eventId)
  final String eventId;

  /// Etkinliğin kulübü (etkinlikten kopyalanır; MGT-06 sorgusu).
  @JsonKey(name: FirestoreFields.clubId)
  final String clubId;

  /// Katılımcının uid'i.
  @JsonKey(name: FirestoreFields.userId)
  final String userId;

  /// Katılım durumu.
  @JsonKey(name: FirestoreFields.status)
  final RsvpStatus status;

  /// Hatırlatıcı seçimi (SHT-13).
  @JsonKey(name: FirestoreFields.reminder)
  final ReminderOption reminder;

  /// Bilet kodu (`GU-XXXX-XXXX`, D-30); yeniden katılımda korunur.
  @JsonKey(name: FirestoreFields.ticketCode)
  final String ticketCode;

  /// Bekleme listesine giriş anı (sunucu zamanı, UTC); sıra hesabı.
  @TimestampConverter()
  @JsonKey(name: FirestoreFields.waitlistAt)
  final DateTime? waitlistAt;

  /// Biletin okutulduğu an (sunucu zamanı, UTC).
  @TimestampConverter()
  @JsonKey(name: FirestoreFields.scannedAt)
  final DateTime? scannedAt;

  /// Yoklamayı alan yöneticinin uid'i.
  @JsonKey(name: FirestoreFields.scannedBy)
  final String? scannedBy;

  @override
  @TimestampConverter()
  @JsonKey(name: FirestoreFields.createdAt)
  final DateTime? createdAt;

  @override
  @TimestampConverter()
  @JsonKey(name: FirestoreFields.updatedAt)
  final DateTime? updatedAt;

  @override
  @JsonKey(name: FirestoreFields.isDeleted)
  final bool isDeleted;

  @override
  @TimestampConverter()
  @JsonKey(name: FirestoreFields.deletedAt)
  final DateTime? deletedAt;

  @override
  @JsonKey(name: FirestoreFields.deletedBy)
  final String? deletedBy;

  /// Katılım kaydı `createdBy` taşımaz (sahibi [userId]).
  @override
  String? get createdBy => null;

  /// "Gelmedi" mi? Etkinlik bitti ve kayıt hâlâ "katılıyor" durumunda.
  /// [event] bu kaydın etkinliği olmalıdır.
  bool isAbsent(EventModel event, AppClock clock) =>
      status == RsvpStatus.going && event.isPast(clock);

  /// Bilet rozeti durumu (EVT-03). [event] bu kaydın etkinliği olmalıdır.
  ///
  /// İptal edilmiş etkinlikte her bilet geçersizdir. Aksi halde "katılıyor"
  /// geçerli, "katıldı" kullanılmış bilettir; vazgeçilmiş ya da bekleme
  /// listesindeki kaydın geçerli bileti yoktur.
  TicketState ticketState(EventModel event) {
    if (event.status == EventStatus.cancelled) return TicketState.voided;
    return switch (status) {
      RsvpStatus.going => TicketState.valid,
      RsvpStatus.attended => TicketState.used,
      RsvpStatus.waitlist || RsvpStatus.cancelled => TicketState.voided,
    };
  }

  /// Bilet QR içeriği: `gu:ticket:v1:{eventId}:{ticketCode}` (D-30).
  String get qrPayload => FirestoreIds.ticketQrPayload(eventId, ticketCode);

  /// Firestore'a yazılacak alanlar; [id] ve `null` değerler yer almaz, zaman
  /// alanları `Timestamp` olur.
  Map<String, Object?> toJson() => _$RsvpModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya döner.
  ///
  /// Null olabilen bir alanı `null` yapmak için ilgili `clear…` bayrağı
  /// verilir; bayrak, aynı alan için verilen değerden önce gelir. Belge
  /// kimliği açıkça verilmemişse kopyada da türetilmeye devam eder.
  RsvpModel copyWith({
    String? id,
    String? eventId,
    String? clubId,
    String? userId,
    RsvpStatus? status,
    ReminderOption? reminder,
    String? ticketCode,
    DateTime? waitlistAt,
    DateTime? scannedAt,
    String? scannedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    bool clearWaitlistAt = false,
    bool clearScannedAt = false,
    bool clearScannedBy = false,
    bool clearCreatedAt = false,
    bool clearUpdatedAt = false,
    bool clearDeletedAt = false,
    bool clearDeletedBy = false,
  }) => RsvpModel(
    id: id ?? _id,
    eventId: eventId ?? this.eventId,
    clubId: clubId ?? this.clubId,
    userId: userId ?? this.userId,
    status: status ?? this.status,
    reminder: reminder ?? this.reminder,
    ticketCode: ticketCode ?? this.ticketCode,
    waitlistAt: clearWaitlistAt ? null : waitlistAt ?? this.waitlistAt,
    scannedAt: clearScannedAt ? null : scannedAt ?? this.scannedAt,
    scannedBy: clearScannedBy ? null : scannedBy ?? this.scannedBy,
    createdAt: clearCreatedAt ? null : createdAt ?? this.createdAt,
    updatedAt: clearUpdatedAt ? null : updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    deletedBy: clearDeletedBy ? null : deletedBy ?? this.deletedBy,
  );

  @override
  List<Object?> get props => [
    id,
    eventId,
    clubId,
    userId,
    status,
    reminder,
    ticketCode,
    waitlistAt,
    scannedAt,
    scannedBy,
    createdAt,
    updatedAt,
    isDeleted,
    deletedAt,
    deletedBy,
  ];
}
