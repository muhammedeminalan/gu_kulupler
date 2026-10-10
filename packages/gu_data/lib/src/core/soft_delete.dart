import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';

/// Soft delete yükleri — içerik "silme" ve geri almanın **tek** yolu (D-10,
/// soft-delete.md §3).
///
/// Uygulamada hiçbir belge fiziksel olarak kaldırılmaz: silinen belge
/// [payload] ile işaretlenir, geri alınan belge [restorePayload] ile yeniden
/// canlanır. Durum geçişleri (üyelik `left`, katılım `cancelled` …) bu sınıfı
/// kullanmaz; onlar `status` alanıdır.
abstract final class SoftDelete {
  /// Silme yükü: `isDeleted: true`, `deletedAt` sunucu zamanı,
  /// `deletedBy: actorId`, `updatedAt` sunucu zamanı.
  ///
  /// [actorId] silen kullanıcının uid'idir; Security Rules `deletedBy`
  /// alanını istek sahibinin uid'iyle karşılaştırır. Boş olamaz
  /// ([ArgumentError]).
  static Map<String, Object?> payload({required String actorId}) {
    if (actorId.isEmpty) {
      throw ArgumentError.value(actorId, 'actorId', 'boş olamaz');
    }
    return {
      FirestoreFields.isDeleted: true,
      FirestoreFields.deletedAt: FieldValue.serverTimestamp(),
      FirestoreFields.deletedBy: actorId,
      FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
    };
  }

  /// Geri alma yükü: `isDeleted: false`, `deletedAt: null`,
  /// `deletedBy: null`, `updatedAt` sunucu zamanı.
  ///
  /// `deletedAt` ve `deletedBy` belgeden kaldırılmaz, **`null` yazılır**:
  /// Security Rules geri almada bu iki alanın `null` olmasını bekler.
  static Map<String, Object?> restorePayload() => {
    FirestoreFields.isDeleted: false,
    FirestoreFields.deletedAt: null,
    FirestoreFields.deletedBy: null,
    FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
  };

  /// [payload] ve [restorePayload] yüklerinin dokunduğu anahtarlar; Security
  /// Rules'taki izinli alan kümesiyle aynıdır (test ve doğrulama için).
  static const Set<String> affectedKeys = {
    FirestoreFields.isDeleted,
    FirestoreFields.deletedAt,
    FirestoreFields.deletedBy,
    FirestoreFields.updatedAt,
  };
}
