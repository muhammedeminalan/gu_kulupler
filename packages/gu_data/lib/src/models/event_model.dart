import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/models/enums/club_palette.dart';
import 'package:gu_data/src/models/enums/club_pattern.dart';
import 'package:gu_data/src/models/enums/event_status.dart';
import 'package:gu_data/src/models/enums/event_type.dart';
import 'package:gu_data/src/models/enums/event_visibility.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'event_model.g.dart';

/// Etkinlik belgesi — `events/{eventId}` (PLAN §9.6.9, domain-model §2.7,
/// §8; rules-spec §3.7).
///
/// Tüm zamanlar UTC'dir (D-26). Sayaçlar ([goingCount], [waitlistCount],
/// [attendedCount]) yalnızca katılım kaydıyla aynı batch/transaction içinde
/// ±1 değişir; [lastRsvpRef] o yazımın belge yolunu taşır (CD-41).
/// [goingCount] **kayıtlı** sayısıdır: yoklama (`going→attended`) onu
/// düşürmez, yalnızca [attendedCount]'u artırır; yani [attendedCount],
/// [goingCount]'un alt kümesidir (CD-130). "Geçmiş" bir durum değildir,
/// [isPast] ile türetilir. Yalnızca taslak soft delete edilebilir (DLG-31);
/// yayındaki etkinlik iptal edilir.
///
/// Belge kimliği ([id]) JSON'a yazılmaz; okurken [EventModel.fromJson]
/// çağrısına ayrıca verilir.
@JsonSerializable()
final class EventModel extends Equatable with BaseFields {
  /// Etkinlik oluşturur. [coverSeed] verilmezse
  /// [FirestoreIds.eventCoverSeed] ile [id]'den türetilir.
  const EventModel({
    required this.clubId,
    required this.title,
    required this.type,
    required this.startsAt,
    required this.endsAt,
    required this.coverPalette,
    required this.coverPattern,
    this.id = '',
    this.createdBy,
    this.desc = '',
    this.placeId,
    this.placeText,
    this.capacity,
    this.visibility = EventVisibility.public,
    this.status = EventStatus.draft,
    this.cancelReason,
    this._coverSeed,
    this.coverPath,
    this.registrationOpen = true,
    this.autoReminder = true,
    this.goingCount = 0,
    this.waitlistCount = 0,
    this.attendedCount = 0,
    this.lastRsvpRef,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  /// Firestore belge verisinden ([json]) ve belge kimliğinden ([id]) etkinlik
  /// üretir.
  ///
  /// Zaman alanları `Timestamp`, [DateTime] ya da ISO-8601 dizgisi olabilir;
  /// hepsi UTC'ye çevrilir. Tanınmayan anahtarlar yok sayılır. Eksik zorunlu
  /// alan ya da bilinmeyen enum değeri `CheckedFromJsonException` fırlatır
  /// (alan adıyla).
  factory EventModel.fromJson(
    Map<String, Object?> json, {
    required String id,
  }) => _$EventModelFromJson(json).copyWith(id: id);

  /// Belge kimliği (`events/{eventId}`); JSON'a yazılmaz ve JSON'dan
  /// okunmaz. Henüz yazılmamış taslakta boştur.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id;

  /// Etkinliği düzenleyen kulübün kimliği.
  @JsonKey(name: FirestoreFields.clubId)
  final String clubId;

  /// Etkinliği oluşturan yöneticinin uid'i.
  @override
  @JsonKey(name: FirestoreFields.createdBy)
  final String? createdBy;

  /// Başlık (1 – `Limits.eventTitleMax`).
  @JsonKey(name: FirestoreFields.title)
  final String title;

  /// Açıklama (≤ `Limits.eventDescMax`).
  @JsonKey(name: FirestoreFields.desc)
  final String desc;

  /// Etkinlik türü.
  @JsonKey(name: FirestoreFields.type)
  final EventType type;

  /// Başlangıç anı (UTC).
  @RequiredTimestampConverter()
  @JsonKey(name: FirestoreFields.startsAt)
  final DateTime startsAt;

  /// Bitiş anı (UTC); [startsAt]'ten sonradır.
  @RequiredTimestampConverter()
  @JsonKey(name: FirestoreFields.endsAt)
  final DateTime endsAt;

  /// Mekân tablosu kimliği (`StaticTables.placeIds`); serbest metin mekânda
  /// `null`.
  @JsonKey(name: FirestoreFields.placeId)
  final String? placeId;

  /// Serbest metin mekân (≤ `Limits.placeTextMax`).
  @JsonKey(name: FirestoreFields.placeText)
  final String? placeText;

  /// Kontenjan; `null` = sınırsız, doluysa `≥ 1`.
  @JsonKey(name: FirestoreFields.capacity)
  final int? capacity;

  /// Görünürlük (herkese açık ya da yalnızca üyeler).
  @JsonKey(name: FirestoreFields.visibility)
  final EventVisibility visibility;

  /// Durum (taslak, yayında, iptal).
  @JsonKey(name: FirestoreFields.status)
  final EventStatus status;

  /// İptal nedeni (DLG-23); yalnızca [status] iptal iken dolu.
  @JsonKey(name: FirestoreFields.cancelReason)
  final String? cancelReason;

  /// Kapak deseni tohumu (`event-{eventId}`).
  @JsonKey(name: FirestoreFields.coverSeed)
  String get coverSeed => _coverSeed ?? FirestoreIds.eventCoverSeed(id);
  final String? _coverSeed;

  /// Kapak paleti.
  @JsonKey(name: FirestoreFields.coverPalette)
  final ClubPalette coverPalette;

  /// Kapak deseni.
  @JsonKey(name: FirestoreFields.coverPattern)
  final ClubPattern coverPattern;

  /// Özel kapak görselinin Storage yolu (`events/{eventId}/{file}`, K-C).
  @JsonKey(name: FirestoreFields.coverPath)
  final String? coverPath;

  /// Kayıt açık mı?
  @JsonKey(name: FirestoreFields.registrationOpen)
  final bool registrationOpen;

  /// Otomatik hatırlatma açık mı?
  @JsonKey(name: FirestoreFields.autoReminder)
  final bool autoReminder;

  /// Kayıtlı sayacı: durumu `going` **ya da** `attended` olan katılım
  /// kayıtları. Katılımda artar, vazgeçmede azalır; yoklama değiştirmez
  /// (Rules `going→attended` = `(0, 0, +1)`). Kontenjan ([isFull]) ve K-F
  /// ([canUnpublish]) bu sayıya bakar.
  @JsonKey(name: FirestoreFields.goingCount)
  final int goingCount;

  /// Bekleme listesi sayacı.
  @JsonKey(name: FirestoreFields.waitlistCount)
  final int waitlistCount;

  /// Yoklaması alınan katılımcı sayacı; [goingCount]'a dahildir.
  @JsonKey(name: FirestoreFields.attendedCount)
  final int attendedCount;

  /// Sayaçları son değiştiren katılım kaydının yolu
  /// (`rsvps/{eventId}_{userId}`, CD-41).
  @JsonKey(name: FirestoreFields.lastRsvpRef)
  final String? lastRsvpRef;

  /// Yayınlanma anı (sunucu zamanı, UTC); taslakta `null`.
  @TimestampConverter()
  @JsonKey(name: FirestoreFields.publishedAt)
  final DateTime? publishedAt;

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

  /// Etkinlik bitti mi? (`endsAt < şimdi`).
  bool isPast(AppClock clock) => endsAt.isBefore(clock.nowUtc());

  /// Kontenjan doldu mu? Sınırsız etkinlik ([capacity] `null`) hiç dolmaz.
  bool get isFull {
    final limit = capacity;
    return limit != null && goingCount >= limit;
  }

  /// Yoklama oranı, `0`–`1`: `attendedCount / goingCount`; kayıtlı yoksa `0`.
  ///
  /// Payda yalnızca [goingCount]'tur: yoklaması alınanlar zaten onun içinde
  /// sayılır (durum sayılarıyla `attended / (going + attended)`).
  double get attendanceRate => goingCount == 0 ? 0 : attendedCount / goingCount;

  /// Şu an yoklama penceresinin içinde mi? Pencere
  /// `startsAt − Limits.attendanceWindowBefore` ile
  /// `endsAt + Limits.attendanceWindowAfter` arasıdır; iki uç dahildir (K-G,
  /// Rules ile aynı).
  bool attendanceWindow(AppClock clock) {
    final now = clock.nowUtc();
    final opensAt = startsAt.subtract(Limits.attendanceWindowBefore);
    final closesAt = endsAt.add(Limits.attendanceWindowAfter);
    return !now.isBefore(opensAt) && !now.isAfter(closesAt);
  }

  /// Yayından çekilebilir mi? Yalnızca kayıtlı katılımcı yokken (K-F).
  bool get canUnpublish => goingCount == 0;

  /// Firestore'a yazılacak alanlar; [id] ve `null` değerler yer almaz, zaman
  /// alanları `Timestamp` olur.
  Map<String, Object?> toJson() => _$EventModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya döner.
  ///
  /// Null olabilen bir alanı `null` yapmak için ilgili `clear…` bayrağı
  /// verilir; bayrak, aynı alan için verilen değerden önce gelir. [coverSeed]
  /// açıkça verilmemişse kopyada da [id]'den türetilmeye devam eder.
  EventModel copyWith({
    String? id,
    String? clubId,
    String? createdBy,
    String? title,
    String? desc,
    EventType? type,
    DateTime? startsAt,
    DateTime? endsAt,
    String? placeId,
    String? placeText,
    int? capacity,
    EventVisibility? visibility,
    EventStatus? status,
    String? cancelReason,
    String? coverSeed,
    ClubPalette? coverPalette,
    ClubPattern? coverPattern,
    String? coverPath,
    bool? registrationOpen,
    bool? autoReminder,
    int? goingCount,
    int? waitlistCount,
    int? attendedCount,
    String? lastRsvpRef,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    bool clearCreatedBy = false,
    bool clearPlaceId = false,
    bool clearPlaceText = false,
    bool clearCapacity = false,
    bool clearCancelReason = false,
    bool clearCoverPath = false,
    bool clearLastRsvpRef = false,
    bool clearPublishedAt = false,
    bool clearCreatedAt = false,
    bool clearUpdatedAt = false,
    bool clearDeletedAt = false,
    bool clearDeletedBy = false,
  }) => EventModel(
    id: id ?? this.id,
    clubId: clubId ?? this.clubId,
    createdBy: clearCreatedBy ? null : createdBy ?? this.createdBy,
    title: title ?? this.title,
    desc: desc ?? this.desc,
    type: type ?? this.type,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    placeId: clearPlaceId ? null : placeId ?? this.placeId,
    placeText: clearPlaceText ? null : placeText ?? this.placeText,
    capacity: clearCapacity ? null : capacity ?? this.capacity,
    visibility: visibility ?? this.visibility,
    status: status ?? this.status,
    cancelReason: clearCancelReason ? null : cancelReason ?? this.cancelReason,
    coverSeed: coverSeed ?? _coverSeed,
    coverPalette: coverPalette ?? this.coverPalette,
    coverPattern: coverPattern ?? this.coverPattern,
    coverPath: clearCoverPath ? null : coverPath ?? this.coverPath,
    registrationOpen: registrationOpen ?? this.registrationOpen,
    autoReminder: autoReminder ?? this.autoReminder,
    goingCount: goingCount ?? this.goingCount,
    waitlistCount: waitlistCount ?? this.waitlistCount,
    attendedCount: attendedCount ?? this.attendedCount,
    lastRsvpRef: clearLastRsvpRef ? null : lastRsvpRef ?? this.lastRsvpRef,
    publishedAt: clearPublishedAt ? null : publishedAt ?? this.publishedAt,
    createdAt: clearCreatedAt ? null : createdAt ?? this.createdAt,
    updatedAt: clearUpdatedAt ? null : updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    deletedBy: clearDeletedBy ? null : deletedBy ?? this.deletedBy,
  );

  @override
  List<Object?> get props => [
    id,
    clubId,
    createdBy,
    title,
    desc,
    type,
    startsAt,
    endsAt,
    placeId,
    placeText,
    capacity,
    visibility,
    status,
    cancelReason,
    coverSeed,
    coverPalette,
    coverPattern,
    coverPath,
    registrationOpen,
    autoReminder,
    goingCount,
    waitlistCount,
    attendedCount,
    lastRsvpRef,
    publishedAt,
    createdAt,
    updatedAt,
    isDeleted,
    deletedAt,
    deletedBy,
  ];
}
