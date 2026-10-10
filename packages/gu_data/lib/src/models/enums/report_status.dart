import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Şikayet durumu (`reports.status`; PLAN §9.7, domain-model §2.10).
@JsonEnum(valueField: 'json')
enum ReportStatus {
  /// Açık (karar bekliyor).
  open('open'),

  /// Çözüldü (`action` dolu).
  resolved('resolved');

  const ReportStatus(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static ReportStatus fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(
        json,
        'json',
        'ReportStatus: bilinmeyen değer',
      ));
}
