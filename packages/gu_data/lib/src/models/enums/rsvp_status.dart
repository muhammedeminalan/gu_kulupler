import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

/// Katılım kaydı durumu (`rsvps.status`; PLAN §9.7, domain-model §2.8, §8).
///
/// "Gelmedi" bir üye değildir: etkinlik bitti ve durum [going] ise türetilir.
@JsonEnum(valueField: 'json')
enum RsvpStatus {
  /// Katılıyor (bilet geçerli).
  going('going'),

  /// Bekleme listesinde.
  waitlist('waitlist'),

  /// Katıldı (bilet okutuldu).
  attended('attended'),

  /// Katılım iptal edildi.
  cancelled('cancelled');

  const RsvpStatus(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static RsvpStatus fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(json, 'json', 'RsvpStatus: bilinmeyen değer'));
}
