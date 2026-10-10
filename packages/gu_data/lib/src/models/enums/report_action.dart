import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Çözülen şikayette uygulanan işlem (`reports.action`; PLAN §9.7,
/// domain-model §2.10).
@JsonEnum(valueField: 'json')
enum ReportAction {
  /// İçerik kaldırıldı.
  removed('removed'),

  /// Şikayet reddedildi (işlem yapılmadı).
  dismissed('dismissed'),

  /// Hedef askıya alındı.
  suspended('suspended');

  const ReportAction(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static ReportAction fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(
        json,
        'json',
        'ReportAction: bilinmeyen değer',
      ));
}
