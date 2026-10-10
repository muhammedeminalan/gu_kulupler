import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';

/// Her belgede bulunan ortak alanların tip sözleşmesi (PLAN §9.2,
/// soft-delete.md §2).
///
/// Mixin alan **üretmez**: `json_serializable` mixin alanlarını görmediği için
/// her model altı alanı kendi gövdesinde bildirir; mixin yalnızca ortak
/// arayüzü ve [isLive] türetimini sağlar. `createdBy` taşımayan modeller
/// getter'ı `null` dönecek biçimde uygular.
///
/// Zaman alanları sunucu zamanıdır ve bekleyen yazımda `null` gelebilir; bu
/// yüzden hepsi null olabilir. Değerler UTC'dir (D-26).
mixin BaseFields {
  /// Oluşturulma anı (sunucu zamanı, UTC).
  DateTime? get createdAt;

  /// Son güncelleme anı (sunucu zamanı, UTC).
  DateTime? get updatedAt;

  /// Belgeyi oluşturan kullanıcının uid'i (yalnızca gerekli belgelerde).
  String? get createdBy;

  /// Soft delete bayrağı (D-10).
  bool get isDeleted;

  /// Silinme anı (sunucu zamanı, UTC); silinmemişse `null`.
  DateTime? get deletedAt;

  /// Silen kullanıcının uid'i; silinmemişse `null`.
  String? get deletedBy;

  /// Belge silinmemiş mi? Liste ve tekil okumalar yalnızca canlı belgeleri
  /// gösterir.
  bool get isLive => !isDeleted;
}

/// Ortak alanların yazma yükleri (PLAN §9.2, §10.3; D-26).
///
/// Zaman damgaları istemci saatinden değil **sunucu zamanından** gelir
/// (`FieldValue.serverTimestamp()`); Security Rules bunları `request.time`
/// ile birebir karşılaştırır. Servis her `create` yükünü [create], her
/// `update` yükünü [update] ile birleştirir; model `toJson()` çıktısındaki
/// eş adlı değerler ezilir.
abstract final class BaseFieldsPayload {
  /// Yeni belgenin ortak alanları: `createdAt` ve `updatedAt` sunucu zamanı,
  /// `isDeleted: false`, `deletedAt: null`, `deletedBy: null`; [createdBy]
  /// verilirse o da eklenir (verilmezse anahtar yüke **girmez**).
  ///
  /// [createdBy] boş dizgi olamaz ([ArgumentError]).
  static Map<String, Object?> create({String? createdBy}) {
    if (createdBy != null && createdBy.isEmpty) {
      throw ArgumentError.value(createdBy, 'createdBy', 'boş olamaz');
    }
    return {
      FirestoreFields.createdAt: FieldValue.serverTimestamp(),
      FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
      FirestoreFields.isDeleted: false,
      FirestoreFields.deletedAt: null,
      FirestoreFields.deletedBy: null,
      FirestoreFields.createdBy: ?createdBy,
    };
  }

  /// Güncellenen belgenin ortak alanı: `updatedAt` sunucu zamanı.
  static Map<String, Object?> update() => {
    FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
  };
}
