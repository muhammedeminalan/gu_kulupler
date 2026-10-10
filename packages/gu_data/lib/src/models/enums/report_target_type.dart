import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Şikayet hedef türü (`reports.targetType`; PLAN §9.7, CD-33).
@JsonEnum(valueField: 'json')
enum ReportTargetType {
  /// Gönderi.
  post('post'),

  /// Yorum.
  comment('comment'),

  /// Kullanıcı (`targetClubId` yoktur).
  user('user'),

  /// Kulüp.
  club('club'),

  /// Etkinlik (`targetClubId` = etkinliğin kulübü).
  event('event');

  const ReportTargetType(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static ReportTargetType fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(
        json,
        'json',
        'ReportTargetType: bilinmeyen değer',
      ));
}
