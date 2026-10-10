import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Şikayet nedeni (`reports.reason`; PLAN §9.7, CD-33 — SHT-10 altı neden).
@JsonEnum(valueField: 'json')
enum ReportReason {
  /// İstenmeyen içerik.
  spam('spam'),

  /// Taciz / zorbalık.
  harassment('harassment'),

  /// Uygunsuz içerik.
  inappropriate('inappropriate'),

  /// Yanlış bilgi.
  misinformation('misinformation'),

  /// Konu dışı.
  offtopic('offtopic'),

  /// Diğer (not alanı açıklar).
  other('other');

  const ReportReason(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static ReportReason fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(
        json,
        'json',
        'ReportReason: bilinmeyen değer',
      ));
}
