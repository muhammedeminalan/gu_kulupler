import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/services/firestore_types.dart';

/// Liste sorgularının "silinmemiş" süzgeci (PLAN §10.3, soft-delete.md §4).
///
/// Yalnızca `firebase_<alan>_repository.dart` uygulamaları kullanır: SDK
/// sorgu tipi üzerinde tanımlıdır, ViewModel bu tipi görmez.
extension NotDeletedQuery on Query<Json> {
  /// Sorguya `isDeleted == false` süzgecini ekler.
  ///
  /// Soft delete edilebilen her koleksiyonun liste sorgusu bunu taşır:
  /// Security Rules süzgeçsiz sorguyu reddeder (rules-spec §6). Hiç soft
  /// delete edilmeyen belgelerde (`memberships` — durum geçişi; `activity` —
  /// `isDeleted` alanı yok) **kullanılmaz**: indeksler bu alanı içermez
  /// (rules-spec §8).
  Query<Json> notDeleted() =>
      where(FirestoreFields.isDeleted, isEqualTo: false);
}
