import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:json_annotation/json_annotation.dart';

part 'club_notification_prefs_model.g.dart';

/// Tek bir kulübe özgü bildirim tercihleri — `settings.clubs[clubId]` değeri
/// (PLAN §9.6.14, domain-model §2.12).
///
/// Gömülü modeldir: kendi belgesi ve `BaseFields` alanları yoktur. Kulüp için
/// kayıt yoksa bu modelin varsayılanları geçerlidir (hepsi açık, sessize
/// alınmamış).
@JsonSerializable()
final class ClubNotificationPrefsModel extends Equatable {
  /// Kulüp bildirim tercihleri oluşturur.
  const ClubNotificationPrefsModel({
    this.announcements = true,
    this.events = true,
    this.posts = true,
    this.muted = false,
  });

  /// Firestore map'inden model üretir; eksik alanlar varsayılanını alır.
  factory ClubNotificationPrefsModel.fromJson(Map<String, Object?> json) =>
      _$ClubNotificationPrefsModelFromJson(json);

  /// Kulübün duyuru bildirimleri açık mı?
  @JsonKey(name: FirestoreFields.announcements)
  final bool announcements;

  /// Kulübün etkinlik bildirimleri açık mı?
  @JsonKey(name: FirestoreFields.events)
  final bool events;

  /// Kulübün gönderi bildirimleri açık mı?
  @JsonKey(name: FirestoreFields.posts)
  final bool posts;

  /// Kulüp tümüyle sessize alındı mı?
  @JsonKey(name: FirestoreFields.muted)
  final bool muted;

  /// Firestore'a yazılacak map.
  Map<String, Object?> toJson() => _$ClubNotificationPrefsModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya.
  ClubNotificationPrefsModel copyWith({
    bool? announcements,
    bool? events,
    bool? posts,
    bool? muted,
  }) => ClubNotificationPrefsModel(
    announcements: announcements ?? this.announcements,
    events: events ?? this.events,
    posts: posts ?? this.posts,
    muted: muted ?? this.muted,
  );

  @override
  List<Object?> get props => [announcements, events, posts, muted];
}
