import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'counter_model.g.dart';

/// Bir kulübün bir gündeki bildirimli duyuru sayacı —
/// `announcementCounters/{clubId}_{yyyyMMdd}` belgesi (PLAN §9.6.18,
/// domain-model §2.16, §7).
///
/// `BaseFields` taşımaz (yalnızca [updatedAt]); soft delete edilmez. Gün
/// Istanbul takvim günüdür. Belge kimliği [id] JSON'a girmez.
@JsonSerializable()
final class CounterModel extends Equatable {
  /// Sayaç oluşturur.
  ///
  /// [id] verilmezse `FirestoreIds.announcementCounter(clubId, dayKey)`
  /// değeridir; `dayKey`, [day]'in tiresiz (`yyyyMMdd`) yazımıdır.
  const CounterModel({
    required this.clubId,
    required this.day,
    this._id,
    this.count = 0,
    this.lastPostRef,
    this.updatedAt,
  });

  /// Firestore belge verisinden üretir; [id] belge kimliğidir (veride
  /// `id` anahtarı olsa da okunmaz).
  factory CounterModel.fromJson(
    Map<String, Object?> json, {
    required String id,
  }) => _$CounterModelFromJson(json).copyWith(id: id);

  /// [day] (`yyyy-MM-dd`) içindeki, kimlikte yer almayan ayraç.
  static const String _daySeparator = '-';

  /// Açıkça verilmiş belge kimliği; `null` ise [id] alanlardan türer.
  final String? _id;

  /// Belge kimliği (JSON'a yazılmaz); verilmediyse
  /// `FirestoreIds.announcementCounter(clubId, dayKey)`.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get id =>
      _id ??
      FirestoreIds.announcementCounter(
        clubId,
        day.replaceAll(_daySeparator, ''),
      );

  /// Kulübün kimliği.
  @JsonKey(name: FirestoreFields.clubId)
  final String clubId;

  /// Istanbul takvim günü, `yyyy-MM-dd` (`AppClock.istanbulDay`).
  @JsonKey(name: FirestoreFields.day)
  final String day;

  /// O gün gönderilen bildirimli duyuru sayısı (`0`–
  /// [Limits.announcementDailyLimit]).
  @JsonKey(name: FirestoreFields.count)
  final int count;

  /// Sayacı son artıran batch'teki duyuru belgesinin yolu (CD-41); sayaç hiç
  /// artmadıysa `null`.
  @JsonKey(name: FirestoreFields.lastPostRef)
  final String? lastPostRef;

  /// Son güncelleme anı (sunucu zamanı, UTC).
  @JsonKey(name: FirestoreFields.updatedAt)
  @TimestampConverter()
  final DateTime? updatedAt;

  /// O gün kalan bildirimli duyuru hakkı.
  int get remaining => Limits.announcementDailyLimit - count;

  /// Firestore'a yazılacak harita ([id] hariç).
  Map<String, Object?> toJson() => _$CounterModelToJson(this);

  /// Verilen alanları değişmiş kopya; `clear*` bayrağı alanı `null` yapar.
  ///
  /// [id] açıkça verilmediyse türetilmiş kalır ve yeni [clubId] / [day]
  /// değerlerini izler.
  CounterModel copyWith({
    String? id,
    String? clubId,
    String? day,
    int? count,
    String? lastPostRef,
    bool clearLastPostRef = false,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
  }) => CounterModel(
    id: id ?? _id,
    clubId: clubId ?? this.clubId,
    day: day ?? this.day,
    count: count ?? this.count,
    lastPostRef: clearLastPostRef ? null : (lastPostRef ?? this.lastPostRef),
    updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
  );

  @override
  List<Object?> get props => [id, clubId, day, count, lastPostRef, updatedAt];
}
