import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Kullanıcı hesap durumu (`users.status`; PLAN §9.7, domain-model §2.1).
@JsonEnum(valueField: 'json')
enum UserStatus {
  /// Hesap etkin.
  active('active'),

  /// Hesap süper admin tarafından askıya alındı (`suspendReason` dolu).
  suspended('suspended'),

  /// Hesap silindi ve anonimleştirildi (SET-03; domain-model §11).
  deleted('deleted');

  const UserStatus(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static UserStatus fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(json, 'json', 'UserStatus: bilinmeyen değer'));
}
