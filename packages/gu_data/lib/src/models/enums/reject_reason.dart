import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Başvuru ret nedeni (`memberships.rejectReason`; PLAN §9.7,
/// domain-model §2.4).
@JsonEnum(valueField: 'json')
enum RejectReason {
  /// Kontenjan doldu.
  quota('quota'),

  /// Koşullar karşılanmıyor.
  criteria('criteria'),

  /// Eksik bilgi.
  missing('missing'),

  /// Diğer (`rejectNote` açıklar).
  other('other');

  const RejectReason(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static RejectReason fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(
        json,
        'json',
        'RejectReason: bilinmeyen değer',
      ));
}
