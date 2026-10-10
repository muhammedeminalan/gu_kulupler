import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Gönderi türü (`posts.type`; PLAN §9.7, domain-model §2.5).
@JsonEnum(valueField: 'json')
enum PostType {
  /// Sıradan gönderi.
  post('post'),

  /// Duyuru (başlık zorunlu; günlük limit domain-model §7).
  announcement('announcement'),

  /// Anket (`poll` alt nesnesi zorunlu).
  poll('poll');

  const PostType(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static PostType fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(json, 'json', 'PostType: bilinmeyen değer'));
}
